import AppKit
import Combine

@MainActor
final class BasketStore: ObservableObject {
    @Published private(set) var items: [Material] = [] { didSet { refreshPrompt() } }
    @Published var dropFeedback: DropFeedback?
    var isDragOver: Bool { dropFeedback != nil }
    @Published var errorMessage: String?
    @Published var preview: Material?
    @Published private(set) var canUndo = false
    @Published private(set) var prompt = "" { didSet { refreshPrompt() } }
    @Published private(set) var importMode: FileImportMode = .copy
    @Published private(set) var automaticallyCollectClipboard = true
    @Published var noteEditorID: UUID?
    @Published var showLocationEditor = false
    @Published var showPromptPreview = false
    @Published private(set) var promptText = ""
    @Published var statusMessage: String?
    @Published var isExporting = false
    @Published var isChoosingFiles = false
    let library: MaterialLibrary
    private var removed: (items: [(item: Material, index: Int)], prompt: String?)?
    private var thumbnails: [UUID: NSImage] = [:]
    private var converting: [UUID: Material] = [:]
    var onCountChanged: (() -> Void)?
    var onClipboardCollectionChanged: ((Bool) -> Void)?

    init(library: MaterialLibrary) {
        self.library = library
        do {
            let document = try library.loadDocument()
            items = document.items
            prompt = document.prompt
            importMode = document.importMode
            automaticallyCollectClipboard = document.automaticallyCollectClipboard
        }
        catch { errorMessage = "上次的材料暂时无法恢复。原文件仍保存在本机。" }
        refreshPrompt()
    }

    @discardableResult
    func add(_ incoming: [IncomingMaterial], mode: FileImportMode? = nil, hasStableSource: Bool = true) -> [Task<Void, Never>] {
        errorMessage = nil
        let selectedMode = hasStableSource ? (mode ?? importMode) : .copy
        return incoming.map { content in
            let id = UUID()
            items.append(.pending(id: id, title: content.title))
            onCountChanged?()
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
                        if !hasStableSource { item.sourceURL = nil }
                        self.items[index] = item
                        self.persist()
                    } else {
                        library.discard(id: id)
                    }
                case .failure(let error):
                    self.items.removeAll { $0.id == id }
                    library.discard(id: id)
                    self.errorMessage = "\(content.title)：\(error.localizedDescription)"
                }
                self.onCountChanged?()
            }
        }
    }

    func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        discardPreviousRemoval()
        let item = items.remove(at: index)
        removed = item.isLoading ? nil : ([(item, index)], nil)
        canUndo = removed != nil
        thumbnails[id] = nil
        if preview?.id == id { preview = nil }
        persist()
        onCountChanged?()
    }

    func undoRemove() {
        guard let removed else { return }
        for entry in removed.items { items.insert(entry.item, at: min(entry.index, items.count)) }
        if let previousPrompt = removed.prompt { prompt = previousPrompt }
        self.removed = nil
        canUndo = false
        persist()
        onCountChanged?()
    }

    var hasContent: Bool { !items.isEmpty || !prompt.isEmpty }

    func clearBasket() {
        guard hasContent else { return }
        discardPreviousRemoval()
        let stableItems = items.enumerated().compactMap { index, item -> (item: Material, index: Int)? in
            guard !item.isLoading else { return nil }
            return (item, index)
        }
        removed = (stableItems, prompt)
        items = []
        prompt = ""
        thumbnails = [:]
        preview = nil
        noteEditorID = nil
        showPromptPreview = false
        errorMessage = nil
        statusMessage = nil
        canUndo = true
        persist()
        onCountChanged?()
    }

    private func discardPreviousRemoval() {
        for entry in removed?.items ?? [] { library.discard(id: entry.item.id) }
        removed = nil
    }

    func thumbnail(for item: Material) -> NSImage? {
        if let cached = thumbnails[item.id] { return cached }
        guard let path = item.thumbnailPath else { return nil }
        let image = NSImage(contentsOf: library.url(for: path))
        thumbnails[item.id] = image
        return image
    }

    func chooseFiles() { chooseFiles(mode: importMode) }

    func chooseFiles(mode: FileImportMode) {
        isChoosingFiles = true
        let picker = NSOpenPanel()
        picker.title = "添加材料"
        picker.prompt = "添加"
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = mode == .reference
        NSApp.activate(ignoringOtherApps: true)
        picker.begin { [weak self] response in
            self?.isChoosingFiles = false
            if response == .OK { self?.add(picker.urls.map(IncomingMaterial.file), mode: mode) }
        }
        picker.makeKeyAndOrderFront(nil)
    }

    func paste() {
        let incoming = DropReader.read(NSPasteboard.general)
        if incoming.isEmpty { errorMessage = "剪贴板里没有可添加的图片、文字或文件。" }
        else { add(incoming) }
    }

    func setPrompt(_ value: String) { prompt = value; persist() }
    func setImportMode(_ value: FileImportMode) { importMode = value; persist() }

    func setAutomaticallyCollectClipboard(_ value: Bool) {
        guard automaticallyCollectClipboard != value else { return }
        automaticallyCollectClipboard = value
        onClipboardCollectionChanged?(value)
        persist()
    }

    func setNote(_ id: UUID, _ value: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].note = value
        persist()
    }

    func editNote(_ id: UUID) { noteEditorID = id }
    func finishNoteEditing() { noteEditorID = nil }

    @discardableResult
    func changeMode(_ id: UUID, to mode: FileImportMode) -> Task<Void, Never>? {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isLoading,
              items[index].importMode != mode, let source = items[index].sourceURL else { return nil }
        let old = items[index]
        converting[id] = old
        items[index].isLoading = true
        let library = library
        return Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try library.prepare(.file(source), id: id, mode: mode) }
            }.value
            guard let self else { return }
            self.converting[id] = nil
            guard let index = self.items.firstIndex(where: { $0.id == id }) else { library.discard(id: id); return }
            switch result {
            case .success(var item):
                item.note = self.items[index].note
                self.items[index] = item
                self.thumbnails[id] = nil
            case .failure(let error):
                var restored = old
                restored.note = self.items[index].note
                self.items[index] = restored
                self.errorMessage = error.localizedDescription
            }
            self.persist()
        }
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

    private func refreshPrompt() {
        promptText = PromptExporter.text(items: items.filter { !$0.isLoading }, prompt: prompt)
    }
    var canExport: Bool { (!items.isEmpty || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && !items.contains(where: \.isLoading) }

    func export(_ selection: [Material]? = nil) throws -> PromptBundle {
        try PromptExporter.create(items: selection ?? items, prompt: selection == nil ? prompt : "", library: library)
    }

    func copyPrompt() { copyPrompt(to: .general) }

    func copyPrompt(to pasteboard: NSPasteboard) {
        do {
            try PromptExporter.validate(items: items, prompt: prompt)
            let text = promptText
            // Include the task file: browsers suppress clipboard text when files are present.
            // Finish the snapshot before replacing the user's clipboard.
            let files = items.contains { !$0.isReference && $0.assetPath != nil }
                ? try PromptExporter.create(items: items, prompt: prompt, library: library).files
                : []
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            item.setString(ClipboardMonitor.sourceIdentifier, forType: ClipboardMonitor.sourceType)
            // Keep text and the first file on one item so readers can discover both types.
            if let first = files.first { item.setString(first.absoluteString, forType: .fileURL) }
            var objects: [NSPasteboardWriting] = [item]
            objects.append(contentsOf: files.dropFirst().map { $0 as NSURL })
            pasteboard.clearContents()
            guard pasteboard.writeObjects(objects) else {
                errorMessage = "暂时无法写入剪贴板，请重试。"
                return
            }
            errorMessage = nil
            statusMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func presentPromptPreview() {
        guard canExport else { return }
        showPromptPreview = true
    }

    func previewURL(for item: Material) -> URL? {
        item.isReference ? item.sourceURL : item.assetPath.map(library.url(for:))
    }

    func openMaterial(_ item: Material) {
        guard !item.isLoading else { return }
        do {
            switch try MaterialOpenDestination.resolve(item) {
            case .inApp: preview = item
            case .sourceFile(let url): SourceFilePreview.shared.show(url)
            case .website(let url):
                if !NSWorkspace.shared.open(url) { errorMessage = "暂时无法打开这个网址。" }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func persist() {
        let stableItems = items.map { item -> Material in
            guard var previous = converting[item.id] else { return item }
            previous.note = item.note
            return previous
        }
        do { try library.saveDocument(BasketDocument(items: stableItems, prompt: prompt, importMode: importMode, automaticallyCollectClipboard: automaticallyCollectClipboard)) }
        catch { errorMessage = "当前更改暂时无法保存：\(error.localizedDescription)" }
    }
}
