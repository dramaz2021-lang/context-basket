import AppKit

/// Keep the hint in the native editor so IME composition hides it before text is committed.
class PlaceholderTextView: NSTextView {
    var placeholder = "" { didSet { needsDisplay = true } }
    var showsPlaceholder: Bool { string.isEmpty && !hasMarkedText() }

    override var string: String { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard showsPlaceholder, !placeholder.isEmpty else { return }
        let origin = NSPoint(x: textContainerOrigin.x + (textContainer?.lineFragmentPadding ?? 0), y: textContainerOrigin.y)
        (placeholder as NSString).draw(at: origin, withAttributes: [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor
        ])
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        needsDisplay = true
    }

    override func unmarkText() {
        super.unmarkText()
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}
