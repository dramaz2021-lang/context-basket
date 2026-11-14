import Foundation

enum FileImportMode: String, Codable, CaseIterable, Sendable {
    case copy, reference
    var title: String { self == .copy ? "复制副本" : "源文件地址" }
}

struct Material: Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case image, text, link, file }

    /// One case per way a material can be held, so a copy never carries a path to export
    /// and a reference never carries an attachment.
    enum Content: Equatable, Sendable {
        case pending
        case text(String)
        case link(String)
        case copy(Copy)
        case reference(source: URL, thumbnailPath: String?)
    }

    struct Copy: Equatable, Sendable {
        var assetPath: String
        var thumbnailPath: String?
        /// Verbatim content of a small text file, embedded in the prompt.
        var text: String?
        /// Unknown for clipboard images and file promises; never guessed.
        var sourceURL: URL?
    }

    let id: UUID
    var title: String
    var detail: String
    var note: String?
    var content: Content

    init(id: UUID, title: String, detail: String, note: String? = nil, content: Content) {
        self.id = id
        self.title = title
        self.detail = detail
        self.note = note
        self.content = content
    }

    static func pending(id: UUID, title: String) -> Material {
        Material(id: id, title: title, detail: "正在添加…", content: .pending)
    }

    var isLoading: Bool { content == .pending }

    var isReference: Bool {
        if case .reference = content { return true }
        return false
    }

    var kind: Kind {
        switch content {
        case .pending: return .file
        case .text: return .text
        case .link: return .link
        case .copy(let copy): return copy.thumbnailPath != nil ? .image : (copy.text != nil ? .text : .file)
        case .reference(_, let thumbnailPath): return thumbnailPath != nil ? .image : .file
        }
    }

    var text: String? {
        switch content {
        case .text(let text), .link(let text): return text
        case .copy(let copy): return copy.text
        case .pending, .reference: return nil
        }
    }

    var assetPath: String? {
        if case .copy(let copy) = content { return copy.assetPath }
        return nil
    }

    /// A copy travels as a file only when its content is not already written into the prompt.
    var attachmentPath: String? {
        if case .copy(let copy) = content, copy.text == nil { return copy.assetPath }
        return nil
    }

    var thumbnailPath: String? {
        switch content {
        case .copy(let copy): return copy.thumbnailPath
        case .reference(_, let thumbnailPath): return thumbnailPath
        case .pending, .text, .link: return nil
        }
    }

    var sourceURL: URL? {
        switch content {
        case .copy(let copy): return copy.sourceURL
        case .reference(let source, _): return source
        case .pending, .text, .link: return nil
        }
    }

    var importMode: FileImportMode? {
        switch content {
        case .copy: return .copy
        case .reference: return .reference
        case .pending, .text, .link: return nil
        }
    }

    var modeLabel: String {
        switch content {
        case .reference: return "源文件地址"
        case .copy: return "副本"
        case .link: return "网页链接"
        case .pending, .text: return "文字"
        }
    }

    /// A temporary transfer location must not be remembered as the source.
    mutating func forgetSource() {
        guard case .copy(var copy) = content else { return }
        copy.sourceURL = nil
        content = .copy(copy)
    }
}

/// Keeps the flat version 2 fields on disk, so documents stay readable in both directions.
extension Material: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, kind, title, text, assetPath, thumbnailPath, detail, isLoading, note, sourceURL, importMode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        detail = try values.decode(String.self, forKey: .detail)
        note = try values.decodeIfPresent(String.self, forKey: .note)
        let kind = try values.decode(Kind.self, forKey: .kind)
        let text = try values.decodeIfPresent(String.self, forKey: .text)
        let thumbnailPath = try values.decodeIfPresent(String.self, forKey: .thumbnailPath)
        let sourceURL = try values.decodeIfPresent(URL.self, forKey: .sourceURL)
        let importMode = try values.decodeIfPresent(FileImportMode.self, forKey: .importMode)
        if importMode == .reference, let sourceURL {
            content = .reference(source: sourceURL, thumbnailPath: thumbnailPath)
        } else if let assetPath = try values.decodeIfPresent(String.self, forKey: .assetPath) {
            content = .copy(Copy(assetPath: assetPath, thumbnailPath: thumbnailPath, text: text, sourceURL: sourceURL))
        } else if kind == .link {
            content = .link(text ?? "")
        } else {
            content = .text(text ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(kind, forKey: .kind)
        try values.encode(title, forKey: .title)
        try values.encodeIfPresent(text, forKey: .text)
        try values.encodeIfPresent(assetPath, forKey: .assetPath)
        try values.encodeIfPresent(thumbnailPath, forKey: .thumbnailPath)
        try values.encode(detail, forKey: .detail)
        try values.encode(isLoading, forKey: .isLoading)
        try values.encodeIfPresent(note, forKey: .note)
        try values.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try values.encodeIfPresent(importMode, forKey: .importMode)
    }
}

/// Unknown keys, such as the retired clipboard switch of older documents, are ignored.
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
