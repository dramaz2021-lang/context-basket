import AppKit

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var pasteMaterials: (() -> Void)?
    var undoRemoval: (() -> Void)?
    private(set) var lastEditingEventTime: TimeInterval = -.infinity

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let editor = firstResponder as? NSTextView, editor.isEditable {
            lastEditingEventTime = ProcessInfo.processInfo.systemUptime
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let editor = firstResponder as? NSTextView, editor.isEditable {
            return super.performKeyEquivalent(with: event)
        }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            switch event.charactersIgnoringModifiers {
            case "v": pasteMaterials?(); return true
            case "z": undoRemoval?(); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
