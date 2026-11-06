import AppKit
import SwiftUI

struct MaterialNoteEditor: NSViewRepresentable {
    @ObservedObject var store: BasketStore
    let itemID: UUID
    let title: String

    func makeCoordinator() -> Coordinator { Coordinator(store: store, itemID: itemID) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = MaterialNoteTextView(frame: .zero)
        editor.placeholder = "输入附件说明"
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 11)
        editor.textColor = .black
        editor.insertionPointColor = .black
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.string = store.items.first { $0.id == itemID }?.note ?? ""
        editor.setAccessibilityLabel("文件说明：\(title)")
        editor.onSubmit = { [weak editor, coordinator = context.coordinator] in
            guard let editor else { return }
            coordinator.store.setNote(coordinator.itemID, editor.string)
            editor.window?.makeFirstResponder(nil)
            coordinator.store.finishNoteEditing()
        }
        scroll.documentView = editor
        DispatchQueue.main.async { [weak editor] in
            guard let editor, editor.window != nil else { return }
            editor.window?.makeFirstResponder(editor)
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? MaterialNoteTextView, !editor.hasMarkedText() else { return }
        let note = store.items.first { $0.id == itemID }?.note ?? ""
        if editor.string != note { editor.string = note }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let store: BasketStore
        let itemID: UUID
        init(store: BasketStore, itemID: UUID) { self.store = store; self.itemID = itemID }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            store.setNote(itemID, editor.string)
        }
    }
}

final class MaterialNoteTextView: PlaceholderTextView {
    var onSubmit: () -> Void = {}

    override func doCommand(by selector: Selector) {
        // Input methods commit marked text before issuing the ordinary Return command.
        if selector == #selector(NSResponder.insertNewline(_:)), !hasMarkedText(),
           NSApp.currentEvent?.modifierFlags.contains(.shift) != true {
            onSubmit()
            return
        }
        super.doCommand(by: selector)
    }
}
