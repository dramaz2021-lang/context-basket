import AppKit
import SwiftUI

final class ShelfHostingView: NSHostingView<ShelfView> {
    override var isOpaque: Bool { false }
    let presentation: ShelfPresentation
    let drops: MaterialDropCoordinator

    init(store: BasketStore, close: @escaping () -> Void) {
        presentation = ShelfPresentation(store: store)
        drops = MaterialDropCoordinator(store: store, presentation: presentation)
        super.init(rootView: ShelfView(store: store, ui: presentation, drops: drops, close: close))
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
        if sender.draggingPasteboard.types?.contains(MaterialDropCoordinator.materialType) == true {
            return drops.reorder(sender.draggingPasteboard, at: sender.draggingLocation)
        }
        return drops.receive(sender.draggingPasteboard, at: drops.location(for: sender))
    }
}
