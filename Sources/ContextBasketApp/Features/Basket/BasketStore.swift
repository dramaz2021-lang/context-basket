import AppKit
import Combine

/// The basket's content and settings. Every change to them is saved from one place;
/// what the window currently shows lives in `ShelfPresentation`.
@MainActor
final class BasketStore: ObservableObject {
    @Published private(set) var items: [Material] = [] { didSet { contentChanged() } }
    @Published private(set) var prompt = "" { didSet { contentChanged() } }
    @Published private(set) var importMode: FileImportMode = .copy { didSet { save() } }
    @Published private(set) var promptText = ""
    @Published private(set) var canUndo = false
    @Published var errorMessage: String?
    let library: MaterialLibrary

    private struct RemovalSnapshot {
        var entries: [(item: Material, index: Int)]
        var prompt: String?
    }

    private static let typingSaveDelay: Duration = .milliseconds(400)
    private var removed: RemovalSnapshot?
    private var thumbnails: [UUID: NSImage] = [:]
    private var converting: [UUID: Material] = [:]
    private var isRestoring = true
    private var isTyping = false
    private var pendingSave: Task<Void, Never>?

    init(library: MaterialLibrary) {
        self.library = library
        do {
            let document = try library.loadDocument()
            items = document.items
            prompt = document.prompt
            importMode = document.importMode
            library.removeUnreferenced(keeping: Set(document.items.map(\.id)))
        } catch {
            // Unread copies stay on disk: nothing is swept and the index is kept aside.
            library.setAsideUnreadableIndex()
            errorMessage = "上次的材料暂时无法恢复。原文件仍保存在本机。"
        }
        library.pruneExports()
        isRestoring = false
        refreshPrompt()
    }

    // MARK: Materials

    @discardableResult
    func add(_ incoming: [IncomingMaterial], mode: FileImportMode? = nil, hasStableSource: Bool = true) -> [Task<Void, Never>] {
        errorMessage = nil
        let selectedMode = hasStableSource ? (mode ?? importMode) : .copy
        return incoming.map { content in
            let id = UUID()
            items.append(.pending(id: id, title: content.title))
            let library = library
            return Task { [weak self] in
                let result = await Task.detached(priority: .userInitiated) { () -> Result<Material, Error> in
                    Result { try library.prepare(content, id: id, mode: selectedMode) }
                }.value
                guard let self else { return }
                switch result {
                case .success(var item):
                    if let index = self.items.firstIndex(where: { $0.id == id }) {
                        item.note = self.items[index].note
                        if !hasStableSource { item.forgetSource() }
                        self.items[index] = item
                    } else {
                        library.discard(id: id)
                    }
                case .failure(let error):
                    self.items.removeAll { $0.id == id }
                    library.discard(id: id)
                    self.errorMessage = "\(content.title)：\(error.localizedDescription)"
                }
            }
        }
    }

    /// True when the basket already holds this exact text, link or source file.
    func contains(_ incoming: IncomingMaterial) -> Bool {
        switch incoming {
        case .text(let text): return items.contains { $0.content == .text(text) }
        case .link(let url): return items.contains { $0.content == .link(url.absoluteString) }
        case .file(let url): return items.contains { $0.sourceURL == url.standardizedFileURL }
        case .image: return false
        }
    }

    /// Moves a material so it takes the given position; the others keep their order.
    func move(_ id: UUID, to position: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let target = max(0, min(position, items.count - 1))
        guard target != index else { return }
        var reordered = items
        reordered.insert(reordered.remove(at: index), at: target)
        items = reordered
    }

    func paste() {
        let incoming = DropReader.read(NSPasteboard.general)
        if incoming.isEmpty { errorMessage = "剪贴板里没有可添加的图片、文字或文件。" }
        else { add(incoming) }
    }

    @discardableResult
    func addLocation(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = DropReader.webURL(trimmed) {
            add([.link(url)])
        } else if let url = DropReader.localURL(trimmed) {
            add([.file(url)], mode: .reference)
        } else {
            errorMessage = "请输入网页链接，或以 /、~/、file:// 开头的本机地址。"
            return false
        }
        return true
    }

    @discardableResult
    func changeMode(_ id: UUID, to mode: FileImportMode) -> Task<Void, Never>? {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isLoading,
              items[index].importMode != mode, let source = items[index].sourceURL else { return nil }
        let old = items[index]
        converting[id] = old
        items[index].content = .pending
        let library = library
        return Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try library.prepare(.file(source), id: id, mode: mode) }
            }.value
            guard let self else { return }
            self.converting[id] = nil
            guard let index = self.items.firstIndex(where: { $0.id == id }) else { library.discard(id: id); return }
            self.thumbnails[id] = nil
            switch result {
            case .success(var item):
                item.note = self.items[index].note
                self.items[index] = item
                if item.isReference { library.removeCopy(id: id) }
            case .failure(let error):
                var restored = old
                restored.note = self.items[index].note
                self.items[index] = restored
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func thumbnail(for item: Material) -> NSImage? {
        if let cached = thumbnails[item.id] { return cached }
        guard let path = item.thumbnailPath else { return nil }
        let image = NSImage(contentsOf: library.url(for: path))
        thumbnails[item.id] = image
        return image
    }

    // MARK: Removal and undo

    var hasContent: Bool { !items.isEmpty || !prompt.isEmpty }

    func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        discardPreviousRemoval()
        let item = items.remove(at: index)
        if !item.isLoading { removed = RemovalSnapshot(entries: [(item, index)], prompt: nil) }
        canUndo = removed != nil
        thumbnails[id] = nil
    }

    func clearBasket() {
        guard hasContent else { return }
        discardPreviousRemoval()
        let entries = items.enumerated().compactMap { index, item in item.isLoading ? nil : (item: item, index: index) }
        removed = RemovalSnapshot(entries: entries, prompt: prompt)
        items = []
        prompt = ""
        thumbnails = [:]
        errorMessage = nil
        canUndo = true
    }

    func undoRemove() {
        guard let removed else { return }
        var restored = items
        for entry in removed.entries { restored.insert(entry.item, at: min(entry.index, restored.count)) }
        self.removed = nil
        canUndo = false
        items = restored
        if let previousPrompt = removed.prompt { prompt = previousPrompt }
    }

    private func discardPreviousRemoval() {
        for entry in removed?.entries ?? [] { library.discard(id: entry.item.id) }
        removed = nil
    }

    // MARK: Text and settings

    func setPrompt(_ value: String) { typing { prompt = value } }

    func setNote(_ id: UUID, _ value: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        typing { items[index].note = value }
    }

    func setImportMode(_ value: FileImportMode) { importMode = value }

    // MARK: Prompt

    var canExport: Bool { (!items.isEmpty || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && !items.contains(where: \.isLoading) }

    func export(_ selection: [Material]? = nil) throws -> PromptBundle {
        try PromptExporter.create(items: selection ?? items, prompt: selection == nil ? prompt : "", library: library)
    }

    @discardableResult
    func copyPrompt() -> Bool { copyPrompt(to: .general) }

    /// Returns whether the clipboard now holds the prompt.
    @discardableResult
    func copyPrompt(to pasteboard: NSPasteboard) -> Bool {
        do {
            try PromptExporter.validate(items: items, prompt: prompt)
            // Include the task file: browsers suppress clipboard text when files are present.
            // Finish the snapshot before replacing the user's clipboard.
            let files = items.contains { $0.attachmentPath != nil } ? try export().files : []
            guard PromptClipboardWriter.write(text: promptText, files: files, to: pasteboard) else {
                errorMessage = "暂时无法写入剪贴板，请重试。"
                return false
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshPrompt() {
        promptText = PromptFormat.text(items: items.filter { !$0.isLoading }, prompt: prompt)
    }

    // MARK: Saving

    /// Writes an edit that is still waiting for typing to pause, for example before quitting.
    func flush() {
        if pendingSave != nil { save() }
    }

    private func typing(_ edit: () -> Void) {
        isTyping = true
        edit()
        isTyping = false
    }

    private func contentChanged() {
        guard !isRestoring else { return }
        refreshPrompt()
        if isTyping { saveSoon() } else { save() }
    }

    /// One write per burst of keystrokes instead of one per character.
    private func saveSoon() {
        guard pendingSave == nil else { return }
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.typingSaveDelay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        guard !isRestoring else { return }
        pendingSave?.cancel()
        pendingSave = nil
        // A material being converted is saved as it was, so quitting midway loses nothing.
        let stableItems = items.map { item -> Material in
            guard var previous = converting[item.id] else { return item }
            previous.note = item.note
            return previous
        }
        do { try library.saveDocument(BasketDocument(items: stableItems, prompt: prompt, importMode: importMode)) }
        catch { errorMessage = "当前更改暂时无法保存：\(error.localizedDescription)" }
    }
}
