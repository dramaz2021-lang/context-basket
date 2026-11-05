import Testing
import AppKit
@testable import ContextBasket

@Suite @MainActor
struct BasketTests {
    private func temporaryLibrary() throws -> MaterialLibrary {
        try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ContextBasketTests-\(UUID().uuidString)"))
    }

    @Test func oneMaterialForMultiplePasteboardRepresentations() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("file:///tmp/reference.png", forType: .fileURL)
        item.setString("reference.png", forType: .string)
        board.writeObjects([item])
        let result = DropReader.read(board)
        #expect(result.count == 1)
        guard case .file(let url) = result.first else { Issue.record("File should win over its label"); return }
        #expect(url.path == "/tmp/reference.png")
    }

    @Test func mixedDropPreservesEveryItemAndOrder() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let original = "第一段\n\n保留换行和空格  "
        let text = NSPasteboardItem()
        text.setString(original, forType: .string)
        let link = NSPasteboardItem()
        link.setString("https://example.com/reference", forType: .URL)
        let file = NSPasteboardItem()
        file.setString("file:///tmp/example.pdf", forType: .fileURL)
        board.writeObjects([text, link, file])
        let result = DropReader.read(board)
        guard result.count == 3 else { Issue.record("All three materials must survive"); return }
        guard case .text(let value) = result[0], case .link = result[1], case .file = result[2] else {
            Issue.record("Mixed items must keep their representations and order"); return
        }
        #expect(value == original)
    }

    @Test func pendingImportsDoNotReturnAfterRemoval() async throws {
        let library = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        let tasks = store.add([.text("刚拖入的内容")])
        #expect(store.items.count == 1)
        #expect(store.items[0].isLoading)
        store.remove(store.items[0].id)
        for task in tasks { await task.value }
        #expect(store.items.isEmpty)
    }

    @Test func deleteUndoAndRelaunchKeepOriginalTextAndOrder() async throws {
        let library = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        let original = "中文，emoji 🌿\n第二行\n  保留空格"
        for task in store.add([.text(original), .text("第二份材料")]) { await task.value }
        let id = try #require(store.items.first?.id)
        store.remove(id)
        #expect(store.items.count == 1)
        store.undoRemove()
        #expect(store.items.map(\.text) == [original, "第二份材料"])
        let restored = BasketStore(library: library)
        #expect(restored.items == store.items)
    }

    @Test func fileImportOwnsCopyAndRemovalDoesNotTouchSource() async throws {
        let library = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("source.txt")
        try "合成测试材料".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)]) { await task.value }
        #expect(store.items.count == 1)
        let item = try #require(store.items.first)
        let asset = try #require(item.assetPath)
        #expect(library.url(for: asset) != source)
        store.remove(item.id)
        #expect(try String(contentsOf: source, encoding: .utf8) == "合成测试材料")
        store.undoRemove()
        #expect(FileManager.default.fileExists(atPath: library.url(for: asset).path))
    }

    @Test func rejectingFolderDoesNotLoseOtherMaterials() throws {
        let library = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        #expect(throws: (any Error).self) { try library.prepare(.file(library.directory), id: UUID()) }
        let text = try library.prepare(.text("仍然可以添加"), id: UUID())
        #expect(text.text == "仍然可以添加")
    }
}
