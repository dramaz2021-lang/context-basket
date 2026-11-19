import Foundation

/// The wording of the prompt, with no file or clipboard access.
enum PromptFormat {
    static func text(items: [Material], prompt: String) -> String {
        var sections: [String] = []
        if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("任务：\n" + prompt)
        }
        if !items.isEmpty {
            let materials = items.enumerated().map { index, item in
                var entry = "\(index + 1). \(title(item))"
                if let note = item.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entry += "：" + note
                }
                switch item.content {
                case .reference(let source, _): entry += "\n源文件地址：" + source.path
                case .link(let link): entry += "\n" + link
                case .text(let text): entry += verbatim(text, index: index)
                case .copy(let copy): if let text = copy.text { entry += verbatim(text, index: index) }
                case .pending: break
                }
                return entry
            }
            sections.append("附件说明：\n" + materials.joined(separator: "\n\n"))
        }
        return sections.isEmpty ? "" : sections.joined(separator: "\n\n") + "\n"
    }

    static func attachmentName(_ item: Material, index: Int) -> String {
        let filename = item.attachmentPath.map { ($0 as NSString).lastPathComponent } ?? item.title
        return String(format: "%02d-", index + 1) + filename
    }

    /// Numbered tags mark where the user's text starts and ends, whatever blank lines
    /// or lists it contains; the text between them is untouched.
    private static func verbatim(_ text: String, index: Int) -> String {
        "\n<material-\(index + 1)>\n" + text + "\n</material-\(index + 1)>"
    }

    private static func title(_ item: Material) -> String {
        // Pasted text already contains its first line; avoid repeating it as a title.
        if case .text = item.content { return "文字材料" }
        return item.title
    }
}
