import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(red: 0.65, green: 0.83, blue: 0.73)
// Resolve the property-wrapper type explicitly, including SDKs with a same-name macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ShelfView: View {
    @ObservedObject var store: BasketStore
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(store.items) { item in
                                MaterialCard(item: item, thumbnail: store.thumbnail(for: item),
                                             preview: { if !item.isLoading { store.preview = item } },
                                             remove: { withAnimation(.easeInOut(duration: 0.18)) { store.remove(item.id) } })
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 14)
                    }
                    .scrollIndicators(.automatic)
                    .onChange(of: store.items.count) { _, _ in
                        if let last = store.items.last {
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            footer
        }
        .background {
            ZStack {
                FrostedBackground()
                Color(red: 0.12, green: 0.13, blue: 0.15).opacity(0.92)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay {
            if store.isDragOver {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.35))
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                        .padding(7)
                    Label("松开，添加到这里", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 20).padding(.vertical, 13)
                        .background(.black.opacity(0.75), in: Capsule())
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: store.isDragOver)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .preferredColorScheme(.dark)
        .sheet(item: $store.preview) { item in
            MaterialPreview(item: item, library: store.library)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent)
            Text("上下文篮").font(.system(size: 14, weight: .semibold))
            Text("\(store.items.count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.white.opacity(0.07), in: Capsule())
                .accessibilityLabel("\(store.items.count) 项材料")
            Spacer()
            Button(action: store.chooseFiles) { Image(systemName: "plus").font(.system(size: 13, weight: .medium)) }
                .buttonStyle(ShelfIconStyle())
                .help("添加文件")
                .accessibilityLabel("添加文件")
            Menu {
                Button("添加文件…", action: store.chooseFiles)
                Button("粘贴材料", action: store.paste)
                Button("撤销删除", action: store.undoRemove).disabled(!store.canUndo)
                Divider()
                Button("退出上下文篮") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium)).frame(width: 24, height: 26)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("更多操作").accessibilityLabel("更多操作")
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(ShelfIconStyle()).help("收起浮窗").accessibilityLabel("收起浮窗")
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 17).frame(height: 58)
        .background(WindowDragArea())
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            ZStack {
                emptyCard(symbol: "text.alignleft", color: Color(red: 0.79, green: 0.72, blue: 0.94))
                    .rotationEffect(.degrees(-16)).offset(x: -38, y: 6)
                emptyCard(symbol: "link", color: Color(red: 0.77, green: 0.82, blue: 0.98))
                    .rotationEffect(.degrees(15)).offset(x: 38, y: 6)
                emptyCard(symbol: "photo", color: accent).rotationEffect(.degrees(-2)).offset(y: -2)
            }
            .frame(height: 86)
            Text("把材料放在这里")
                .font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                .padding(.top, 15)
            Text("图片、文字、链接、文件")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.42)).padding(.top, 8)
            Spacer(minLength: 22)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func emptyCard(symbol: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(Color(red: 0.21, green: 0.23, blue: 0.25))
            .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.12)) }
            .overlay { Image(systemName: symbol).font(.system(size: 25, weight: .light)).foregroundStyle(color) }
            .frame(width: 65, height: 76)
            .shadow(color: .black.opacity(0.25), radius: 9, y: 5)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 16)
            if let error = store.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    Text(error).lineLimit(3)
                    Spacer(minLength: 0)
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                .padding(12).background(.orange.opacity(0.08))
            }
            HStack(spacing: 6) {
                Circle().fill(accent.opacity(0.8)).frame(width: 4, height: 4)
                Text(store.items.isEmpty ? "随手收集，留在本机" : "\(store.items.count) 项材料 · 本机收集")
                    .font(.system(size: 10))
                Spacer()
                if store.canUndo {
                    Button("撤销删除", action: store.undoRemove).buttonStyle(.plain).foregroundStyle(accent)
                        .font(.system(size: 10))
                } else {
                    Button(action: store.paste) {
                        HStack(spacing: 4) {
                            Text("⌘ V").font(.system(size: 10, weight: .medium, design: .monospaced))
                            Text("粘贴").font(.system(size: 10))
                        }
                    }.buttonStyle(.plain).help("粘贴材料").accessibilityLabel("粘贴材料")
                }
            }
            .foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 19).frame(height: 40)
        }
    }
}

private struct MaterialCard: View {
    let item: Material
    let thumbnail: NSImage?
    let preview: () -> Void
    let remove: () -> Void
    @ViewState private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.12)
                cardContent
            }
            .frame(height: 112).clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.white.opacity(0.85))
                Text(item.detail).font(.system(size: 9)).lineLimit(1).foregroundStyle(.white.opacity(0.38))
            }
            .padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading).frame(height: 45)
        }
        .background(.white.opacity(hovered ? 0.09 : 0.045))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(hovered ? 0.22 : 0.07)) }
        .contentShape(RoundedRectangle(cornerRadius: 13))
        .onTapGesture(perform: preview)
        .overlay(alignment: .topTrailing) {
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95)).frame(width: 22, height: 22)
                    .background(Color(white: 0.16).opacity(0.97), in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.2)) }
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            }
            .buttonStyle(.plain).padding(6)
            .opacity(hovered ? 1 : 0)
            .allowsHitTesting(hovered)
            .help("移除这份材料")
            .accessibilityLabel("删除 \(item.title)")
        }
        .background {
            GeometryReader { geometry in
                HoverTrackingArea { hovered = $0 }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovered)
        .help(item.title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
        .accessibilityAction(named: "预览", preview)
        .accessibilityAction(named: "删除", remove)
    }

    @ViewBuilder private var cardContent: some View {
        if item.isLoading {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch item.kind {
            case .image:
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo").font(.system(size: 30)).foregroundStyle(accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .text:
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "text.alignleft").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.77, green: 0.70, blue: 0.90))
                    Text(item.text ?? "").font(.system(size: 11)).lineSpacing(3).lineLimit(4)
                        .foregroundStyle(.white.opacity(0.76)).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(12)
            case .link:
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "link").font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color(red: 0.67, green: 0.78, blue: 0.96))
                    Text(item.text ?? "").font(.system(size: 11)).lineLimit(3).lineSpacing(3)
                        .foregroundStyle(.white.opacity(0.68)).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(14)
            case .file:
                Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: (item.title as NSString).pathExtension) ?? .data))
                    .resizable().scaledToFit().frame(width: 55, height: 64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ShelfIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 25, height: 26)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 1 : 0.5))
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct FrostedBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct WindowDragArea: NSViewRepresentable {
    class Handle: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ nsView: Handle, context: Context) {}
}

/// Floating nonactivating panels need tracking even while another app is active.
private struct HoverTrackingArea: NSViewRepresentable {
    var changed: (Bool) -> Void
    final class TrackingView: NSView {
        var changed: (Bool) -> Void = { _ in }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag], owner: self))
        }
        override func mouseEntered(with event: NSEvent) { changed(true) }
        override func mouseExited(with event: NSEvent) { changed(false) }
    }
    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.changed = changed
        return view
    }
    func updateNSView(_ nsView: TrackingView, context: Context) { nsView.changed = changed }
}
