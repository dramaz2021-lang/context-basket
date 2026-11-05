import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor struct ClearBasketTests {
    @Test func clearAndUndoRestoreTaskNotesAndAttachmentsWithoutTouchingSourceOrClipboardMode() async throws {
        let library = try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ClearBasket-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("source.txt")
        try "原件".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        store.setAutomaticallyCollectClipboard(false)
        for task in store.add([.file(source), .text("材料正文")]) { await task.value }
        let first = try #require(store.items.first)
        store.setPrompt("整理这两份材料")
        store.setNote(first.id, "附件说明")
        let previousPrompt = store.promptText
        let bundle = try store.export()
        store.clearBasket()
        #expect(store.items.isEmpty && store.prompt.isEmpty && !store.canExport)
        #expect(store.canUndo)
        #expect(!store.automaticallyCollectClipboard)
        #expect(try library.loadDocument().items.isEmpty)
        #expect(try library.loadDocument().prompt.isEmpty)
        #expect(try String(contentsOf: source, encoding: .utf8) == "原件")
        #expect(bundle.files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        store.undoRemove()
        #expect(store.items.count == 2)
        #expect(store.items.first?.id == first.id)
        #expect(store.items.first?.note == "附件说明")
        #expect(store.promptText == previousPrompt)
        #expect(!store.canUndo)
        #expect(try library.loadDocument().prompt == "整理这两份材料")
        #expect(FileManager.default.fileExists(atPath: library.url(for: try #require(first.assetPath)).path))
    }

    @Test func clearPendingImportsDoesNotResurrectMaterials() async throws {
        let library = try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ClearPending-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        let tasks = store.add([.text("还在导入")])
        store.clearBasket()
        for task in tasks { await task.value }
        #expect(store.items.isEmpty)
        store.undoRemove()
        #expect(store.items.isEmpty)
    }
}
