import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(red: 0.10, green: 0.23, blue: 0.43)
private let noteBackground = Color(red: 0.83, green: 0.89, blue: 0.97)
// Disambiguate the property wrapper from the same-name macro in newer SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ShelfView: View {
    @ObservedObject var store: BasketStore
    let drops: MaterialDropCoordinator
    let close: () -> Void
    private let addBubbleID = "add-material-bubble"
    private let columns = Array(repeating: GridItem(.fixed(BubbleLayout.cardWidth), spacing: BubbleLayout.gap, alignment: .top), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: BubbleLayout.gap) {
            header
            promptBubble
            attachments
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
        .sheet(item: $store.preview) { MaterialPreview(item: $0, library: store.library) }
        .sheet(isPresented: $store.showLocationEditor) { LocationEditor(store: store) }
        .sheet(isPresented: $store.showPromptPreview) { PromptPreview(store: store) }
    }

    private var header: some View {
        HStack(spacing: BubbleLayout.gap) {
            ShelfAnchorView(store: store, expanded: true, toggle: close)
                .frame(width: BubbleLayout.iconSize, height: BubbleLayout.iconSize)
                .background(DropAreaMarker(coordinator: drops, isIcon: true))
            Button(action: store.presentPromptPreview) { Text("预览 Prompt") }
                .buttonStyle(PromptActionStyle()).disabled(!store.canExport)
                .help("预览完整 Prompt").accessibilityLabel("预览完整 Prompt")
            Button(action: store.copyPrompt) { Text("复制 Prompt") }
                .buttonStyle(PromptActionStyle()).disabled(!store.canExport)
                .help("复制完整 Prompt 和附件，到 Agent 中粘贴")
                .accessibilityLabel("复制完整 Prompt")
            Button { store.setAutomaticallyCollectClipboard(!store.automaticallyCollectClipboard) } label: {
                Image(systemName: store.automaticallyCollectClipboard ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(HeaderIconStyle(active: store.automaticallyCollectClipboard))
            .help(store.automaticallyCollectClipboard ? "自动添加剪贴板内容 · 点击暂停" : "已暂停添加剪贴板内容 · 点击继续")
            .accessibilityLabel(store.automaticallyCollectClipboard ? "暂停自动添加剪贴板内容" : "继续自动添加剪贴板内容")
            Button(action: store.clearBasket) { Image(systemName: "xmark") }
                .buttonStyle(HeaderIconStyle()).disabled(!store.hasContent)
                .help("清空当前指令和附件").accessibilityLabel("清空当前 Prompt 和附件")
        }.frame(height: BubbleLayout.headerHeight)
    }

    private var promptBubble: some View {
        PromptTextEditor(store: store, drops: drops)
            .overlay(alignment: .topLeading) {
                if store.prompt.isEmpty {
                    Text("输入指令").font(.system(size: 13)).foregroundStyle(.white.opacity(0.48))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, BubbleLayout.promptPadding).padding(.vertical, 12)
            .frame(width: BubbleLayout.promptWidth, height: BubbleLayout.promptHeight(for: store.prompt))
            .basketGlass(cornerRadius: 22)
            .background(DropAreaMarker(coordinator: drops, isPrompt: true))
    }

    private var attachments: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: BubbleLayout.gap) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: BubbleLayout.gap) {
                        ForEach(store.items) { item in
                            MaterialCard(store: store, item: item).id(item.id)
                        }
                        ForEach(0..<BubbleLayout.addSlotCount(itemCount: store.items.count), id: \.self) { slot in
                            addBubble(slot: slot).id("\(addBubbleID)-\(slot)")
                        }
                    }
                    if let message = store.errorMessage {
                        HStack(alignment: .top) {
                            Text(message).font(.system(size: 11)).foregroundStyle(.orange)
                            Spacer(minLength: 0)
                            Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("关闭错误提示")
                        }.padding(12).basketGlass(cornerRadius: 18)
                    }
                }.frame(width: BubbleLayout.collectionWidth)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.items.count) { _, _ in
                DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("\(addBubbleID)-0", anchor: .bottom) } }
            }
            .onChange(of: store.noteEditorID) { _, id in
                if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
        .frame(width: BubbleLayout.collectionWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func addBubble(slot: Int) -> some View {
        let feedback = store.dropFeedback
        let targeted = feedback != nil && !feedback!.overPrompt && (feedback!.targetSlot == nil || feedback!.targetSlot == slot)
        return ZStack {
            if targeted && feedback?.style == .fileChoices {
                HStack(spacing: 6) {
                    dropChoice(.copy)
                    dropChoice(.reference)
                }.padding(8).transition(.opacity)
            } else {
                addMenu
                    .frame(width: BubbleLayout.cardWidth, height: BubbleLayout.cardHeight)
                    .overlay {
                        VStack(spacing: 7) {
                            Image(systemName: "plus").font(.system(size: 28, weight: .ultraLight)).padding(.bottom, 7)
                            Text("把材料拖到这里").font(.system(size: 13, weight: .medium))
                            Text("图片、文字、链接、文件").font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                        }
                        .foregroundStyle(.white.opacity(0.78)).allowsHitTesting(false).accessibilityHidden(true)
                    }
            }
        }
        .frame(width: BubbleLayout.cardWidth, height: BubbleLayout.cardHeight)
        .basketGlass(cornerRadius: 24)
        .overlay(alignment: .topTrailing) {
            if slot == 0 && store.canUndo && !targeted {
                Button(action: store.undoRemove) { Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .medium)) }
                    .buttonStyle(ShelfIconStyle()).padding(9)
                    .help("撤销删除或清空").accessibilityLabel("撤销删除或清空")
            }
        }
        .background(DropAreaMarker(coordinator: drops, slot: slot))
        .animation(.easeOut(duration: 0.16), value: targeted)
        .accessibilityElement(children: .contain).accessibilityLabel("添加附件气泡")
    }

    private var addMenu: some View {
        Menu {
            Button("添加文件…", action: store.chooseFiles)
            Button("添加链接或本机地址…") { store.showLocationEditor = true }
            Button("粘贴为材料", action: store.paste)
            Menu("选文件与粘贴的默认方式") {
                ForEach(FileImportMode.allCases, id: \.self) { mode in
                    Button { store.setImportMode(mode) } label: {
                        if store.importMode == mode { Label(mode.title, systemImage: "checkmark") } else { Text(mode.title) }
                    }
                }
            }
            Divider()
            Button("撤销删除或清空", action: store.undoRemove).disabled(!store.canUndo)
            Button("退出 context basket") { NSApp.terminate(nil) }
        } label: {
            Color.clear.frame(width: BubbleLayout.cardWidth, height: BubbleLayout.cardHeight)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("添加材料").accessibilityLabel("添加材料")
    }

    private func dropChoice(_ mode: FileImportMode) -> some View {
        let color = mode == .copy ? Color(red: 0.65, green: 0.83, blue: 0.73) : Color(red: 0.56, green: 0.73, blue: 0.97)
        let selected = store.dropFeedback?.mode == mode
        return VStack(spacing: 10) {
            Image(systemName: mode == .copy ? "doc.on.doc" : "link").font(.system(size: 22, weight: .light))
            Text(mode == .copy ? "副本" : "链接").font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(selected ? 0.95 : 0.76), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(color.opacity(selected ? 0.9 : 0.3), lineWidth: 0.8) }
        .allowsHitTesting(false)
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
                Color.clear
                cardContent
                PromptDragSource(store: store, material: item, clicked: preview, hoverChanged: { hovered = $0 })
                HStack {
                    Text(item.modeLabel).font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
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
                    HStack { Spacer(); Button("完成", action: store.finishNoteEditing).buttonStyle(.plain).font(.system(size: 10, weight: .medium)).foregroundStyle(accent).padding(.horizontal, 8).padding(.vertical, 3).background(noteBackground, in: Capsule()) }
                }.padding(9).background(.black.opacity(0.15)).padding(.horizontal, 7).padding(.bottom, 7)
            } else if hasNote {
                Button { store.editNote(item.id) } label: {
                    HStack(alignment: .top, spacing: 3) {
                        Text("“").font(.system(size: 14, weight: .semibold))
                        Text(item.note ?? "").font(.system(size: 10)).lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("”").font(.system(size: 14, weight: .semibold))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .foregroundStyle(accent).padding(.horizontal, 8).padding(.vertical, 4)
                    .frame(height: 30)
                    .background(noteBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).padding(.horizontal, 10).frame(height: 38).help("编辑文件说明")
            }
        }
        .frame(width: BubbleLayout.cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .basketGlass(cornerRadius: 24)
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
        configuration.label.font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : .white.opacity(0.55))
            .frame(maxWidth: .infinity).frame(height: BubbleLayout.headerHeight)
            .basketGlass(cornerRadius: 22, interactive: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct HeaderIconStyle: ButtonStyle {
    var active = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .medium))
            .foregroundStyle(isEnabled ? .white.opacity(active ? 1 : 0.85) : .white.opacity(0.3))
            .frame(width: BubbleLayout.iconSize, height: BubbleLayout.headerHeight)
            .basketGlass(cornerRadius: 22, interactive: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct ShelfIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 25, height: 26).foregroundStyle(.white.opacity(configuration.isPressed ? 1 : 0.5))
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 7))
    }
}
