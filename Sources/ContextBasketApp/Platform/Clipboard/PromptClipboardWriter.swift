import AppKit

@MainActor
enum PromptClipboardWriter {
    /// Replaces the clipboard with the prompt and its snapshot files, marked as this app's own output.
    static func write(text: String, files: [URL], to pasteboard: NSPasteboard) -> Bool {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setString(ClipboardMonitor.sourceIdentifier, forType: ClipboardMonitor.sourceType)
        // Keep text and the first file on one item so readers can discover both types.
        if let first = files.first { item.setString(first.absoluteString, forType: .fileURL) }
        var objects: [NSPasteboardWriting] = [item]
        objects.append(contentsOf: files.dropFirst().map { $0 as NSURL })
        pasteboard.clearContents()
        return pasteboard.writeObjects(objects)
    }
}
