import Foundation

enum FileImportMode: String, Codable, CaseIterable, Sendable {
    case copy, reference
    var title: String { self == .copy ? "复制副本" : "源文件地址" }
}

struct Material: Identifiable, Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case image, text, link, file }

    let id: UUID
    var kind: Kind
    var title: String
    var text: String?
    var assetPath: String?
    var thumbnailPath: String?
    var detail: String
    var isLoading = false
    var note: String?
    var sourceURL: URL?
    var importMode: FileImportMode?

    var isReference: Bool { importMode == .reference }
    var modeLabel: String {
        if isReference { return "源文件地址" }
        if assetPath != nil { return "副本" }
        return kind == .link ? "网页链接" : "文字"
    }

    static func pending(id: UUID, title: String) -> Material {
        Material(id: id, kind: .file, title: title, detail: "正在添加…", isLoading: true)
    }
}

struct BasketDocument: Codable, Sendable {
    var version = 2
    var items: [Material]
    var prompt: String
    var importMode: FileImportMode
}

enum IncomingMaterial: Sendable {
    case file(URL)
    case image(Data)
    case text(String)
    case link(URL)

    var title: String {
        switch self {
        case .file(let url): return url.lastPathComponent
        case .image: return "图片"
        case .text(let text): return String(text.split(whereSeparator: \.isNewline).first.map(String.init)?.prefix(60) ?? "文字".prefix(60))
        case .link(let url): return url.host ?? url.absoluteString
        }
    }
}
