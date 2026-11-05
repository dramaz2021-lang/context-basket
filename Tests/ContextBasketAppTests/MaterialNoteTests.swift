import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor
struct MaterialNoteTests {
    @Test func returnFinishesTheNoteWithoutInsertingANewline() {
        _ = NSApplication.shared
        let editor = MaterialNoteTextView(frame: NSRect(x: 0, y: 0, width: 220, height: 56))
        editor.string = "用这个当作模板"
        var submitted: String?
        editor.onSubmit = { submitted = editor.string }
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(submitted == "用这个当作模板")
        #expect(editor.string == "用这个当作模板")
    }

    @Test func markedTextDoesNotSubmitTheNote() {
        _ = NSApplication.shared
        let editor = MaterialNoteTextView(frame: NSRect(x: 0, y: 0, width: 220, height: 56))
        var submitted = false
        editor.onSubmit = { submitted = true }
        editor.setMarkedText("模", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(editor.hasMarkedText())
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(!submitted)
    }
}
