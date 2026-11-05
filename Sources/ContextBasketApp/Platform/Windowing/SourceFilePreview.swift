import AppKit
import Quartz

/// Finder reveals the source; the system Quick Look panel reads that exact URL.
@MainActor
final class SourceFilePreview: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = SourceFilePreview()
    private(set) var sourceURL: URL?

    func show(_ url: URL) {
        sourceURL = url
        NSWorkspace.shared.activateFileViewerSelecting([url])
        NSApp.activate(ignoringOtherApps: true)
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)
        panel.updateController()
        panel.reloadData()
        panel.refreshCurrentPreviewItem()
    }

    // AppDelegate participates in the responder chain and forwards ownership here.
    func begin(_ panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.delegate = self
    }
    func end(_ panel: QLPreviewPanel) {
        panel.dataSource = nil
        panel.delegate = nil
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { sourceURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        sourceURL as NSURL?
    }
}
