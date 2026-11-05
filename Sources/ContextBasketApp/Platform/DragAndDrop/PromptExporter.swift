import Foundation

struct PromptBundle {
    let text: String
    let files: [URL]
    let folder: URL
}

enum PromptExporter {
    static func attachmentName(_ item: Material, index: Int) -> String {
        let filename = item.assetPath.map { ($0 as NSString).lastPathComponent } ?? item.title
        return String(format: "%02d-", index + 1) + filename
    }

    static func text(items: [Material], prompt: String) -> String {
        var sections: [String] = []
        if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("任务：\n" + prompt)
        }
        if !items.isEmpty {
            let materials = items.enumerated().map { index, item in
                // Pasted text already contains its first line; avoid repeating it as a title.
                let title = item.kind == .text && item.assetPath == nil && !item.isReference ? "文字材料" : item.title
                var entry = "\(index + 1). \(title)"
                if let note = item.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entry += "：" + note
                }
                if item.isReference, let source = item.sourceURL {
                    entry += "\n源文件地址：" + source.path
                } else if let text = item.text {
                    entry += "\n" + text
                }
                return entry
            }
            sections.append("附件说明：\n" + materials.joined(separator: "\n\n"))
        }
        return sections.isEmpty ? "" : sections.joined(separator: "\n\n") + "\n"
    }

    static func validate(items: [Material], prompt: String) throws {
        guard !items.contains(where: \.isLoading) else { throw ExportError.loading }
        guard !items.isEmpty || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ExportError.empty }
        for item in items where item.isReference {
            guard let source = item.sourceURL, FileManager.default.fileExists(atPath: source.path) else {
                throw ExportError.missing(item.title)
            }
        }
    }

    static func create(items: [Material], prompt: String, library: MaterialLibrary) throws -> PromptBundle {
        try validate(items: items, prompt: prompt)
        let folder = library.directory.appendingPathComponent("exports/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            var files: [URL] = []
            for (index, item) in items.enumerated() where !item.isReference {
                if let asset = item.assetPath {
                    let destination = folder.appendingPathComponent(attachmentName(item, index: index))
                    try FileManager.default.copyItem(at: library.url(for: asset), to: destination)
                    files.append(destination)
                }
            }
            let text = text(items: items, prompt: prompt)
            let promptFile = folder.appendingPathComponent("PROMPT.txt")
            try text.write(to: promptFile, atomically: true, encoding: .utf8)
            files.insert(promptFile, at: 0)
            // Copied and dragged files must outlive edits or deletion in the basket.
            return PromptBundle(text: text, files: files, folder: folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}

enum ExportError: LocalizedError {
    case empty, loading, missing(String)
    var errorDescription: String? {
        switch self {
        case .empty: return "先添加材料或写一句指令。"
        case .loading: return "材料还在添加中，请稍后再复制。"
        case .missing(let name): return "找不到源文件“\(name)”，请重新选择它的地址。"
        }
    }
}
