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
        var sections = ["# 任务指令\n\n" + (prompt.isEmpty ? "（未填写指令）" : prompt)]
        if !items.isEmpty {
            sections.append("# 相关材料\n\n下面逐项列出材料类型和用途。副本通过附件交付；源文件引用只提供本机路径，不附带该文件副本。请按任务指令使用材料。")
        }
        for (index, item) in items.enumerated() {
            var lines = ["## 材料 \(index + 1)：\(item.title)", "类型：\(item.modeLabel)"]
            if let note = item.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("用途 / 用户说明：\n" + note)
            }
            if item.isReference, let source = item.sourceURL {
                lines.append("源文件本机路径：\(source.path)")
                lines.append("源文件 URL：\(source.absoluteString)")
                lines.append("此项没有副本附件。只有用户任务要求修改时，才直接修改上述源文件；如无权访问或路径不存在，请明确说明，不要改动另一份副本来代替。")
            } else if item.assetPath != nil {
                lines.append("副本附件：\(attachmentName(item, index: index))")
                lines.append("这是独立副本。对附件的修改不会更新用户原文件。")
            } else if item.kind == .link {
                lines.append("网页链接：\(item.text ?? "")")
            } else if let text = item.text {
                lines.append("引用文字原文：\n" + text)
            }
            sections.append(lines.joined(separator: "\n\n"))
        }
        if items.contains(where: \.isReference) {
            sections.append("# 本机路径访问\n\n本机路径只对能访问这台电脑文件的 Agent 有效。拿到路径不等于获得文件访问权限；若当前环境无法读取，请说明需要什么访问方式。")
        }
        return sections.joined(separator: "\n\n") + "\n"
    }

    static func create(items: [Material], prompt: String, library: MaterialLibrary) throws -> PromptBundle {
        guard !items.contains(where: \.isLoading) else { throw ExportError.loading }
        guard !items.isEmpty || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ExportError.empty }
        for item in items where item.isReference {
            guard let source = item.sourceURL, FileManager.default.fileExists(atPath: source.path) else {
                throw ExportError.missing(item.title)
            }
        }
        let folder = library.directory.appendingPathComponent("exports/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            let text = text(items: items, prompt: prompt)
            let promptFile = folder.appendingPathComponent("PROMPT.txt")
            try text.write(to: promptFile, atomically: true, encoding: .utf8)
            var files = [promptFile]
            for (index, item) in items.enumerated() where !item.isReference {
                if let asset = item.assetPath {
                    let destination = folder.appendingPathComponent(attachmentName(item, index: index))
                    try FileManager.default.copyItem(at: library.url(for: asset), to: destination)
                    files.append(destination)
                }
            }
            // These immutable files must outlive the drag: targets may read them later.
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
        case .loading: return "材料还在添加中，请稍后再拖出。"
        case .missing(let name): return "找不到源文件“\(name)”，请重新选择它的地址。"
        }
    }
}
