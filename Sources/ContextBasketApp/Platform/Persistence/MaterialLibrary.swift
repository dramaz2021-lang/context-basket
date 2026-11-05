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
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        return try JSONDecoder().decode([Material].self, from: Data(contentsOf: index))
    }

    func save(_ items: [Material]) throws {
        let data = try JSONEncoder().encode(items.filter { !$0.isLoading })
        try data.write(to: index, options: .atomic)
    }

    func url(for path: String) -> URL { directory.appendingPathComponent(path) }

    func prepare(_ incoming: IncomingMaterial, id: UUID) throws -> Material {
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
            let values = try original.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { throw ImportError.unsupportedFolder }
            guard (values.fileSize ?? 0) <= 100 * 1024 * 1024 else { throw ImportError.tooLarge }
            let copy = try assetFolder(id).appendingPathComponent(original.lastPathComponent)
            try FileManager.default.copyItem(at: original, to: copy)
            return try fileMaterial(at: copy, id: id)
        }
    }

    func discard(id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("assets/\(id.uuidString)"))
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
            let thumbnail = "assets/\(id.uuidString)/.preview.png"
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
    case unreadableImage, unsupportedFolder, tooLarge
    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "这张图片无法读取，请换一个图片文件试试。"
        case .unsupportedFolder: return "请拖入具体文件，暂不支持文件夹。"
        case .tooLarge: return "这份文件超过 100 MB，请先添加较小的材料。"
        }
    }
}
