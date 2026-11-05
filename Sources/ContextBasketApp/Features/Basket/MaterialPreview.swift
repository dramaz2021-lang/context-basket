import SwiftUI
import AppKit
import Quartz

struct MaterialPreview: View {
    let item: Material
    let library: MaterialLibrary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(18)
            Divider()
            if let text = item.text {
                ScrollView {
                    Text(text).font(.system(size: 14)).lineSpacing(6).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(22)
                }
            } else if let path = item.assetPath {
                FileQuickLook(url: library.url(for: path)).padding(12)
            }
        }
        .frame(width: 520, height: 430)
        .preferredColorScheme(.dark)
    }
}

private struct FileQuickLook: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = false
        view.previewItem = url as NSURL
        return view
    }
    func updateNSView(_ nsView: QLPreviewView, context: Context) { nsView.previewItem = url as NSURL }
}
