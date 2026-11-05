import AppKit

enum DropReader {
    static var types: [NSPasteboard.PasteboardType] {
        let base: [NSPasteboard.PasteboardType] = [.fileURL, .png, .tiff, .URL, .string, .rtf]
        let promises = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        return base + promises
    }

    /// A pasteboard item may offer several formats for the same content. Pick one.
    static func read(_ pasteboard: NSPasteboard) -> [IncomingMaterial] {
        (pasteboard.pasteboardItems ?? []).compactMap { item in
            if let value = item.string(forType: .fileURL), let url = URL(string: value), url.isFileURL {
                return .file(url)
            }
            for type in [NSPasteboard.PasteboardType.png, .tiff] {
                if let data = item.data(forType: type) { return .image(data) }
            }
            if let value = item.string(forType: .URL), let url = webURL(value) { return .link(url) }
            if let value = item.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let url = webURL(value) { return .link(url) }
                if let url = localURL(value), FileManager.default.fileExists(atPath: url.path) { return .file(url) }
                return .text(value)
            }
            if let data = item.data(forType: .rtf), let text = NSAttributedString(rtf: data, documentAttributes: nil)?.string, !text.isEmpty {
                return .text(text)
            }
            return nil
        }
    }

    static func webURL(_ value: String) -> URL? {
        guard !value.contains(where: { $0.isWhitespace }),
              let url = URL(string: value),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    static func localURL(_ value: String) -> URL? {
        guard !value.contains("\n") else { return nil }
        if value.hasPrefix("file://"), let url = URL(string: value), url.isFileURL { return url.standardizedFileURL }
        guard value.hasPrefix("/") || value.hasPrefix("~/") else { return nil }
        return URL(fileURLWithPath: (value as NSString).expandingTildeInPath).standardizedFileURL
    }
}
