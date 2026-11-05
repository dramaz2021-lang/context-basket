#if DEBUG
import AppKit

/// Manual drag fixture; excluded entirely from release builds.
@MainActor
func makeDragHarness(store: BasketStore) -> NSWindow {
    let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ContextBasket-UI-\(UUID())")
    let testStore = BasketStore(library: try! MaterialLibrary(directory: testDirectory))
    let fixture = testDirectory.appendingPathComponent("待修改原文件.txt")
    try! "这是合成测试源文件。原文件不能因拖动或删除而改变。".write(to: fixture, atomically: true, encoding: .utf8)
    let window = NSWindow(contentRect: NSRect(x: 100, y: 80, width: 750, height: 710), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Prompt 验收 · 合成材料 · 独立数据"
    window.isReleasedWhenClosed = false
    window.level = .floating
    window.appearance = NSAppearance(named: .darkAqua)
    window.acceptsMouseMovedEvents = true
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 750, height: 710))
    let source = DragFixtureSource(frame: NSRect(x: 0, y: 400, width: 280, height: 310))
    source.fixture = fixture
    let receiver = ExportFixtureReceiver(frame: NSRect(x: 15, y: 20, width: 255, height: 360))
    let destination = ShelfHostingView(store: testStore, close: {})
    destination.frame = NSRect(x: 285, y: 5, width: 460, height: 700)
    container.addSubview(source)
    container.addSubview(receiver)
    container.addSubview(destination)
    window.contentView = container
    return window
}

private final class DragFixtureSource: NSView, NSDraggingSource {
    var fixture: URL!
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let rect = NSRect(x: 25, y: 100, width: 230, height: 125)
        NSColor.systemGreen.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()
        let text = "拖动这里 →\n文字 + 链接 + 图片\n+ 本机文件\n四个独立材料"
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
        let file = NSPasteboardItem()
        file.setString(fixture.absoluteString, forType: .fileURL)
        let items = [text, link, picture, file].enumerated().map { index, content in
            let item = NSDraggingItem(pasteboardWriter: content)
            item.setDraggingFrame(NSRect(x: 100 + index * 8, y: 160, width: 50, height: 50), contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}

private final class ExportFixtureReceiver: NSView {
    private var report = "← 拖出全部到这里\n\n检查实际交付的文件和说明"
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL, .string]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()
        (report as NSString).draw(in: bounds.insetBy(dx: 15, dy: 20), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard let prompt = urls.first(where: { $0.lastPathComponent == "PROMPT.txt" }), let text = try? String(contentsOf: prompt, encoding: .utf8) else { return false }
        report = "已接收 \(urls.count) 个文件\n" + urls.map(\.lastPathComponent).joined(separator: "\n")
        report += "\n\n指令：" + (text.contains("检查排版") ? "通过" : "待填写")
        report += "\n文件说明：" + (text.contains("重点修改标题") ? "通过" : "待填写")
        report += "\n源地址：" + (text.contains("源文件本机路径") ? "已保留" : "未设置")
        report += "\n原文件附件：" + (urls.contains { $0.lastPathComponent.contains("待修改原文件") } ? "存在（副本）" : "未附带")
        report += "\n\n" + String(text.prefix(200))
        needsDisplay = true
        return true
    }
}
#endif
