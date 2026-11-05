import AppKit
import SwiftUI
import QuartzCore
import Combine

@MainActor
final class FloatingShelfController {
    let panel: ShelfPanel
    private let store: BasketStore
    private var expandedView: ShelfHostingView!
    private var compactView: CompactShelfHostingView!
    private var sizeObservation: AnyCancellable?
    private(set) var isCollapsed = true
    private var expandedSize = NSSize(width: BubbleLayout.expandedWidth, height: BubbleLayout.baseHeight)
    private let compactSize = NSSize(width: 58, height: 58)

    init(panel: ShelfPanel, store: BasketStore) {
        self.panel = panel
        self.store = store
        expandedView = ShelfHostingView(store: store) { [weak self] in self?.collapse() }
        compactView = CompactShelfHostingView(store: store, expand: { [weak self] in self?.expand() }, receive: { [weak self] info in
            self?.expandedView.performDragOperation(info) ?? false
        })
        panel.contentView = compactView
        updateSize()
        setFrame(size: compactSize, animate: false)
        sizeObservation = store.$items.combineLatest(store.$noteEditorID, store.$prompt, store.$errorMessage).dropFirst()
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.updateSize() }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func updateSize() {
        let available = (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 800
        expandedSize.height = BubbleLayout.expandedHeight(items: store.items, noteEditorID: store.noteEditorID, prompt: store.prompt, hasError: store.errorMessage != nil, available: available)
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

struct ShelfAnchorView: View {
    @ObservedObject var store: BasketStore
    var expanded = false
    let toggle: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: BasketArtwork.image(size: 34)).resizable().scaledToFit()
                .frame(width: 34, height: 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !store.items.isEmpty {
                Text(store.items.count > 99 ? "99+" : "\(store.items.count)")
                    .font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 2).background(.black.opacity(0.5), in: Capsule()).padding(5)
            }
            CompactHandle(expand: toggle)
        }
        .basketGlass(cornerRadius: 22, interactive: true)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("context basket 悬浮图标，\(store.items.count) 项材料，\(expanded ? "点击收起" : "点击展开")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
        .help(expanded ? "点击收起 · 拖动图标可移动" : "点击展开 · 拖文件到此展开 · 拖动图标可移动")
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

private final class CompactShelfHostingView: NSHostingView<ShelfAnchorView> {
    private let expand: () -> Void
    private let receive: (NSDraggingInfo) -> Bool
    override var isOpaque: Bool { false }
    init(store: BasketStore, expand: @escaping () -> Void, receive: @escaping (NSDraggingInfo) -> Bool) {
        self.expand = expand
        self.receive = receive
        super.init(rootView: ShelfAnchorView(store: store, toggle: expand))
        sizingOptions = []
        registerForDraggedTypes(DropReader.types)
    }
    @available(*, unavailable) required init(rootView: ShelfAnchorView) { fatalError() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { expand(); return .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { receive(sender) }
}
