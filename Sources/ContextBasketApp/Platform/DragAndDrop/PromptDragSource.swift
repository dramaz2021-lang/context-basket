import AppKit
import SwiftUI

/// A native drag with one small translucent badge, even when many files travel with it.
struct PromptDragSource: NSViewRepresentable {
    let store: BasketStore
    var material: Material?
    var clicked: () -> Void = {}
    var hoverChanged: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ view: Handle, context: Context) {
        view.store = store
        view.material = material
        view.clicked = clicked
        view.hoverChanged = hoverChanged
    }

    final class Handle: NSView, NSDraggingSource {
        weak var store: BasketStore?
        var material: Material?
        var clicked: () -> Void = {}
        var hoverChanged: (Bool) -> Void = { _ in }
        private var start: NSPoint?
        private var didDrag = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            start = convert(event.locationInWindow, from: nil)
            didDrag = false
        }
        override func mouseUp(with event: NSEvent) {
            if !didDrag { clicked() }
            start = nil
        }
        override func mouseDragged(with event: NSEvent) {
            guard !didDrag, let start, let store else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard hypot(point.x - start.x, point.y - start.y) > 4 else { return }
            didDrag = true
            do {
                let selection = material.flatMap { selected in store.items.first { $0.id == selected.id } }.map { [$0] }
                // A removed card cannot accidentally export the entire basket.
                if material != nil && selection == nil { return }
                let bundle = try store.export(selection)
                let label = material?.title ?? "\(store.items.count) 份材料 + 指令"
                let badge = Self.badge(label)
                let items = bundle.files.enumerated().map { index, file in
                    let board = NSPasteboardItem()
                    board.setString(file.absoluteString, forType: .fileURL)
                    if index == 0 { board.setString(bundle.text, forType: .string) }
                    let item = NSDraggingItem(pasteboardWriter: board)
                    item.setDraggingFrame(NSRect(x: point.x - 95, y: point.y - 24, width: 190, height: 48), contents: index == 0 ? badge : nil)
                    return item
                }
                store.isExporting = true
                let session = beginDraggingSession(with: items, event: event, source: self)
                session.draggingFormation = .none
                session.animatesToStartingPositionsOnCancelOrFail = true
            } catch { store.errorMessage = error.localizedDescription }
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            store?.isExporting = false
            hoverChanged(false)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag], owner: self))
        }
        override func mouseEntered(with event: NSEvent) { hoverChanged(true) }
        override func mouseMoved(with event: NSEvent) { hoverChanged(true) }
        override func mouseExited(with event: NSEvent) { hoverChanged(false) }

        private static func badge(_ text: String) -> NSImage {
            let opaque = NSImage(size: NSSize(width: 190, height: 48), flipped: false) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byTruncatingMiddle
                (text as NSString).draw(in: rect.insetBy(dx: 15, dy: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
                return true
            }
            return NSImage(size: opaque.size, flipped: false) { rect in
                opaque.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.48)
                return true
            }
        }
    }
}
