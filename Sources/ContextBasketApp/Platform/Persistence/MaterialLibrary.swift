import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Owns imported copies only. Removing a card never touches the source file.
final class MaterialLibrary: @unchecked Sendable {
    let directory: URL
    private let index: URL

    init(directory: URL? = nil) throws {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ContextBasket", isDirectory: true)
        index = self.directory.appendingPathComponent("basket.json")
        try FileManager.default.createDirectory(at: self.directory.appendingPathComponent("assets"), withIntermediateDirectories: true)
    }

    func load() throws -> [Material] {
        try loadDocument().items
    }

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

    func save(_ items: [Material]) throws {
        try saveDocument(BasketDocument(items: items, prompt: "", importMode: .copy))
    }

    func saveDocument(_ document: BasketDocument) throws {
        var saved = document
        saved.items.removeAll { $0.isLoading }
        let data = try JSONEncoder().encode(saved)
        try data.write(to: index, options: .atomic)
    }

    func url(for path: String) -> URL { directory.appendingPathComponent(path) }

    func prepare(_ incoming: IncomingMaterial, id: UUID, mode: FileImportMode = .copy) throws -> Material {
        switch incoming {
        case .text(let text):
            return Material(id: id, kind: .text, title: incoming.title, text: text, detail: "\(text.count) 字")
        case .link(let url):
            return Material(id: id, kind: .link, title: url.host ?? url.absoluteString, text: url.absoluteString, detail: "链接")
        case .image(let data):
            let folder = try assetFolder(id)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("图片.png") as CFURL, UTType.png.identifier as CFString, 1, nil)
            else { throw ImportError.unreadableImage }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { throw ImportError.unreadableImage }
            return try fileMaterial(at: folder.appendingPathComponent("图片.png"), id: id)
        case .file(let original):
            let scoped = original.startAccessingSecurityScopedResource()
            defer { if scoped { original.stopAccessingSecurityScopedResource() } }
            let values = try original.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            if mode == .reference {
                _ = try assetFolder(id)
                var item: Material
                if values.isDirectory == true {
                    item = Material(id: id, kind: .file, title: original.lastPathComponent, detail: "文件夹 · 引用原位置")
                } else {
                    item = try fileMaterial(at: original, id: id)
                    item.assetPath = nil
                    item.text = nil
                    if item.kind == .text { item.kind = .file }
                }
                item.sourceURL = original.standardizedFileURL
                item.importMode = .reference
                return item
            }
            guard values.isRegularFile == true else { throw ImportError.unsupportedFolder }
            guard (values.fileSize ?? 0) <= 100 * 1024 * 1024 else { throw ImportError.tooLarge }
            let copy = try assetFolder(id).appendingPathComponent(original.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) { try FileManager.default.removeItem(at: copy) }
            try FileManager.default.copyItem(at: original, to: copy)
            var item = try fileMaterial(at: copy, id: id)
            item.sourceURL = original.standardizedFileURL
            item.importMode = .copy
            return item
        }
    }

    func discard(id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("assets/\(id.uuidString)"))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("thumbnails/\(id.uuidString)"))
    }

    private func assetFolder(_ id: UUID) throws -> URL {
        let folder = directory.appendingPathComponent("assets/\(id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func fileMaterial(at file: URL, id: UUID) throws -> Material {
        let relative = "assets/\(id.uuidString)/\(file.lastPathComponent)"
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
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
                if CGImageDestinationFinalize(destination) {
                    return Material(id: id, kind: .image, title: file.lastPathComponent, assetPath: relative, thumbnailPath: thumbnail, detail: "\(width) × \(height)")
                }
            }
        }
        let type = (try? file.resourceValues(forKeys: [.contentTypeKey]).contentType)
        if type?.conforms(to: .text) == true, size <= 1_000_000,
           let text = try? String(contentsOf: file, encoding: .utf8) {
            return Material(id: id, kind: .text, title: file.lastPathComponent, text: text, assetPath: relative, detail: "\(text.count) 字 · \(file.pathExtension.uppercased())")
        }
        return Material(id: id, kind: .file, title: file.lastPathComponent, assetPath: relative, detail: "\(file.pathExtension.uppercased()) · \(formattedSize)")
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
