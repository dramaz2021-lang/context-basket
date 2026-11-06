import AppKit
import SwiftUI

extension View {
    func basketGlass(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(BasketGlassSurface(cornerRadius: cornerRadius, interactive: interactive))
    }
}

/// Each bubble owns its glass background. Content and the gaps never enter a shared glass layer.
private struct BasketGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if #available(macOS 26.0, *) {
                    Color.clear
                        // Regular glass increases its tint on larger surfaces. Use the same
                        // fixed dimming layer at every size so cards match the toolbar.
                        .glassEffect(.clear.interactive(interactive), in: shape)
                        .background(.black.opacity(0.30), in: shape)
                        .clipShape(shape)
                } else {
                    GlassBackdrop().clipShape(shape)
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.06), .white.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.7
                ).allowsHitTesting(false)
            }
    }
}

private struct GlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
