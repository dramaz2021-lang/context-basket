import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor struct TextPlaceholderTests {
    @Test func bothEditorsHideHintsDuringCompositionAndRestoreAfterCancellation() {
        _ = NSApplication.shared
        let frame = NSRect(x: 0, y: 0, width: 220, height: 56)
        let editors: [PlaceholderTextView] = [PromptTextView(frame: frame), MaterialNoteTextView(frame: frame)]
        for editor in editors {
            #expect(editor.showsPlaceholder)
            let selection = NSRange(location: NSNotFound, length: 0)
            editor.setMarkedText("dan", selectedRange: NSRange(location: 3, length: 0), replacementRange: selection)
            #expect(editor.hasMarkedText())
            #expect(!editor.showsPlaceholder)

            editor.setMarkedText("", selectedRange: NSRange(location: 0, length: 0), replacementRange: selection)
            editor.unmarkText()
            #expect(editor.string.isEmpty)
            #expect(editor.showsPlaceholder)

            editor.setMarkedText("dan", selectedRange: NSRange(location: 3, length: 0), replacementRange: selection)
            editor.insertText("丹", replacementRange: selection)
            #expect(!editor.hasMarkedText())
            #expect(editor.string == "丹")
            #expect(!editor.showsPlaceholder)

            editor.string = ""
            #expect(editor.showsPlaceholder)
            editor.string = "恢复保存的指令"
            #expect(!editor.showsPlaceholder)
        }
    }
}
