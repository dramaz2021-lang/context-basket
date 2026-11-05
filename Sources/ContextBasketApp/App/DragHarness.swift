#if DEBUG
import AppKit

/// Manual drag fixture; excluded entirely from release builds.
@MainActor
func makeDragHarness(store: BasketStore) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 720, height: 510), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "拖入验收 · 合成材料"
    window.isReleasedWhenClosed = false
    window.level = .floating
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 510))
    let source = DragFixtureSource(frame: NSRect(x: 0, y: 0, width: 280, height: 510))
    let destination = ShelfHostingView(store: store, close: {})
    destination.frame = NSRect(x: 290, y: 5, width: 420, height: 500)
    container.addSubview(source)
    container.addSubview(destination)
    window.contentView = container
    return window
}

private final class DragFixtureSource: NSView, NSDraggingSource {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let rect = NSRect(x: 25, y: 200, width: 230, height: 110)
        NSColor.systemGreen.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()
        let text = "拖动这里 →\n文字 + 链接 + 图片\n三个独立材料"
        (text as NSString).draw(in: rect.insetBy(dx: 24, dy: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.labelColor])
    }

    override func mouseDown(with event: NSEvent) {
        let text = NSPasteboardItem()
        text.setString("这是从原生拖拽会话加入的文字。\n每份材料都应该单独可见。", forType: .string)
        let link = NSPasteboardItem()
        link.setString("https://example.com/design-reference", forType: .URL)
        let image = NSImage(size: NSSize(width: 600, height: 400), flipped: false) { rect in
            NSColor(calibratedRed: 0.65, green: 0.78, blue: 0.70, alpha: 1).setFill()
            rect.fill()
            NSColor.white.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 60, dy: 60), xRadius: 30, yRadius: 30).fill()
            ("DROP TEST" as NSString).draw(at: NSPoint(x: 130, y: 185), withAttributes: [.font: NSFont.systemFont(ofSize: 45, weight: .medium), .foregroundColor: NSColor.darkGray])
            return true
        }
        let picture = NSPasteboardItem()
        picture.setData(image.tiffRepresentation!, forType: .tiff)
        let icon = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)!
        let items = [text, link, picture].enumerated().map { index, content in
            let item = NSDraggingItem(pasteboardWriter: content)
            item.setDraggingFrame(NSRect(x: 100 + index * 8, y: 245, width: 50, height: 50), contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}
#endif
