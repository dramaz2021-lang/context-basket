import AppKit
import Combine

@MainActor
final class BasketStore: ObservableObject {
    @Published private(set) var items: [Material] = []
    @Published var isDragOver = false
    @Published var errorMessage: String?
    @Published var preview: Material?
    @Published private(set) var canUndo = false
    let library: MaterialLibrary
    private var removed: (Material, Int)?
    private var thumbnails: [UUID: NSImage] = [:]
    var onCountChanged: (() -> Void)?

    init(library: MaterialLibrary) {
        self.library = library
        do { items = try library.load() }
        catch { errorMessage = "上次的材料暂时无法恢复。原文件仍保存在本机。" }
    }

    @discardableResult
    func add(_ incoming: [IncomingMaterial]) -> [Task<Void, Never>] {
        errorMessage = nil
        return incoming.map { content in
            let id = UUID()
            items.append(.pending(id: id, title: content.title))
            onCountChanged?()
            let library = library
            return Task { [weak self] in
                let result = await Task.detached(priority: .userInitiated) { () -> Result<Material, Error> in
                    Result { try library.prepare(content, id: id) }
                }.value
                guard let self else { return }
                switch result {
                case .success(let item):
                    if let index = self.items.firstIndex(where: { $0.id == id }) {
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
        if let previous = removed { library.discard(id: previous.0.id) }
        let item = items.remove(at: index)
        removed = item.isLoading ? nil : (item, index)
        canUndo = removed != nil
        thumbnails[id] = nil
        if preview?.id == id { preview = nil }
        persist()
        onCountChanged?()
    }

    func undoRemove() {
        guard let (item, index) = removed else { return }
        items.insert(item, at: min(index, items.count))
        removed = nil
        canUndo = false
        persist()
        onCountChanged?()
    }

    func thumbnail(for item: Material) -> NSImage? {
        if let cached = thumbnails[item.id] { return cached }
        guard let path = item.thumbnailPath else { return nil }
        let image = NSImage(contentsOf: library.url(for: path))
        thumbnails[item.id] = image
        return image
    }

    func chooseFiles() {
        let picker = NSOpenPanel()
        picker.title = "添加材料"
        picker.prompt = "添加"
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        picker.begin { [weak self] response in
            if response == .OK { self?.add(picker.urls.map(IncomingMaterial.file)) }
        }
        picker.makeKeyAndOrderFront(nil)
    }

    func paste() {
        let incoming = DropReader.read(NSPasteboard.general)
        if incoming.isEmpty { errorMessage = "剪贴板里没有可添加的图片、文字或文件。" }
        else { add(incoming) }
    }

    private func persist() {
        do { try library.save(items) }
        catch { errorMessage = "材料已添加，但暂时无法保存：\(error.localizedDescription)" }
    }
}
