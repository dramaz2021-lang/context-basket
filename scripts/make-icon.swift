import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let variants = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
                (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"),
                (512, "512x512"), (1024, "512x512@2x")]
for (pixels, suffix) in variants {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let shape = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888), xRadius: 204, yRadius: 204)
    NSGradient(starting: NSColor(calibratedWhite: 0.24, alpha: 1), ending: NSColor(calibratedWhite: 0.13, alpha: 1))!.draw(in: shape, angle: -90)
    NSColor.white.withAlphaComponent(0.15).setStroke()
    shape.lineWidth = 3
    shape.stroke()
    let symbol = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(paletteColors: [NSColor(calibratedRed: 0.65, green: 0.83, blue: 0.73, alpha: 1)]))!
    symbol.draw(in: NSRect(x: 240, y: 272, width: 544, height: 490))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("icon_\(suffix).png"))
}
