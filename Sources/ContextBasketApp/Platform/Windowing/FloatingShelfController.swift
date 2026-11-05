import AppKit
import SwiftUI
import QuartzCore

@MainActor
final class FloatingShelfController {
    let panel: ShelfPanel
    private let store: BasketStore
    private var expandedView: ShelfHostingView!
    private var compactView: CompactShelfHostingView!
    private(set) var isCollapsed = false
    private var expandedSize = NSSize(width: 460, height: 500)
    private let compactSize = NSSize(width: 58, height: 58)

    init(panel: ShelfPanel, store: BasketStore) {
        self.panel = panel
        self.store = store
        expandedView = ShelfHostingView(store: store) { [weak self] in self?.collapse() }
        compactView = CompactShelfHostingView(store: store, expand: { [weak self] in self?.expand() }, receive: { [weak self] info in
            self?.expandedView.performDragOperation(info) ?? false
        })
        panel.contentView = expandedView
    }

    func show() {
        expand()
        panel.orderFrontRegardless()
    }

    func updateSize() {
        let rows = (store.items.count + 1) / 2
        let available = (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 800
        expandedSize.height = min(available - 32, store.items.isEmpty ? 500 : min(710, 310 + CGFloat(rows) * 185))
        guard !isCollapsed else { return }
        setFrame(size: expandedSize, animate: false)
    }

    func expand() {
        guard isCollapsed else { return }
        isCollapsed = false
        // Keep the hosting view alive: scrolling and in-progress SwiftUI state survive folding.
        panel.contentView = expandedView
        setFrame(size: expandedSize, animate: true)
        panel.makeFirstResponder(nil)
    }

    func collapse() {
        guard !isCollapsed else { return }
        isCollapsed = true
        panel.makeFirstResponder(nil)
        panel.contentView = compactView
        setFrame(size: compactSize, animate: true)
    }

    private func setFrame(size: NSSize, animate: Bool) {
        let old = panel.frame
        var next = NSRect(x: old.minX, y: old.maxY - size.height, width: size.width, height: size.height)
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: old.midX, y: old.midY)) } ?? panel.screen ?? NSScreen.main
        if let visible = screen?.visibleFrame.insetBy(dx: 8, dy: 8) {
            next.origin.x = max(visible.minX, min(next.minX, visible.maxX - next.width))
            next.origin.y = max(visible.minY, min(next.minY, visible.maxY - next.height))
        }
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(next, display: true)
            }
        } else { panel.setFrame(next, display: true) }
    }


}

private struct CompactShelfView: View {
    @ObservedObject var store: BasketStore
    let expand: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.08, green: 0.10, blue: 0.12).opacity(0.58))
            Image(systemName: "tray.full.fill").font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color(red: 0.65, green: 0.88, blue: 0.76))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !store.items.isEmpty {
                Text(store.items.count > 99 ? "99+" : "\(store.items.count)")
                    .font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 2).background(.black.opacity(0.5), in: Capsule()).padding(5)
            }
            CompactHandle(expand: expand)
        }
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.28)).allowsHitTesting(false) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("context basket 悬浮图标，\(store.items.count) 项材料，点击展开")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { expand() }
        .help("点击展开 · 拖文件到此展开 · 拖动图标可移动")
    }
}

private struct CompactHandle: NSViewRepresentable {
    let expand: () -> Void
    final class Handle: NSView {
        var expand: () -> Void = {}
        private var downEvent: NSEvent?
        private var moved = false
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { downEvent = event; moved = false }
        override func mouseDragged(with event: NSEvent) {
            guard let window, let downEvent, !moved else { return }
            moved = true
            let alpha = window.alphaValue
            window.alphaValue = 0.55
            window.performDrag(with: downEvent)
            window.alphaValue = alpha
        }
        override func mouseUp(with event: NSEvent) { if !moved { expand() }; downEvent = nil }
    }
    func makeNSView(context: Context) -> Handle { let view = Handle(); view.expand = expand; return view }
    func updateNSView(_ view: Handle, context: Context) { view.expand = expand }
}

private final class CompactShelfHostingView: NSHostingView<CompactShelfView> {
    private let expand: () -> Void
    private let receive: (NSDraggingInfo) -> Bool
    override var isOpaque: Bool { false }
    init(store: BasketStore, expand: @escaping () -> Void, receive: @escaping (NSDraggingInfo) -> Bool) {
        self.expand = expand
        self.receive = receive
        super.init(rootView: CompactShelfView(store: store, expand: expand))
        sizingOptions = []
        registerForDraggedTypes(DropReader.types)
    }
    @available(*, unavailable) required init(rootView: CompactShelfView) { fatalError() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { expand(); return .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { receive(sender) }
}
