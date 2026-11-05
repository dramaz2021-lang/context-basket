import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(red: 0.65, green: 0.83, blue: 0.73)
// Disambiguate the property wrapper from the same-name macro in newer SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ShelfView: View {
    @ObservedObject var store: BasketStore
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            importOptions
            if store.items.isEmpty { emptyState } else { materials }
            promptEditor
            footer
        }
        .background {
            ZStack {
                FrostedBackground()
                Color(red: 0.12, green: 0.13, blue: 0.15).opacity(0.92)
            }
        }
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.14), lineWidth: 1).allowsHitTesting(false) }
        .overlay {
            if store.isDragOver {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.35))
                    RoundedRectangle(cornerRadius: 20).strokeBorder(accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5])).padding(7)
                    Label(store.activeDropMode == .reference ? "松开，引用源文件地址" : "松开，添加副本", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .padding(16).background(.black.opacity(0.8), in: Capsule())
                }.allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .preferredColorScheme(.dark)
        .sheet(item: $store.preview) { MaterialPreview(item: $0, library: store.library) }
        .sheet(isPresented: $store.showLocationEditor) { LocationEditor(store: store) }
        .sheet(isPresented: $store.showPromptPreview) { PromptPreview(store: store) }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "tray.full.fill").font(.system(size: 17)).foregroundStyle(accent)
            Text("上下文篮").font(.system(size: 14, weight: .semibold))
            Text("\(store.items.count)").font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 7).padding(.vertical, 3)
                .background(.white.opacity(0.07), in: Capsule()).accessibilityLabel("\(store.items.count) 项材料")
            Spacer()
            Button(action: store.chooseFiles) { Image(systemName: "plus") }
                .buttonStyle(ShelfIconStyle()).help("添加文件").accessibilityLabel("添加文件")
            Menu {
                Button("添加文件…", action: store.chooseFiles)
                Button("添加链接或本机地址…") { store.showLocationEditor = true }
                Button("粘贴为材料", action: store.paste)
                Button("撤销删除", action: store.undoRemove).disabled(!store.canUndo)
                Divider()
                Button("退出上下文篮") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis").frame(width: 24, height: 26) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("更多操作")
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(ShelfIconStyle()).help("收起浮窗").accessibilityLabel("收起浮窗")
        }
        .foregroundStyle(.white.opacity(0.9)).padding(.horizontal, 17).frame(height: 56)
        .background(WindowDragArea())
    }

    private var importOptions: some View {
        HStack(spacing: 6) {
            Text("拖入文件").foregroundStyle(.white.opacity(0.4))
            Menu {
                ForEach(FileImportMode.allCases, id: \.self) { mode in
                    Button { store.setImportMode(mode) } label: {
                        if store.importMode == mode { Label(mode.title, systemImage: "checkmark") } else { Text(mode.title) }
                    }
                }
            } label: {
                Label(store.importMode.title, systemImage: store.importMode == .copy ? "doc.on.doc" : "link").foregroundStyle(accent)
            }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("文件导入方式：\(store.importMode.title)")
            Spacer()
            Button { store.showLocationEditor = true } label: { Image(systemName: "link.badge.plus") }
                .buttonStyle(.plain).foregroundStyle(.white.opacity(0.5)).help("添加链接或本机地址").accessibilityLabel("添加链接或本机地址")
        }.font(.system(size: 10)).padding(.horizontal, 18).padding(.bottom, 13)
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
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("给 Agent 的指令", systemImage: "text.bubble").font(.system(size: 11, weight: .medium))
                Spacer()
                Text("随材料一起带走").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
            }.foregroundStyle(.white.opacity(0.65))
            ZStack(alignment: .topLeading) {
                if store.prompt.isEmpty {
                    Text("想让 Agent 做什么？\n可以边收集材料，边修改指令。")
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 5).padding(.top, 8).allowsHitTesting(false)
                }
                TextEditor(text: Binding(get: { store.prompt }, set: store.setPrompt))
                    .font(.system(size: 12)).lineSpacing(4).scrollContentBackground(.hidden).accessibilityLabel("给 Agent 的指令")
            }
            .padding(7).frame(height: 104).background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08)).allowsHitTesting(false) }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
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
                Button { store.showPromptPreview = true } label: { Image(systemName: "doc.text.magnifyingglass") }
                    .buttonStyle(.plain).help("预览完整 Prompt").accessibilityLabel("预览完整 Prompt")
                Button("复制文字", action: store.copyPrompt).buttonStyle(.plain).font(.system(size: 11)).disabled(!store.canExport)
                if store.canUndo { Button(action: store.undoRemove) { Image(systemName: "arrow.uturn.backward") }.buttonStyle(.plain).help("撤销删除").accessibilityLabel("撤销删除") }
                Spacer(minLength: 0)
                Label("拖出全部", systemImage: "hand.draw").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.canExport ? Color(white: 0.12) : .white.opacity(0.25))
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(store.canExport ? accent : Color.white.opacity(0.06), in: Capsule())
                    .overlay { PromptDragSource(store: store, clicked: { store.showPromptPreview = true }) }
                    .help("拖动：指令、材料说明和副本附件；点击：预览 Prompt")
                    .accessibilityElement(children: .ignore).accessibilityLabel("拖出全部，点击预览 Prompt")
                    .accessibilityAddTraits(.isButton).accessibilityAction { store.showPromptPreview = true }
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
    private func preview() { if !item.isLoading { store.preview = item } }

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
                    TextField("说明它的用途或修改重点…", text: Binding(get: { item.note ?? "" }, set: { store.setNote(item.id, $0) }), axis: .vertical)
                        .lineLimit(2...5).textFieldStyle(.plain).font(.system(size: 11)).accessibilityLabel("文件说明：\(item.title)")
                    HStack { Spacer(); Button("完成") { store.noteEditorID = nil }.buttonStyle(.plain).foregroundStyle(accent).font(.system(size: 10)) }
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
            action("eye", label: "预览材料", run: preview)
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
            Text("拖出全部会附带 PROMPT.txt 和副本文件；源地址保留在文字中。")
                .font(.system(size: 10)).foregroundStyle(.secondary).padding(14)
        }.frame(width: 520, height: 480).preferredColorScheme(.dark)
    }
}

private struct ShelfIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 25, height: 26).foregroundStyle(.white.opacity(configuration.isPressed ? 1 : 0.5))
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 7))
    }
}
private struct FrostedBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = .hudWindow; view.blendingMode = .behindWindow; view.state = .active; return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
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
