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
        let empty = BubbleLayout.collectionHeight(items: [], noteEditorID: nil)
        #expect(BubbleLayout.collectionHeight(items: [first], noteEditorID: nil) == empty)
        #expect(BubbleLayout.collectionHeight(items: [first, second], noteEditorID: nil) == empty * 2 + BubbleLayout.gap)
        #expect(BubbleLayout.collectionHeight(items: [first, second], noteEditorID: first.id) > empty * 2 + BubbleLayout.gap)
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
