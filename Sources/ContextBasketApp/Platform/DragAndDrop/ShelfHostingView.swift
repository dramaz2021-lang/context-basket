import AppKit
import SwiftUI

final class ShelfHostingView: NSHostingView<ShelfView> {
    private let store: BasketStore
    private let promiseQueue = OperationQueue()

    init(store: BasketStore, close: @escaping () -> Void) {
        self.store = store
        super.init(rootView: ShelfView(store: store, close: close))
        registerForDraggedTypes(DropReader.types)
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init(rootView: ShelfView) { fatalError() }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = !store.isExporting && sender.draggingPasteboard.availableType(from: DropReader.types) != nil
        store.activeDropMode = NSEvent.modifierFlags.contains(.option) ? .reference : store.importMode
        store.isDragOver = accepted
        return accepted ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { store.isDragOver = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { store.isDragOver = false }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        store.isDragOver = false
        guard !store.isExporting else { return false }
        let mode = NSEvent.modifierFlags.contains(.option) ? FileImportMode.reference : store.importMode
        let pasteboard = sender.draggingPasteboard
        let incoming = DropReader.read(pasteboard)
        // File promises (e.g. browser images) should be materialized rather than saved as their URL.
        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        if !promises.isEmpty && !incoming.contains(where: { if case .file = $0 { return true }; return false }) {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ContextBasket-\(UUID().uuidString)")
            do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
            catch { store.errorMessage = "暂时无法接收这份材料。"; return false }
            for promise in promises {
                promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promiseQueue) { [weak self] url, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if error != nil { self.store.errorMessage = "这份拖入的材料未能完成传输，请重试。"; return }
                        let tasks = self.store.add([.file(url)], hasStableSource: false)
                        if mode == .reference { self.store.statusMessage = "这份材料来自应用临时传输，已保留副本；它没有稳定的本机源地址。" }
                        for task in tasks { await task.value }
                        try? FileManager.default.removeItem(at: url)
                        if (try? FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty) == true {
                            try? FileManager.default.removeItem(at: folder)
                        }
                    }
                }
            }
            return true
        }
        guard !incoming.isEmpty else { return false }
        store.add(incoming, mode: mode)
        return true
    }
}
