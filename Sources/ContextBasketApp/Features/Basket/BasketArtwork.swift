import AppKit

/// Shared vector artwork for the floating handle, menu bar, and app icon.
enum BasketArtwork {
    static func image(size: CGFloat = 100, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.scaleBy(x: rect.width / 100, y: rect.height / 100)
            draw(in: context)
            context.restoreGState()
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "多份文件放进篮子"
        return image
    }

    private static func draw(in context: CGContext) {
        context.setLineCap(.round)
        context.setLineJoin(.round)

        func paper(center: CGPoint, width: CGFloat, height: CGFloat, angle: CGFloat, opacity: CGFloat) {
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: angle)
            let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
            context.setFillColor(NSColor.white.withAlphaComponent(opacity).cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil))
            context.fillPath()
            context.setBlendMode(.clear)
            context.setLineWidth(2.4)
            for y in [rect.minY + 11, rect.minY + 18] {
                context.move(to: CGPoint(x: rect.minX + 6, y: y))
                context.addLine(to: CGPoint(x: rect.maxX - 6, y: y))
                context.strokePath()
            }
            context.restoreGState()
        }

        paper(center: CGPoint(x: 29, y: 34), width: 23, height: 36, angle: -0.26, opacity: 0.68)
        paper(center: CGPoint(x: 70, y: 36), width: 23, height: 35, angle: 0.27, opacity: 0.80)
        paper(center: CGPoint(x: 49, y: 28), width: 25, height: 43, angle: 0.02, opacity: 1)

        // A wide rim and tapered woven body distinguish a basket from an inbox tray.
        context.setFillColor(NSColor.white.cgColor)
        context.move(to: CGPoint(x: 15, y: 51))
        context.addLine(to: CGPoint(x: 85, y: 51))
        context.addLine(to: CGPoint(x: 77, y: 83))
        context.addQuadCurve(to: CGPoint(x: 69, y: 89), control: CGPoint(x: 76, y: 89))
        context.addLine(to: CGPoint(x: 31, y: 89))
        context.addQuadCurve(to: CGPoint(x: 23, y: 83), control: CGPoint(x: 24, y: 89))
        context.closePath()
        context.fillPath()
        context.addPath(CGPath(roundedRect: CGRect(x: 10, y: 49, width: 80, height: 7), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
        context.fillPath()

        context.saveGState()
        context.setBlendMode(.clear)
        context.setLineWidth(4)
        for x: CGFloat in [34, 50, 66] {
            context.move(to: CGPoint(x: x, y: 63))
            context.addLine(to: CGPoint(x: x, y: 79))
            context.strokePath()
        }
        context.restoreGState()
    }
}
