import AppKit

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var pasteMaterials: (() -> Void)?
    var undoRemoval: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
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
