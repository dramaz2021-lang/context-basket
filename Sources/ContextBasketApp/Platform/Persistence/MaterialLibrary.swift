import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Sole owner of everything under the app's data folder: the index, imported copies,
/// thumbnails and export snapshots. It never deletes a source file.
final class MaterialLibrary: @unchecked Sendable {
    static let exportsAlwaysKept = 3
    static let exportLifetime: TimeInterval = 24 * 60 * 60

    let directory: URL
    private let index: URL

    init(directory: URL? = nil) throws {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ContextBasket", isDirectory: true)
        index = self.directory.appendingPathComponent("basket.json")
        try FileManager.default.createDirectory(at: self.directory.appendingPathComponent("assets"), withIntermediateDirectories: true)
    }

    // MARK: Index

    func loadDocument() throws -> BasketDocument {
        guard FileManager.default.fileExists(atPath: index.path) else {
            return BasketDocument(items: [], prompt: "", importMode: .copy)
        }
        let data = try Data(contentsOf: index)
        if let document = try? JSONDecoder().decode(BasketDocument.self, from: data) {
            guard document.version == 2 else { throw ImportError.unknownVersion }
            return document
        }
        return BasketDocument(items: try JSONDecoder().decode([Material].self, from: data), prompt: "", importMode: .copy)
    }

    func saveDocument(_ document: BasketDocument) throws {
        var saved = document
        saved.items.removeAll { $0.isLoading }
        let data = try JSONEncoder().encode(saved)
        try data.write(to: index, options: .atomic)
    }

    /// Keeps an index this version cannot read, so the next save does not overwrite it.
    func setAsideUnreadableIndex() {
        let backup = directory.appendingPathComponent("basket.unreadable.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: index, to: backup)
    }

    // MARK: Imported copies

    func url(for path: String) -> URL { directory.appendingPathComponent(path) }

    func prepare(_ incoming: IncomingMaterial, id: UUID, mode: FileImportMode = .copy) throws -> Material {
        switch incoming {
        case .text(let text):
            return Material(id: id, title: incoming.title, detail: "\(text.count) 字", content: .text(text))
        case .link(let url):
            return Material(id: id, title: incoming.title, detail: "链接", content: .link(url.absoluteString))
        case .image(let data):
            let file = try assetFolder(id).appendingPathComponent("图片.png")
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)
            else { throw ImportError.unreadableImage }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { throw ImportError.unreadableImage }
            return try copyMaterial(at: file, id: id, source: nil)
        case .file(let original):
            let scoped = original.startAccessingSecurityScopedResource()
            defer { if scoped { original.stopAccessingSecurityScopedResource() } }
            let values = try original.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            let source = original.standardizedFileURL
            if mode == .reference {
                if values.isDirectory == true {
                    return Material(id: id, title: original.lastPathComponent, detail: "文件夹 · 引用原位置",
                                    content: .reference(source: source, thumbnailPath: nil))
                }
                let facts = try inspect(original, id: id)
                return Material(id: id, title: original.lastPathComponent, detail: facts.detail,
                                content: .reference(source: source, thumbnailPath: facts.thumbnailPath))
            }
            guard values.isRegularFile == true else { throw ImportError.unsupportedFolder }
            guard (values.fileSize ?? 0) <= 100 * 1024 * 1024 else { throw ImportError.tooLarge }
            let copy = try assetFolder(id).appendingPathComponent(original.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) { try FileManager.default.removeItem(at: copy) }
            try FileManager.default.copyItem(at: original, to: copy)
            return try copyMaterial(at: copy, id: id, source: source)
        }
    }

    /// Removes the copy and thumbnail of a material that left the basket for good.
    func discard(id: UUID) {
        removeCopy(id: id)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("thumbnails/\(id.uuidString)"))
    }

    /// Removes only the copy, for a material that now references its source instead.
    func removeCopy(id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("assets/\(id.uuidString)"))
    }

    /// Removes copies and thumbnails that no material in the index refers to, such as
    /// removals whose undo was still available when the app quit.
    func removeUnreferenced(keeping ids: Set<UUID>) {
        for name in ["assets", "thumbnails"] {
            let folder = directory.appendingPathComponent(name)
            for entry in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
                guard let id = UUID(uuidString: entry), !ids.contains(id) else { continue }
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(entry))
            }
        }
    }

    // MARK: Export snapshots

    private var exports: URL { directory.appendingPathComponent("exports", isDirectory: true) }

    func makeExportFolder() throws -> URL {
        pruneExports()
        let folder = exports.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func removeExport(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Snapshots must outlive the paste or drop that uses them, so the newest ones and
    /// everything recent stay; only older snapshots are removed.
    func pruneExports(now: Date = Date()) {
        let folders = (try? FileManager.default.contentsOfDirectory(at: exports, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let dated = folders.map { folder in
            (folder: folder, created: (try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
        }.sorted { $0.created > $1.created }
        for entry in dated.dropFirst(Self.exportsAlwaysKept) where now.timeIntervalSince(entry.created) > Self.exportLifetime {
            removeExport(entry.folder)
        }
    }

    // MARK: Private

    private func assetFolder(_ id: UUID) throws -> URL {
        let folder = directory.appendingPathComponent("assets/\(id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func copyMaterial(at file: URL, id: UUID, source: URL?) throws -> Material {
        let facts = try inspect(file, id: id)
        let copy = Material.Copy(assetPath: "assets/\(id.uuidString)/\(file.lastPathComponent)",
                                 thumbnailPath: facts.thumbnailPath, text: facts.text, sourceURL: source)
        return Material(id: id, title: file.lastPathComponent, detail: facts.detail, content: .copy(copy))
    }

    /// Images get a thumbnail, small text files their verbatim content, everything else a size.
    private func inspect(_ file: URL, id: UUID) throws -> (detail: String, thumbnailPath: String?, text: String?) {
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if let source = CGImageSourceCreateWithURL(file as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int {
            let thumbnailFolder = directory.appendingPathComponent("thumbnails/\(id.uuidString)")
            try FileManager.default.createDirectory(at: thumbnailFolder, withIntermediateDirectories: true)
            let thumbnail = "thumbnails/\(id.uuidString)/preview.png"
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 640
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
               let destination = CGImageDestinationCreateWithURL(url(for: thumbnail) as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                if CGImageDestinationFinalize(destination) { return ("\(width) × \(height)", thumbnail, nil) }
            }
        }
        let type = (try? file.resourceValues(forKeys: [.contentTypeKey]).contentType)
        if type?.conforms(to: .text) == true, size <= 1_000_000,
           let text = try? String(contentsOf: file, encoding: .utf8) {
            return ("\(text.count) 字 · \(file.pathExtension.uppercased())", nil, text)
        }
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        return ("\(file.pathExtension.uppercased()) · \(formattedSize)", nil, nil)
    }
}

enum ImportError: LocalizedError {
    case unreadableImage, unsupportedFolder, tooLarge, unknownVersion
    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "这张图片无法读取，请换一个图片文件试试。"
        case .unsupportedFolder: return "文件夹请使用“源文件地址”模式添加。"
        case .tooLarge: return "这份文件超过 100 MB，请先添加较小的材料。"
        case .unknownVersion: return "此材料组由较新版本创建，请更新应用后再打开。"
        }
    }
}
