import AppKit
import SwiftUI

/// Plain-text editing. File/image drops are rejected rather than imported or embedded.
struct PromptTextEditor: NSViewRepresentable {
    @ObservedObject var store: BasketStore
    let drops: MaterialDropCoordinator

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        let editor = PromptTextView(frame: .zero)
        editor.placeholder = "输入指令"
        editor.drops = drops
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.drawsBackground = false
        editor.font = BubbleLayout.promptFont
        editor.textColor = .black
        editor.insertionPointColor = .black
        editor.textContainerInset = .zero
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.string = store.prompt
        editor.setAccessibilityLabel("给 Agent 的指令")
        // Include image/file promises so they never fall through to a rich-text attachment.
        editor.registerForDraggedTypes(DropReader.types)
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? PromptTextView else { return }
        if editor.string != store.prompt, !editor.hasMarkedText() { editor.string = store.prompt }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        let store: BasketStore
        init(store: BasketStore) { self.store = store }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            store.setPrompt(editor.string)
        }
    }
}

final class PromptTextView: PlaceholderTextView {
    var drops: MaterialDropCoordinator?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let result = drops?.update(sender, at: .prompt) ?? []
        if !DropProfile.inspect(sender.draggingPasteboard).hasAttachments {
            let native = super.draggingEntered(sender)
            if (sender.draggingSource as? NSTextView) === self { return native }
        }
        return result
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let result = drops?.update(sender, at: .prompt) ?? []
        if !DropProfile.inspect(sender.draggingPasteboard).hasAttachments {
            let native = super.draggingUpdated(sender)
            if (sender.draggingSource as? NSTextView) === self { return native }
        }
        return result
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { drops?.end(); super.draggingExited(sender) }
    override func draggingEnded(_ sender: NSDraggingInfo) { drops?.end(); super.draggingEnded(sender) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let profile = DropProfile.inspect(sender.draggingPasteboard)
        return profile.isSupported && !profile.hasAttachments
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if (sender.draggingSource as? NSTextView) === self {
            drops?.end()
            return super.performDragOperation(sender)
        }
        return receiveDrop(sender.draggingPasteboard, at: convert(sender.draggingLocation, from: nil))
    }

    @discardableResult
    func receiveDrop(_ pasteboard: NSPasteboard, at point: NSPoint) -> Bool {
        drops?.end()
        guard !DropProfile.inspect(pasteboard).hasAttachments else { return false }
        guard let text = DropReader.plainText(pasteboard) else { return false }
        let index = characterIndexForInsertion(at: point)
        insertText(text, replacementRange: NSRange(location: min(index, (string as NSString).length), length: 0))
        return true
    }
}
