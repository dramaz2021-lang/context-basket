import AppKit
import Combine

/// What one basket window is showing right now. Nothing here is saved, and folding
/// the window leaves it untouched.
@MainActor
final class ShelfPresentation: ObservableObject {
    @Published var dropFeedback: DropFeedback?
    @Published var preview: Material?
    @Published var noteEditorID: UUID?
    @Published var showLocationEditor = false
    @Published var showPromptPreview = false
    /// The card a dragged card would take the place of.
    @Published var reorderTarget: UUID?
    @Published private(set) var justCopied = false
    /// True while this window drags its own prompt out, so it does not accept it back.
    var isExporting = false
    private let store: BasketStore
    private var contentObservation: AnyCancellable?
    private var copiedReset: Task<Void, Never>?

    init(store: BasketStore) {
        self.store = store
        contentObservation = store.$items.combineLatest(store.$prompt).sink { [weak self] items, prompt in
            self?.contentChanged(items: items, prompt: prompt)
        }
    }

    func editNote(_ id: UUID) { noteEditorID = id }
    func finishNoteEditing() { noteEditorID = nil }

    func presentPromptPreview() {
        guard store.canExport else { return }
        showPromptPreview = true
    }

    /// Copying replaces the clipboard without any visible trace, so the button confirms it briefly.
    func copyPrompt() { copyPrompt(to: .general) }

    func copyPrompt(to pasteboard: NSPasteboard) {
        guard store.copyPrompt(to: pasteboard) else { return }
        justCopied = true
        copiedReset?.cancel()
        copiedReset = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.justCopied = false
        }
    }

    func open(_ item: Material) {
        guard !item.isLoading else { return }
        do {
            switch try MaterialOpenDestination.resolve(item) {
            case .inApp: preview = item
            case .sourceFile(let url): SourceFilePreview.shared.show(url)
            case .website(let url):
                if !NSWorkspace.shared.open(url) { store.errorMessage = "暂时无法打开这个网址。" }
            }
        } catch { store.errorMessage = error.localizedDescription }
    }

    func chooseFiles() {
        let mode = store.importMode
        let picker = NSOpenPanel()
        picker.title = "添加材料"
        picker.prompt = "添加"
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = mode == .reference
        NSApp.activate(ignoringOtherApps: true)
        picker.begin { [store] response in
            if response == .OK { store.add(picker.urls.map(IncomingMaterial.file), mode: mode) }
        }
        picker.makeKeyAndOrderFront(nil)
    }

    /// Sheets and editors never outlive the material or content they belong to.
    private func contentChanged(items: [Material], prompt: String) {
        if let id = preview?.id, !items.contains(where: { $0.id == id }) { preview = nil }
        if let id = noteEditorID, !items.contains(where: { $0.id == id }) { noteEditorID = nil }
        if showPromptPreview, items.isEmpty, prompt.isEmpty { showPromptPreview = false }
        if justCopied { justCopied = false }
    }
}
