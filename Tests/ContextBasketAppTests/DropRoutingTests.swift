import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor struct DropRoutingTests {
    private func library() throws -> MaterialLibrary {
        try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("DropRouting-\(UUID())"))
    }
    private func finishImports(_ store: BasketStore) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while store.items.contains(where: \.isLoading), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let stillLoading = store.items.contains { $0.isLoading }
        #expect(!stillLoading)
    }
    private func editor(store: BasketStore, drops: MaterialDropCoordinator) -> PromptTextView {
        _ = NSApplication.shared
        let editor = PromptTextView(frame: NSRect(x: 0, y: 0, width: 350, height: 130))
        editor.isRichText = false
        editor.importsGraphics = false
        editor.drops = drops
        editor.string = store.prompt
        return editor
    }

    @Test func fileZonesChooseIndependentOfGlobalDefaultAndRemainEditable() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let file = library.directory.appendingPathComponent("design.txt")
        try "source".write(to: file, atomically: true, encoding: .utf8)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.writeObjects([file as NSURL])
        let store = BasketStore(library: library)
        store.setImportMode(.reference)
        let drops = MaterialDropCoordinator(store: store)
        #expect(drops.receive(board, at: .collectionLeft))
        #expect(drops.receive(board, at: .collectionRight))
        try await finishImports(store)
        #expect(store.items.map(\.modeLabel) == ["副本", "源文件地址"])
        let id = store.items[1].id
        store.setNote(id, "修改标题")
        await store.changeMode(id, to: .copy)?.value
        #expect(store.items[1].modeLabel == "副本")
        #expect(store.items[1].note == "修改标题")
        #expect(try String(contentsOf: file, encoding: .utf8) == "source")
    }

    @Test func draggingFileOverPromptIsIgnoredWithoutFeedback() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let file = library.directory.appendingPathComponent("reference.txt")
        try "材料正文".write(to: file, atomically: true, encoding: .utf8)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString(file.absoluteString, forType: .fileURL)
        item.setString(file.path, forType: .string)
        board.writeObjects([item])
        let store = BasketStore(library: library)
        store.setPrompt("保留我的指令")
        store.setImportMode(.reference)
        let drops = MaterialDropCoordinator(store: store)
        let editor = editor(store: store, drops: drops)
        store.dropFeedback = DropFeedback(style: .fileChoices, mode: .reference)
        #expect(!editor.receiveDrop(board, at: .zero))
        #expect(!drops.receive(board, at: .prompt))
        #expect(!drops.receive(board, at: .other))
        try await finishImports(store)
        #expect(editor.string == "保留我的指令")
        #expect(store.prompt == "保留我的指令")
        #expect(store.items.isEmpty)
        #expect(store.dropFeedback == nil)
    }

    @Test func rawImageOverPromptIsIgnoredAndNeverTextAttachment() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setString("图片的替代文字", forType: .string)
        board.writeObjects([item])
        let store = BasketStore(library: library)
        store.setPrompt("原来的任务")
        let drops = MaterialDropCoordinator(store: store)
        let editor = editor(store: store, drops: drops)
        #expect(!editor.receiveDrop(board, at: .zero))
        try await finishImports(store)
        #expect(editor.string == "原来的任务")
        #expect(store.items.isEmpty)
        #expect(store.prompt == "原来的任务")
        #expect(store.dropFeedback == nil)
        var containsAttachment = false
        editor.textStorage?.enumerateAttribute(.attachment, in: NSRange(location: 0, length: (editor.string as NSString).length)) { value, _, _ in
            if value != nil { containsAttachment = true }
        }
        #expect(!containsAttachment)
    }

    @Test func textAndWebLinksRemainPlainInstructions() throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let text = NSPasteboardItem()
        text.setString("先检查结构。\n保留空格  ", forType: .string)
        board.writeObjects([text])
        let store = BasketStore(library: library)
        let drops = MaterialDropCoordinator(store: store)
        let editor = editor(store: store, drops: drops)
        #expect(editor.receiveDrop(board, at: .zero))
        #expect(editor.string == "先检查结构。\n保留空格  ")
        #expect(store.items.isEmpty)
        board.clearContents()
        let url = NSPasteboardItem()
        url.setString("https://example.com/reference", forType: .URL)
        board.writeObjects([url])
        #expect(editor.receiveDrop(board, at: .zero))
        #expect(editor.string.contains("https://example.com/reference"))
        #expect(store.items.isEmpty)
    }

    @Test func dropZonesFollowTheMovingAddBubble() throws {
        _ = NSApplication.shared
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let drops = MaterialDropCoordinator(store: BasketStore(library: library))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 700), styleMask: .borderless, backing: .buffered, defer: false)
        let content = try #require(window.contentView)
        let addBubble = NSView(frame: NSRect(x: 0, y: 0, width: 224, height: 154))
        let secondBubble = NSView(frame: NSRect(x: 236, y: 0, width: 224, height: 154))
        let promptBubble = NSView(frame: NSRect(x: 0, y: 542, width: 460, height: 86))
        let icon = NSView(frame: NSRect(x: 0, y: 642, width: 58, height: 58))
        [addBubble, secondBubble, promptBubble, icon].forEach(content.addSubview)
        drops.registerCollectionArea(addBubble, slot: 0)
        drops.registerCollectionArea(secondBubble, slot: 1)
        drops.promptArea = promptBubble
        drops.iconArea = icon
        #expect(drops.location(at: NSPoint(x: 50, y: 58)) == .collectionLeft)
        #expect(drops.location(at: NSPoint(x: 175, y: 58)) == .collectionRight)
        #expect(drops.location(at: NSPoint(x: 270, y: 58)) == .collectionLeft)
        #expect(drops.location(at: NSPoint(x: 400, y: 58)) == .collectionRight)
        #expect(drops.location(at: NSPoint(x: 230, y: 58)) == .other)
        #expect(drops.location(at: NSPoint(x: 230, y: 580)) == .prompt)
        #expect(drops.location(at: NSPoint(x: 29, y: 670)) == .collectionLeft)
        #expect(drops.location(at: NSPoint(x: 350, y: 640)) == .other)
        addBubble.setFrameOrigin(NSPoint(x: 0, y: 200))
        #expect(drops.location(at: NSPoint(x: 50, y: 58)) == .other)
        #expect(drops.location(at: NSPoint(x: 50, y: 250)) == .collectionLeft)
        #expect(drops.location(at: NSPoint(x: 175, y: 250)) == .collectionRight)
        secondBubble.removeFromSuperview()
        #expect(drops.location(at: NSPoint(x: 400, y: 58)) == .other)
    }

    @Test func onlyStableFilesOfferTwoChoices() {
        let files = DropProfile(hasLocalFiles: true, hasAttachments: true, hasText: true)
        #expect(DropPolicy.feedback(profile: files, location: .collectionLeft) == DropFeedback(style: .fileChoices, mode: .copy))
        #expect(DropPolicy.feedback(profile: files, location: .collectionRight) == DropFeedback(style: .fileChoices, mode: .reference))
        #expect(DropPolicy.feedback(profile: files, location: .prompt) == nil)
        #expect(DropPolicy.feedback(profile: files, location: .other) == nil)
        let image = DropProfile(hasAttachments: true)
        #expect(DropPolicy.feedback(profile: image, location: .collectionRight)?.style == .context)
        #expect(DropPolicy.feedback(profile: image, location: .collectionRight)?.mode == .copy)
        #expect(DropPolicy.feedback(profile: image, location: .prompt) == nil)
        #expect(DropPolicy.feedback(profile: DropProfile(hasText: true), location: .prompt)?.style == .promptText)
        #expect(DropPolicy.feedback(profile: DropProfile(), location: .collectionRight) == nil)
    }

    @Test func gridDropMarkersSurviveAddingAndClearingMaterials() async throws {
        _ = NSApplication.shared
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 700), styleMask: .borderless, backing: .buffered, defer: false)
        let host = ShelfHostingView(store: store, close: {})
        window.contentView = host
        defer { window.orderOut(nil) }

        func markers(in view: NSView) -> [DropAreaMarker.Marker] {
            (view as? DropAreaMarker.Marker).map { [$0] } ?? view.subviews.flatMap { markers(in: $0) }
        }
        func checkSlots(_ expected: Int) async throws {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let slots = markers(in: host).filter { abs($0.bounds.width - BubbleLayout.cardWidth) < 1 && !$0.isHiddenOrHasHiddenAncestor }
            #expect(slots.count == expected)
            for slot in slots {
                let left = slot.convert(NSPoint(x: slot.bounds.width * 0.25, y: slot.bounds.midY), to: nil)
                let right = slot.convert(NSPoint(x: slot.bounds.width * 0.75, y: slot.bounds.midY), to: nil)
                #expect(host.drops.location(at: left) == .collectionLeft)
                #expect(host.drops.location(at: right) == .collectionRight)
            }
        }
        try await checkSlots(2)
        for task in store.add([.text("第一份")]) { await task.value }
        try await checkSlots(1)
        for task in store.add([.text("第二份")]) { await task.value }
        try await checkSlots(2)
        store.clearBasket()
        try await checkSlots(2)
    }
}
