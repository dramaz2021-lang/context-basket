import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor struct ShelfPresentationTests {
    @Test func instructionHeightFollowsNewlinesWrappingAndShrinking() {
        let single = BubbleLayout.promptHeight(for: "一行指令")
        #expect(single == BubbleLayout.minimumPromptHeight)
        #expect(BubbleLayout.promptHeight(for: "一行指令\n") > single)
        #expect(BubbleLayout.promptHeight(for: "一行指令\n第二行\n") > BubbleLayout.promptHeight(for: "一行指令\n"))
        #expect(BubbleLayout.promptHeight(for: String(repeating: "较长的指令内容", count: 20)) > single)
        #expect(BubbleLayout.promptHeight(for: String(repeating: "指令\n", count: 50)) == BubbleLayout.maximumPromptHeight)
        #expect(BubbleLayout.promptHeight(for: "") == single)
    }

    @Test func attachmentsFillTwoColumnsBeforeAddingARow() {
        let first = Material.pending(id: UUID(), title: "附件一")
        let second = Material.pending(id: UUID(), title: "附件二")
        let empty = BubbleLayout.collectionHeight(items: [])
        #expect(BubbleLayout.collectionHeight(items: [first]) == empty)
        #expect(BubbleLayout.collectionHeight(items: [first, second]) == empty * 2 + BubbleLayout.gap)
    }

    @Test func editingNotesKeepsTheGridInsideItsOriginalBounds() async throws {
        _ = NSApplication.shared
        let library = try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("NoteGeometry-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        for task in store.add([.text("用于检查卡片布局的材料")]) { await task.value }
        let id = try #require(store.items.first?.id)
        let height = BubbleLayout.expandedHeight(items: store.items, prompt: "", available: 900)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: BubbleLayout.expandedWidth, height: height), styleMask: .borderless, backing: .buffered, defer: false)
        let host = ShelfHostingView(store: store, close: {})
        window.contentView = host
        defer { window.orderOut(nil) }

        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        func checkLayout(editorVisible: Bool) async throws -> NSRect {
            try await Task.sleep(for: .milliseconds(300))
            host.layoutSubtreeIfNeeded()
            let views = descendants(host)
            let slot = try #require(views.compactMap { $0 as? DropAreaMarker.Marker }.first { abs($0.bounds.width - BubbleLayout.cardWidth) < 1 })
            let grid = try #require(slot.enclosingScrollView)
            #expect(abs(grid.contentView.bounds.width - BubbleLayout.collectionWidth) < 1)
            #expect(abs(grid.documentView!.bounds.height - BubbleLayout.cardHeight) < 1)
            let visible = slot.visibleRect.intersection(slot.bounds)
            #expect(abs(visible.width - BubbleLayout.cardWidth) < 1)
            #expect(abs(visible.height - BubbleLayout.cardHeight) < 1)
            #expect(views.contains { $0 is MaterialNoteTextView } == editorVisible)
            #expect(BubbleLayout.expandedHeight(items: store.items, prompt: "", available: 900) == height)
            return slot.convert(slot.bounds, to: host)
        }
        let original = try await checkLayout(editorVisible: false)
        store.editNote(id)
        #expect(try await checkLayout(editorVisible: true) == original)
        store.setNote(id, String(repeating: "多行说明\n", count: 12))
        #expect(try await checkLayout(editorVisible: true) == original)
        let editor = try #require(descendants(host).compactMap { $0 as? MaterialNoteTextView }.first)
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(store.noteEditorID == nil)
        #expect(try await checkLayout(editorVisible: false) == original)
        #expect(store.items.first?.note == String(repeating: "多行说明\n", count: 12))
    }

    @Test func manualFoldingKeepsTheEditorAndMaterialsAlive() async throws {
        _ = NSApplication.shared
        let library = try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ShelfPresentation-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        for task in store.add([.text("原始材料")]) { await task.value }
        let id = try #require(store.items.first?.id)
        store.setPrompt("整理材料")
        store.setNote(id, "保留原文")
        store.editNote(id)
        let panel = ShelfPanel(contentRect: NSRect(x: 50, y: 50, width: 460, height: 500), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let controller = FloatingShelfController(panel: panel, store: store)
        #expect(controller.isCollapsed)
        controller.expand()
        #expect(!controller.isCollapsed)
        let editorView = panel.contentView
        let prompt = store.promptText
        controller.collapse()
        #expect(controller.isCollapsed)
        #expect(panel.contentView !== editorView)
        controller.expand()
        #expect(!controller.isCollapsed)
        #expect(panel.contentView === editorView)
        #expect(store.noteEditorID == id)
        #expect(store.items.first?.note == "保留原文")
        #expect(store.promptText == prompt)
        controller.collapse()
        controller.expand()
        #expect(panel.contentView === editorView)
        panel.orderOut(nil)
    }
}
