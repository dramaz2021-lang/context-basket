import AppKit
import SwiftUI

final class ShelfHostingView: NSHostingView<ShelfView> {
    override var isOpaque: Bool { false }
    let drops: MaterialDropCoordinator

    init(store: BasketStore, close: @escaping () -> Void) {
        drops = MaterialDropCoordinator(store: store)
        super.init(rootView: ShelfView(store: store, drops: drops, close: close))
        sizingOptions = []
        registerForDraggedTypes(DropReader.types)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init(rootView: ShelfView) { fatalError() }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { drops.update(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { drops.update(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { drops.end() }
    override func draggingEnded(_ sender: NSDraggingInfo) { drops.end() }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        drops.receive(sender.draggingPasteboard, at: drops.location(for: sender))
    }
}
