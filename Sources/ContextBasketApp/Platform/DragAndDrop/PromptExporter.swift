import Foundation

struct PromptBundle {
    let text: String
    let files: [URL]
    let folder: URL
}

enum PromptExporter {
    static func validate(items: [Material], prompt: String) throws {
        guard !items.contains(where: \.isLoading) else { throw ExportError.loading }
        guard !items.isEmpty || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ExportError.empty }
        for item in items {
            guard case .reference(let source, _) = item.content else { continue }
            guard FileManager.default.fileExists(atPath: source.path) else { throw ExportError.missing(item.title) }
        }
    }

    static func create(items: [Material], prompt: String, library: MaterialLibrary) throws -> PromptBundle {
        try validate(items: items, prompt: prompt)
        let folder = try library.makeExportFolder()
        do {
            var files: [URL] = []
            for (index, item) in items.enumerated() {
                guard let path = item.attachmentPath else { continue }
                let destination = folder.appendingPathComponent(PromptFormat.attachmentName(item, index: index))
                try FileManager.default.copyItem(at: library.url(for: path), to: destination)
                files.append(destination)
            }
            let text = PromptFormat.text(items: items, prompt: prompt)
            let promptFile = folder.appendingPathComponent("PROMPT.txt")
            try text.write(to: promptFile, atomically: true, encoding: .utf8)
            files.insert(promptFile, at: 0)
            // Copied and dragged files must outlive edits or deletion in the basket.
            return PromptBundle(text: text, files: files, folder: folder)
        } catch {
            library.removeExport(folder)
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
