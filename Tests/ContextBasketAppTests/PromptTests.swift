import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor
struct PromptTests {
    private func library() throws -> MaterialLibrary {
        try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("PromptTests-\(UUID())"))
    }
    @Test func legacyBasketMigratesWithoutInventingSource() throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let json = #"[{"id":"ED50A3C0-3A31-4B10-8846-FED1798F004E","kind":"text","title":"旧材料","text":"原文","detail":"2 字","isLoading":false}]"#
        try json.write(to: library.directory.appendingPathComponent("basket.json"), atomically: true, encoding: .utf8)
        let doc = try library.loadDocument()
        #expect(doc.items[0].sourceURL == nil)
        #expect(doc.items[0].text == "原文")
        #expect(doc.importMode == .copy)
        try library.saveDocument(doc)
        #expect(try library.loadDocument().items == doc.items)
    }
    @Test func notesPromptAndModePersistVerbatim() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        for task in store.add([.text("原材料\n  不改写")]) { await task.value }
        let id = try #require(store.items.first?.id)
        let note = "只参考配色 🌿\n  保留这一行空格"
        let instruction = "请根据这些材料修改页面。\n先给方案，再执行。  "
        store.setNote(id, note)
        store.setPrompt(instruction)
        store.setImportMode(.reference)
        let restored = BasketStore(library: library)
        #expect(restored.items[0].note == note)
        #expect(restored.prompt == instruction)
        #expect(restored.importMode == .reference)
        #expect(restored.promptText.contains(note))
        #expect(restored.promptText.contains(instruction))
    }
    @Test func referencesExportOnlyPathsAndDoNotModifyOriginal() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("原文件.txt")
        try "原文件内容".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)], mode: .reference) { await task.value }
        let item = try #require(store.items.first)
        #expect(item.assetPath == nil)
        #expect(item.text == nil)
        store.setNote(item.id, "重点修改这个原文件")
        let bundle = try store.export()
        #expect(bundle.files.map(\.lastPathComponent) == ["PROMPT.txt"])
        #expect(bundle.text.contains(source.path))
        #expect(bundle.text.contains("重点修改这个原文件"))
        #expect(bundle.text.contains("源文件地址"))
        store.remove(item.id)
        for task in store.add([.text("第二份材料")]) { await task.value }
        store.remove(store.items[0].id) // Discards the undo cache for the reference.
        #expect(try String(contentsOf: source, encoding: .utf8) == "原文件内容")
    }
    @Test func mixedBundleHasUniqueCopiesAndImmutableSnapshot() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let a = library.directory.appendingPathComponent("a")
        let b = library.directory.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        let first = a.appendingPathComponent("same.txt"), second = b.appendingPathComponent("same.txt")
        try "FIRST".write(to: first, atomically: true, encoding: .utf8)
        try "SECOND".write(to: second, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(first), .file(second)]) { await task.value }
        for task in store.add([.file(first)], mode: .reference) { await task.value }
        store.setPrompt("指令一")
        let bundle = try store.export()
        #expect(bundle.files.map(\.lastPathComponent) == ["PROMPT.txt", "01-same.txt", "02-same.txt"])
        #expect(try String(contentsOf: bundle.files[1], encoding: .utf8) == "FIRST")
        #expect(try String(contentsOf: bundle.files[2], encoding: .utf8) == "SECOND")
        store.setPrompt("指令二")
        store.remove(store.items[0].id)
        store.remove(store.items[0].id)
        #expect(try String(contentsOf: bundle.files[1], encoding: .utf8) == "FIRST")
        #expect(try String(contentsOf: bundle.files[0], encoding: .utf8).contains("指令一"))
    }
    @Test func missingReferenceFailsInsteadOfFallingBackToCopy() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("gone.txt")
        try "original".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)], mode: .reference) { await task.value }
        try FileManager.default.removeItem(at: source)
        #expect(throws: ExportError.self) { try store.export() }
    }
    @Test func switchingModeRetainsNotesAndSurvivesConcurrentEditing() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("switch.txt")
        try "original".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)]) { await task.value }
        let id = try #require(store.items.first?.id)
        store.setNote(id, "修改这里")
        let conversion = store.changeMode(id, to: .reference)
        store.setPrompt("转换期间也可以编辑")
        #expect(try library.loadDocument().items.count == 1)
        await conversion?.value
        #expect(store.items[0].isReference)
        #expect(store.items[0].assetPath == nil)
        #expect(store.items[0].note == "修改这里")
        await store.changeMode(id, to: .copy)?.value
        #expect(store.items[0].modeLabel == "副本")
        #expect(store.items[0].sourceURL == source)
        #expect(try String(contentsOf: source, encoding: .utf8) == "original")
    }
    @Test func promisesCannotBecomeDanglingReferences() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("temporary.txt")
        try "临时传输".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        store.setImportMode(.reference)
        for task in store.add([.file(source)], hasStableSource: false) { await task.value }
        try FileManager.default.removeItem(at: source)
        #expect(store.items[0].sourceURL == nil)
        #expect(store.items[0].modeLabel == "副本")
        #expect(try store.export().files.count == 2)
    }
    @Test func addressesAndPromptOnlyExport() throws {
        #expect(DropReader.localURL("/tmp/中文 文件.txt")?.path == "/tmp/中文 文件.txt")
        #expect(DropReader.localURL("file:///tmp/example.txt")?.path == "/tmp/example.txt")
        #expect(DropReader.localURL("/tmp/a\n/tmp/b") == nil)
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        #expect(!store.canExport)
        #expect(throws: ExportError.self) { try store.export() }
        store.setPrompt("只有指令也可以")
        #expect(store.canExport)
        #expect(try store.export().files.count == 1)
    }

    @Test func thumbnailCannotOverwriteAnImportedFileWithTheSameName() throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.setColor(NSColor(deviceRed: 0.2, green: 0.7, blue: 0.4, alpha: 1), atX: 0, y: 0)
        let original = try #require(bitmap.representation(using: .png, properties: [:]))
        let source = library.directory.appendingPathComponent(".preview.png")
        try original.write(to: source)
        let item = try library.prepare(.file(source), id: UUID())
        let asset = try #require(item.assetPath)
        let thumbnail = try #require(item.thumbnailPath)
        #expect(asset != thumbnail)
        #expect(try Data(contentsOf: library.url(for: asset)) == original)
    }
}
