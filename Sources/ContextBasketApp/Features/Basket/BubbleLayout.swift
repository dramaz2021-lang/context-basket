import AppKit

/// Shared measurements for the editor, grid, and native floating window.
enum BubbleLayout {
    static let iconSize: CGFloat = 58
    static let gap: CGFloat = 12
    static let expandedWidth: CGFloat = 460
    static let headerHeight = iconSize
    static let promptWidth = expandedWidth
    static let minimumPromptHeight: CGFloat = 44
    static let maximumPromptHeight: CGFloat = 188
    static let promptPadding: CGFloat = 14
    static let collectionWidth = expandedWidth
    static let cardWidth = (collectionWidth - gap) / 2
    static let cardHeight: CGFloat = 154
    static let cardDetailsHeight: CGFloat = 44
    static let noteSummaryHeight: CGFloat = 38
    static let baseHeight = headerHeight + gap * 2 + minimumPromptHeight + cardHeight

    static var promptFont: NSFont { .systemFont(ofSize: 13) }

    static func promptHeight(for text: String) -> CGFloat {
        let storage = NSTextStorage(string: text, attributes: [.font: promptFont])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: promptWidth - promptPadding * 2, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        let contentHeight = max(layout.defaultLineHeight(for: promptFont), layout.usedRect(for: container).maxY, layout.extraLineFragmentRect.maxY)
        return min(maximumPromptHeight, max(minimumPromptHeight, ceil(contentHeight) + 24))
    }

    static func addSlotCount(itemCount: Int) -> Int { itemCount.isMultiple(of: 2) ? 2 : 1 }

    static func collectionHeight(items: [Material]) -> CGFloat {
        let rows = CGFloat((items.count + addSlotCount(itemCount: items.count)) / 2)
        return rows * cardHeight + (rows - 1) * gap
    }

    static func expandedHeight(items: [Material], prompt: String, hasError: Bool = false, available: CGFloat) -> CGFloat {
        let height = headerHeight + gap * 2 + promptHeight(for: prompt) + collectionHeight(items: items) + (hasError ? 64 : 0)
        return min(available - 16, height)
    }
}
