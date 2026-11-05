import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor
struct PromptTests {
    private func library() throws -> MaterialLibrary {
        try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("PromptTests-\(UUID())"))
    }

    @Test func copiedPromptOnlyContainsTaskAndAttachmentDescription() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("材料模板.docx")
        try Data("synthetic document".utf8).write(to: source)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)]) { await task.value }
        store.setNote(try #require(store.items.first?.id), "用这个当作模板")
        store.setPrompt("根据模板撰写说明。")
        let expected = "任务：\n根据模板撰写说明。\n\n附件说明：\n1. 材料模板.docx：用这个当作模板\n"
        #expect(store.promptText == expected)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        store.presentPromptPreview()
        store.copyPrompt(to: board)
        #expect(board.string(forType: .string) == expected)
        #expect(store.statusMessage == nil)
        let files = try #require(board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])
        #expect(files.map(\.lastPathComponent) == ["PROMPT.txt", "01-材料模板.docx"])
        #expect(try String(contentsOf: files[0], encoding: .utf8) == expected)
        #expect(try Data(contentsOf: files[1]) == Data("synthetic document".utf8))
        #expect(try Data(contentsOf: source) == Data("synthetic document".utf8))
    }

    @Test func promptRefreshesAsMaterialsAndNotesChangeWhilePreviewIsOpen() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        store.setPrompt("整理材料")
        store.presentPromptPreview()
        #expect(store.showPromptPreview)
        let original = "原文 🌿\n  保留缩进  \n```swift\nlet x = 1\n```"
        for task in store.add([.text(original)]) { await task.value }
        #expect(store.promptText.contains(original))
        #expect(store.promptText.contains("1. 文字材料"))
        let id = try #require(store.items.first?.id)
        store.setNote(id, "参考这段原文")
        #expect(store.promptText.contains("1. 文字材料：参考这段原文"))
        store.setPrompt("新的任务")
        #expect(store.promptText.hasPrefix("任务：\n新的任务\n"))
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        store.copyPrompt(to: board)
        #expect(board.string(forType: .string) == store.promptText)
        store.remove(id)
        #expect(!store.promptText.contains(original))
        store.undoRemove()
        #expect(store.promptText.contains(original))
        #expect(!FileManager.default.fileExists(atPath: library.directory.appendingPathComponent("exports").path))
    }

    @Test func copiedFilesAndImagesStayReadableWithoutCollectingThemselves() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("template.docx")
        let original = Data("synthetic document".utf8)
        try original.write(to: source)
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.setColor(.systemGreen, atX: 0, y: 0)
        let image = try #require(bitmap.representation(using: .png, properties: [:]))
        let store = BasketStore(library: library)
        for task in store.add([.file(source), .image(image), .file(source), .text("文字直接放进 Prompt")]) { await task.value }
        for task in store.add([.file(source)], mode: .reference) { await task.value }
        store.setPrompt("参考附件")
        let expectedText = store.promptText
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        store.copyPrompt(to: board)
        let files = try #require(board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])
        #expect(files.map(\.lastPathComponent) == ["PROMPT.txt", "01-template.docx", "02-图片.png", "03-template.docx"])
        #expect(files.count == 4)
        #expect(board.string(forType: .string) == expectedText)
        #expect(board.pasteboardItems?.filter { $0.string(forType: .string) != nil }.count == 1)
        #expect(monitor.poll().isEmpty)
        #expect(store.items.count == 5)
        #expect(!files.contains(source))
        for id in store.items.map(\.id) { store.remove(id) }
        try Data("changed source".utf8).write(to: source)
        #expect(try String(contentsOf: files[0], encoding: .utf8) == expectedText)
        #expect(try Data(contentsOf: files[1]) == original)
        #expect(try Data(contentsOf: files[3]) == original)
        #expect(NSImage(contentsOf: files[2]) != nil)
        #expect(board.string(forType: .string) == expectedText)
    }

    @Test func failedCopyLeavesTheClipboardUntouched() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("保留现有剪贴板", forType: .string)
        let store = BasketStore(library: library)
        store.copyPrompt(to: board)
        #expect(board.string(forType: .string) == "保留现有剪贴板")
        let source = library.directory.appendingPathComponent("original.txt")
        try "原件".write(to: source, atomically: true, encoding: .utf8)
        for task in store.add([.file(source)], mode: .reference) { await task.value }
        store.presentPromptPreview()
        try FileManager.default.removeItem(at: source)
        store.copyPrompt(to: board)
        #expect(board.string(forType: .string) == "保留现有剪贴板")
        #expect(store.errorMessage?.contains("找不到源文件") == true)
        store.remove(try #require(store.items.first?.id))
        try "副本内容".write(to: source, atomically: true, encoding: .utf8)
        for task in store.add([.file(source)]) { await task.value }
        let asset = try #require(store.items.first?.assetPath)
        try FileManager.default.removeItem(at: library.url(for: asset))
        store.copyPrompt(to: board)
        #expect(board.string(forType: .string) == "保留现有剪贴板")
        #expect(store.errorMessage != nil)
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
