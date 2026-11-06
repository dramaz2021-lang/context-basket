import AppKit
import SwiftUI

@MainActor
final class MaterialDropCoordinator {
    private let store: BasketStore
    private let promiseQueue = OperationQueue()
    private struct WeakArea { weak var view: NSView? }
    private var collectionAreas: [Int: WeakArea] = [:]
    weak var promptArea: NSView?
    weak var iconArea: NSView?

    init(store: BasketStore) { self.store = store }

    func registerCollectionArea(_ view: NSView, slot: Int) { collectionAreas[slot] = WeakArea(view: view) }

    func location(for sender: NSDraggingInfo) -> DropLocation {
        location(at: sender.draggingLocation)
    }

    func location(at windowPoint: NSPoint) -> DropLocation {
        if let area = promptArea, area.bounds.contains(area.convert(windowPoint, from: nil)) { return .prompt }
        if let area = iconArea, area.bounds.contains(area.convert(windowPoint, from: nil)) { return .collectionLeft }
        if let (_, area) = collectionTarget(at: windowPoint) {
            let point = area.convert(windowPoint, from: nil)
            if area.bounds.contains(point) { return point.x < area.bounds.midX ? .collectionLeft : .collectionRight }
        }
        return .other
    }

    private func collectionTarget(at windowPoint: NSPoint) -> (Int, NSView)? {
        for (slot, entry) in collectionAreas {
            guard let area = entry.view, area.window != nil, !area.isHiddenOrHasHiddenAncestor else { continue }
            let point = area.convert(windowPoint, from: nil)
            if area.bounds.contains(point), area.visibleRect.contains(point) { return (slot, area) }
        }
        return nil
    }

    func update(_ sender: NSDraggingInfo, at location: DropLocation? = nil) -> NSDragOperation {
        guard !store.isExporting else { end(); return [] }
        var next = DropPolicy.feedback(profile: .inspect(sender.draggingPasteboard), location: location ?? self.location(for: sender))
        next?.targetSlot = collectionTarget(at: sender.draggingLocation)?.0
        if store.dropFeedback != next { store.dropFeedback = next }
        return next == nil ? [] : .copy
    }

    func end() { store.dropFeedback = nil }

    @discardableResult
    func receive(_ pasteboard: NSPasteboard, at location: DropLocation) -> Bool {
        end()
        guard !store.isExporting, let feedback = DropPolicy.feedback(profile: .inspect(pasteboard), location: location) else { return false }
        // Plain text belongs to the native instruction editor, not to this importer.
        guard feedback.style != .promptText else { return false }
        let incoming = DropReader.read(pasteboard)
        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        if !promises.isEmpty && !incoming.contains(where: { if case .file = $0 { return true }; return false }) {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ContextBasket-\(UUID())")
            do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
            catch { store.errorMessage = "暂时无法接收这份材料。"; return false }
            for promise in promises {
                promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promiseQueue) { [weak self] url, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if error != nil { self.store.errorMessage = "这份拖入的材料未能完成传输，请重试。"; return }
                        for task in self.store.add([.file(url)], hasStableSource: false) { await task.value }
                        try? FileManager.default.removeItem(at: url)
                        if (try? FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty) == true { try? FileManager.default.removeItem(at: folder) }
                    }
                }
            }
            return true
        }
        guard !incoming.isEmpty else { return false }
        store.add(incoming, mode: feedback.mode)
        return true
    }
}

/// Read real layout bounds instead of relying on a fixed editor height for hit testing.
struct DropAreaMarker: NSViewRepresentable {
    let coordinator: MaterialDropCoordinator
    var isPrompt = false
    var isIcon = false
    var slot = 0
    final class Marker: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
    func makeNSView(context: Context) -> Marker {
        let view = Marker()
        register(view)
        return view
    }
    func updateNSView(_ view: Marker, context: Context) { register(view) }

    private func register(_ view: Marker) {
        if isPrompt { coordinator.promptArea = view }
        else if isIcon { coordinator.iconArea = view }
        else { coordinator.registerCollectionArea(view, slot: slot) }
    }
}
