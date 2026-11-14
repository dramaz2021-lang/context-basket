import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor
struct ClipboardTests {
    private func library() throws -> MaterialLibrary {
        try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ClipboardTests-\(UUID())"))
    }

    private func write(_ text: String, to board: NSPasteboard) {
        board.clearContents()
        board.setString(text, forType: .string)
    }

    @Test func startsWithNewCopiesAndCollectsEachChangeOnceVerbatim() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        write("启动之前的内容", to: board)
        let store = BasketStore(library: library)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        #expect(monitor.poll().isEmpty)
        #expect(store.items.isEmpty)
        let text = "复制的中文 🌿\n  保留换行、空格和原文  "
        write(text, to: board)
        for task in monitor.poll() { await task.value }
        #expect(monitor.poll().isEmpty)
        #expect(store.items.map(\.text) == [text])
        #expect(try library.loadDocument().items.map(\.text) == [text])
        #expect(board.string(forType: .string) == text)
    }

    @Test func collectsOnlyWhileUnfoldedAndNeverBackfills() async throws {
        _ = NSApplication.shared
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        defer { monitor.setEnabled(false) }
        let panel = ShelfPanel(contentRect: NSRect(x: 50, y: 50, width: 460, height: 500), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        defer { panel.orderOut(nil) }
        let controller = FloatingShelfController(panel: panel, store: store)
        controller.onExpansionChanged = { monitor.setEnabled($0) }
        write("折叠时复制", to: board)
        #expect(monitor.poll().isEmpty)
        controller.expand()
        #expect(monitor.poll().isEmpty)
        write("展开后新复制", to: board)
        for task in monitor.poll() { await task.value }
        controller.collapse()
        write("再次折叠后复制", to: board)
        #expect(monitor.poll().isEmpty)
        controller.expand()
        #expect(monitor.poll().isEmpty)
        #expect(store.items.map(\.text) == ["展开后新复制"])
    }

    @Test func copyingWhatTheBasketAlreadyHoldsAddsNothing() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("原文件.docx")
        try "文件原文".write(to: source, atomically: true, encoding: .utf8)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        for _ in 0..<2 {
            write("同一段文字", to: board)
            for task in monitor.poll() { await task.value }
            write("https://example.com/page", to: board)
            for task in monitor.poll() { await task.value }
            board.clearContents()
            board.writeObjects([source as NSURL])
            for task in monitor.poll() { await task.value }
        }
        #expect(store.items.map(\.kind) == [.text, .link, .file])
        store.remove(store.items[0].id)
        write("同一段文字", to: board)
        for task in monitor.poll() { await task.value }
        #expect(store.items.map(\.kind) == [.link, .file, .text])
    }

    @Test func copiedFilesAlwaysOwnCopiesEvenWhenManualDefaultIsReference() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("原文件.docx")
        try "文件原文".write(to: source, atomically: true, encoding: .utf8)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        store.setImportMode(.reference)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        board.clearContents()
        board.writeObjects([source as NSURL])
        for task in monitor.poll() { await task.value }
        let item = try #require(store.items.first)
        #expect(item.importMode == .copy)
        let copy = library.url(for: try #require(item.assetPath))
        #expect(copy != source)
        try "修改原件".write(to: source, atomically: true, encoding: .utf8)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "文件原文")
        #expect(try store.export().files.count == 2)
        store.remove(item.id)
        #expect(try String(contentsOf: source, encoding: .utf8) == "修改原件")
    }

    @Test func copiedImageAndLinkUseTheExistingImportPipeline() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let image = NSPasteboardItem()
        image.setData(try #require(bitmap.representation(using: .png, properties: [:])), forType: .png)
        image.setString("替代文字不应额外导入", forType: .string)
        let url = NSPasteboardItem()
        url.setString("https://example.com/design?version=1#title", forType: .URL)
        board.clearContents()
        board.writeObjects([image, url])
        for task in monitor.poll() { await task.value }
        #expect(store.items.map(\.kind) == [.image, .link])
        #expect(store.items[0].sourceURL == nil)
        #expect(store.items[0].assetPath != nil)
        #expect(store.items[1].text == "https://example.com/design?version=1#title")
        #expect(try store.export().files.count == 2)
    }

    @Test func copyingThePromptDoesNotCollectItsOwnOutput() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        store.setPrompt("这是要交付的任务指令")
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        store.copyPrompt(to: board)
        #expect(board.string(forType: .string) == store.promptText)
        #expect(monitor.poll().isEmpty)
        #expect(store.items.isEmpty)
        write("下一次外部复制仍然接收", to: board)
        for task in monitor.poll() { await task.value }
        #expect(store.items.count == 1)
    }

    @Test func ignoresMarkedAndUnsupportedClipboardChanges() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType"] {
            let item = NSPasteboardItem()
            item.setString("合成的排除样本", forType: .string)
            item.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
            board.clearContents()
            board.writeObjects([item])
            #expect(monitor.poll().isEmpty)
        }
        board.clearContents()
        board.setData(Data([0]), forType: NSPasteboard.PasteboardType("com.example.unsupported"))
        #expect(monitor.poll().isEmpty)
        #expect(store.items.isEmpty)
        #expect(store.errorMessage == nil)
        write("正常内容", to: board)
        for task in monitor.poll() { await task.value }
        #expect(store.items.map(\.text) == ["正常内容"])
    }

    @Test func documentsWithTheRetiredCollectionSwitchStillLoad() throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let json = #"{"version":2,"items":[],"prompt":"原来的指令","importMode":"reference","automaticallyCollectClipboard":false}"#
        try json.write(to: library.directory.appendingPathComponent("basket.json"), atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        #expect(store.errorMessage == nil)
        #expect(store.prompt == "原来的指令")
        #expect(store.importMode == .reference)
    }

    @Test func timerCollectsWithoutAnExplicitPasteOrPoll() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = BasketStore(library: library)
        let monitor = ClipboardMonitor(store: store, pasteboard: board)
        monitor.setEnabled(true)
        defer { monitor.setEnabled(false) }
        write("定时自动收集", to: board)
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while (store.items.isEmpty || store.items.contains(where: \.isLoading)), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.items.map(\.text) == ["定时自动收集"])
    }
}
