import AppKit

struct DropProfile {
    var hasLocalFiles = false
    var hasAttachments = false
    var hasText = false
    var isSupported: Bool { hasAttachments || hasText }

    static func inspect(_ pasteboard: NSPasteboard) -> DropProfile {
        var profile = DropProfile()
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        for item in pasteboard.pasteboardItems ?? [] {
            let types = item.types
            let location = item.string(forType: .fileURL) ?? item.string(forType: .URL) ?? item.string(forType: .string)
            let localFile = location.flatMap(DropReader.localURL).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            let file = types.contains(.fileURL) || localFile
            profile.hasLocalFiles = profile.hasLocalFiles || file
            profile.hasAttachments = profile.hasAttachments || file || types.contains(.png) || types.contains(.tiff) || types.contains(where: promiseTypes.contains)
            profile.hasText = profile.hasText || types.contains(.string) || types.contains(.URL) || types.contains(.rtf)
        }
        return profile
    }
}

enum DropLocation { case collectionLeft, collectionRight, prompt, other }

struct DropFeedback: Equatable {
    enum Style { case fileChoices, context, promptText }
    var style: Style
    var mode: FileImportMode = .copy
    var overPrompt = false
    var targetSlot: Int?
}

enum DropPolicy {
    static func feedback(profile: DropProfile, location: DropLocation) -> DropFeedback? {
        guard profile.isSupported else { return nil }
        if location == .prompt {
            guard !profile.hasAttachments else { return nil }
            return DropFeedback(style: .promptText, overPrompt: true)
        }
        guard location == .collectionLeft || location == .collectionRight else { return nil }
        if profile.hasLocalFiles, location == .collectionLeft || location == .collectionRight {
            return DropFeedback(style: .fileChoices, mode: location == .collectionRight ? .reference : .copy)
        }
        return DropFeedback(style: .context)
    }
}
