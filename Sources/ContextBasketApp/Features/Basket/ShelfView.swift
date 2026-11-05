import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(red: 0.65, green: 0.83, blue: 0.73)
// Disambiguate the property wrapper from the same-name macro in newer SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ShelfView: View {
    @ObservedObject var store: BasketStore
    let drops: MaterialDropCoordinator
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                if store.items.isEmpty { emptyState } else { materials }
            }
            .background(DropAreaMarker(coordinator: drops))
            .overlay { collectionDropOverlay }
            promptEditor
            footer
        }
        .background(Color(red: 0.06, green: 0.08, blue: 0.10).opacity(0.56))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.14), lineWidth: 1).allowsHitTesting(false) }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .preferredColorScheme(.dark)
        .sheet(item: $store.preview) { MaterialPreview(item: $0, library: store.library) }
        .sheet(isPresented: $store.showLocationEditor) { LocationEditor(store: store) }
        .sheet(isPresented: $store.showPromptPreview) { PromptPreview(store: store) }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Button(action: close) {
                Image(systemName: "tray.full.fill").font(.system(size: 17)).foregroundStyle(accent)
            }.buttonStyle(.plain).help("收起为图标").accessibilityLabel("收起为图标")
            Text("context basket").font(.system(size: 14, weight: .semibold))
            Text("\(store.items.count)").font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 7).padding(.vertical, 3)
                .background(.white.opacity(0.07), in: Capsule()).accessibilityLabel("\(store.items.count) 项材料")
            Spacer()
            Button(action: store.undoRemove) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(ShelfIconStyle()).disabled(!store.canUndo).opacity(store.canUndo ? 1 : 0.35)
            .help("撤销删除").accessibilityLabel("撤销删除")
            Menu {
                Button("添加文件…", action: store.chooseFiles)
                Button("添加链接或本机地址…") { store.showLocationEditor = true }
                Button("粘贴为材料", action: store.paste)
                Toggle("自动收集剪贴板（副本）", isOn: Binding(get: { store.automaticallyCollectClipboard }, set: store.setAutomaticallyCollectClipboard))
                Menu("选文件与粘贴的默认方式") {
                    ForEach(FileImportMode.allCases, id: \.self) { mode in
                        Button { store.setImportMode(mode) } label: {
                            if store.importMode == mode { Label(mode.title, systemImage: "checkmark") } else { Text(mode.title) }
                        }
                    }
                }
                Divider()
                Button("退出 context basket") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "plus").frame(width: 25, height: 26)
                    .foregroundStyle(.white.opacity(0.5))
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("添加材料与设置").accessibilityLabel("添加材料与设置")
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(ShelfIconStyle()).help("收起浮窗").accessibilityLabel("收起浮窗")
        }
        .foregroundStyle(.white.opacity(0.9)).padding(.horizontal, 17).frame(height: 56)
        .background(WindowDragArea())
    }

    @ViewBuilder private var collectionDropOverlay: some View {
        if let feedback = store.dropFeedback, feedback.style != .promptText {
            Group {
                if feedback.style == .fileChoices {
                    HStack(spacing: 10) {
                        fileDropZone(.copy, selected: feedback.mode == .copy)
                        fileDropZone(.reference, selected: feedback.mode == .reference)
                    }
                } else {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.12, green: 0.34, blue: 0.27).opacity(0.88), in: RoundedRectangle(cornerRadius: 17))
                    .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4])) }
                }
            }.padding(12).allowsHitTesting(false)
        }
    }

    private func fileDropZone(_ mode: FileImportMode, selected: Bool) -> some View {
        let color = mode == .copy ? Color(red: 0.45, green: 0.76, blue: 0.61) : Color(red: 0.48, green: 0.64, blue: 0.91)
        return VStack(spacing: 12) {
            Image(systemName: mode == .copy ? "doc.on.doc.fill" : "link").font(.system(size: 32, weight: .medium))
            Text(mode == .copy ? "副本" : "链接").font(.system(size: 22, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.06, green: 0.12, blue: 0.16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(selected ? 0.94 : 0.76), in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(selected ? 0.95 : 0.25), lineWidth: selected ? 3 : 1) }
        .accessibilityLabel(mode == .copy ? "拖入副本区域" : "拖入源文件链接区域")
    }

    private var materials: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                    ForEach(store.items) { item in MaterialCard(store: store, item: item).id(item.id) }
                }.padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 14)
            }
            .onChange(of: store.items.count) { _, _ in
                if let last = store.items.last {
                    DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 12)
            ZStack {
                emptyCard("text.alignleft", color: .purple).rotationEffect(.degrees(-16)).offset(x: -34, y: 5)
                emptyCard("photo", color: accent).rotationEffect(.degrees(10)).offset(x: 28)
            }.frame(height: 80)
            Text("把材料拖到这里").font(.system(size: 14, weight: .medium)).padding(.top, 7)
            Text("图片、文字、链接、文件").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            Spacer(minLength: 20)
        }.frame(maxWidth: .infinity)
    }
    private func emptyCard(_ symbol: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 13).fill(Color(white: 0.22))
            .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.12)) }
            .overlay { Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(color) }
            .frame(width: 62, height: 74).shadow(color: .black.opacity(0.2), radius: 9, y: 5)
    }

    private var promptEditor: some View {
        PromptTextEditor(store: store, drops: drops)
            .padding(7).frame(height: 104).background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(store.dropFeedback?.overPrompt == true ? accent.opacity(0.8) : .white.opacity(0.08)).allowsHitTesting(false) }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
        .background(DropAreaMarker(coordinator: drops, isPrompt: true))
        .background(alignment: .top) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 16) }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message = store.errorMessage ?? store.statusMessage {
                HStack(alignment: .top) {
                    Text(message).lineLimit(3)
                    Spacer(minLength: 0)
                    Button { store.errorMessage = nil; store.statusMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.font(.system(size: 10)).foregroundStyle(store.errorMessage == nil ? accent : .orange)
            }
            HStack(spacing: 13) {
                Button(action: store.presentPromptPreview) { Label("预览完整 Prompt", systemImage: "doc.text.magnifyingglass") }
                    .buttonStyle(PromptActionStyle()).help("预览完整 Prompt").accessibilityLabel("预览完整 Prompt").disabled(!store.canExport)
                Spacer(minLength: 0)
                Button(action: store.copyPrompt) {
                    Label("复制完整 Prompt", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(PromptActionStyle()).disabled(!store.canExport)
                .help("复制完整 Prompt 和附件，到 Agent 中粘贴")
                .accessibilityLabel("复制完整 Prompt")
            }.foregroundStyle(.white.opacity(0.5))
        }.padding(.horizontal, 18).padding(.bottom, 16)
    }
}

private struct MaterialCard: View {
    @ObservedObject var store: BasketStore
    let item: Material
    @ViewState private var hovered = false
    private var hasNote: Bool { !(item.note ?? "").isEmpty }
    private var editing: Bool { store.noteEditorID == item.id }
    private func preview() { store.openMaterial(item) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.12)
                cardContent
                PromptDragSource(store: store, material: item, clicked: preview, hoverChanged: { hovered = $0 })
                HStack {
                    Text(item.modeLabel).font(.system(size: 8, weight: .medium))
                        .foregroundStyle(item.isReference ? accent : .white.opacity(0.72))
                        .padding(.horizontal, 6).padding(.vertical, 4).background(.black.opacity(0.62), in: Capsule()).allowsHitTesting(false)
                    Spacer(minLength: 0)
                    if hovered || editing { actions }
                }.padding(6)
            }.frame(height: 110).clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle).foregroundStyle(.white.opacity(0.85))
                Text(item.isReference ? (item.sourceURL?.path ?? "源地址不可用") : item.detail)
                    .font(.system(size: 9)).lineLimit(1).truncationMode(.middle).foregroundStyle(.white.opacity(0.38))
            }.padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading).frame(height: 44)
                .contentShape(Rectangle()).onTapGesture(perform: preview)
            if editing {
                VStack(alignment: .leading, spacing: 5) {
                    MaterialNoteEditor(store: store, itemID: item.id, title: item.title).frame(height: 56)
                    HStack { Spacer(); Button("完成", action: store.finishNoteEditing).buttonStyle(.plain).foregroundStyle(accent).font(.system(size: 10)) }
                }.padding(9).background(.black.opacity(0.15)).padding(.horizontal, 7).padding(.bottom, 7)
            } else if hasNote {
                Button { store.editNote(item.id) } label: {
                    Label(item.note ?? "", systemImage: "quote.opening").font(.system(size: 10)).lineLimit(2)
                        .foregroundStyle(accent.opacity(0.9)).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).padding(.horizontal, 10).padding(.bottom, 10).help("编辑文件说明")
            }
        }
        .background(.white.opacity(hovered ? 0.09 : 0.045)).clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(hovered ? 0.22 : 0.07)).allowsHitTesting(false) }
        .onHover { hovered = $0 }
        .contextMenu {
            Button(hasNote ? "编辑文件说明" : "添加文件说明") { store.editNote(item.id) }
            Button("预览", action: preview)
            if item.sourceURL != nil {
                Button(item.isReference ? "改为副本" : "改为源文件地址") { store.changeMode(item.id, to: item.isReference ? .copy : .reference) }.disabled(item.isLoading)
            }
            Divider()
            Button("删除材料") { store.remove(item.id) }
        }
        .accessibilityElement(children: .contain).accessibilityLabel(item.title)
        .accessibilityAction(named: "预览", preview)
        .accessibilityAction(named: "添加文件说明") { store.editNote(item.id) }
        .accessibilityAction(named: "删除") { store.remove(item.id) }
        .accessibilityAction(named: "切换副本或源地址") { store.changeMode(item.id, to: item.isReference ? .copy : .reference) }
    }
    private var actions: some View {
        HStack(spacing: 4) {
            action("text.bubble", label: hasNote ? "编辑文件说明" : "添加文件说明") { store.editNote(item.id) }
            action("xmark", label: "删除材料") { store.remove(item.id) }
        }
    }
    private func action(_ symbol: String, label: String, run: @escaping () -> Void) -> some View {
        Button(action: run) { Image(systemName: symbol).font(.system(size: 9, weight: .semibold)).frame(width: 23, height: 23)
                .foregroundStyle(.white.opacity(0.95)).background(Color(white: 0.16).opacity(0.97), in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.18)) } }
            .buttonStyle(.plain).help(label).accessibilityLabel("\(label)：\(item.title)")
    }

    @ViewBuilder private var cardContent: some View {
        if item.isLoading { ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity) }
        else {
            switch item.kind {
            case .image:
                if let thumbnail = store.thumbnail(for: item) { Image(nsImage: thumbnail).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else { Image(systemName: "photo").font(.system(size: 30)).foregroundStyle(accent).frame(maxWidth: .infinity, maxHeight: .infinity) }
            case .text:
                Text(item.text ?? "").font(.system(size: 11)).lineSpacing(3).lineLimit(4).foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.horizontal, 12).padding(.top, 34)
            case .link:
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: "link").font(.system(size: 18, weight: .light)).foregroundStyle(.blue.opacity(0.8))
                    Text(item.text ?? "").font(.system(size: 11)).lineLimit(2).foregroundStyle(.white.opacity(0.65))
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.top, 23)
            case .file:
                Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: (item.title as NSString).pathExtension) ?? .data))
                    .resizable().scaledToFit().frame(width: 48, height: 57).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct LocationEditor: View {
    @ObservedObject var store: BasketStore
    @ViewState private var location = ""
    @ViewState private var invalid = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加链接或本机地址").font(.headline)
            TextField("https://… 或 /Users/…", text: $location).textFieldStyle(.roundedBorder).accessibilityLabel("链接或本机地址")
            if invalid { Text("请输入有效网页链接，或以 /、~/、file:// 开头的本机地址。").font(.system(size: 11)).foregroundStyle(.orange) }
            Text("本机地址只引用源文件，不复制。需要 Agent 能访问这台电脑，才能读取或修改原文件。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack { Button("取消") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("添加") { if store.addLocation(location) { dismiss() } else { invalid = true } }.keyboardShortcut(.defaultAction).disabled(location.isEmpty) }
        }.padding(22).frame(width: 390).preferredColorScheme(.dark)
    }
}

private struct PromptPreview: View {
    @ObservedObject var store: BasketStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("完整 Prompt").font(.headline); Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(18)
            Divider()
            ScrollView { Text(store.promptText).font(.system(size: 12)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
            HStack {
                Spacer()
                Button("复制完整 Prompt", action: store.copyPrompt).disabled(!store.canExport)
            }.padding(14)
        }.frame(width: 520, height: 480).preferredColorScheme(.dark)
    }
}

private struct PromptActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isEnabled ? Color(white: 0.12) : .white.opacity(0.25))
            .padding(.horizontal, 14).frame(height: 32)
            .background(isEnabled ? accent : Color.white.opacity(0.06), in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct ShelfIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 25, height: 26).foregroundStyle(.white.opacity(configuration.isPressed ? 1 : 0.5))
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 7))
    }
}
private struct WindowDragArea: NSViewRepresentable {
    class Handle: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let alpha = window.alphaValue
            window.alphaValue = 0.55
            defer { window.alphaValue = alpha }
            window.performDrag(with: event)
        }
    }
    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ nsView: Handle, context: Context) {}
}
