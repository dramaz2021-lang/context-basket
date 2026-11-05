import AppKit
import Quartz

@main
enum ContextBasket {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: ShelfPanel!
    private var shelfController: FloatingShelfController!
    private var store: BasketStore!
    private var statusItem: NSStatusItem!
    #if DEBUG
    private var dragHarness: NSWindow?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let customDirectory = ProcessInfo.processInfo.environment["CONTEXT_BASKET_DATA_DIR"].map { URL(fileURLWithPath: $0) }
            store = BasketStore(library: try MaterialLibrary(directory: customDirectory))
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法打开上下文篮"
            alert.informativeText = "本地保存目录暂时无法访问：\(error.localizedDescription)"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        configureMenu()
        panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 500), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "上下文篮"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.appearance = NSAppearance(named: .darkAqua)
        shelfController = FloatingShelfController(panel: panel, store: store)
        panel.pasteMaterials = { [weak self] in self?.store.paste() }
        panel.undoRemoval = { [weak self] in self?.store.undoRemove() }
        store.onCountChanged = { [weak self] in self?.shelfController.updateSize() }
        shelfController.updateSize()
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 36, y: visible.midY - panel.frame.height / 2))
        }
        shelfController.show()
        panel.makeFirstResponder(nil)
    }

    private func configureMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "显示上下文篮", action: #selector(showShelf), keyEquivalent: "0")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出上下文篮", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "粘贴", action: #selector(pasteMaterials), keyEquivalent: "v")
        editMenu.addItem(withTitle: "撤销", action: #selector(undoRemoval), keyEquivalent: "z")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        mainMenu.addItem(edit)
        #if DEBUG
        let development = NSMenuItem()
        let developmentMenu = NSMenu(title: "开发")
        developmentMenu.addItem(withTitle: "打开拖入验收窗口", action: #selector(showDragHarness), keyEquivalent: "")
        development.submenu = developmentMenu
        mainMenu.addItem(development)
        #endif
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "上下文篮")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showShelf)
        statusItem.button?.toolTip = "显示上下文篮"
    }

    @objc private func showShelf() { shelfController.show() }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        SourceFilePreview.shared.sourceURL != nil
    }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) { SourceFilePreview.shared.begin(panel) }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { SourceFilePreview.shared.end(panel) }
    @objc private func pasteMaterials() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable { editor.pasteAsPlainText(nil) }
        else { store.paste() }
    }
    @objc private func undoRemoval() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable { editor.undoManager?.undo() }
        else { store.undoRemove() }
    }

    #if DEBUG
    @objc private func showDragHarness() {
        dragHarness = makeDragHarness(store: store)
        NSApp.activate(ignoringOtherApps: true)
        dragHarness?.makeKeyAndOrderFront(nil)
    }
    #endif

}
