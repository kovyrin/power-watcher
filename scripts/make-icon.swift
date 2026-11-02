import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for baseSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = baseSize * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                             isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap),
              let gradient = NSGradient(starting: NSColor(srgbRed: 1, green: 0.57, blue: 0.13, alpha: 1),
                                        ending: NSColor(srgbRed: 0.97, green: 0.22, blue: 0.08, alpha: 1)) else {
            fatalError("Could not render the app icon")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                                      xRadius: 200, yRadius: 200)
        gradient.draw(in: background, angle: -45)
        // Original concentric edge artwork; no SF Symbols are used in the icon.
        let rings: [(CGFloat, CGFloat, CGFloat)] = [(246, 34, 1), (312, 24, 0.55), (371, 16, 0.25)]
        for (inset, lineWidth, alpha) in rings {
            NSColor.white.withAlphaComponent(alpha).setStroke()
            let ring = NSBezierPath(roundedRect: NSRect(x: inset, y: inset,
                                                       width: 1024 - inset * 2, height: 1024 - inset * 2),
                                    xRadius: (1024 - inset * 2) * 0.20,
                                    yRadius: (1024 - inset * 2) * 0.20)
            ring.lineWidth = lineWidth
            ring.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode the app icon")
        }
        let suffix = scale == 1 ? "" : "@2x"
        try data.write(to: outputDirectory.appendingPathComponent("icon_\(baseSize)x\(baseSize)\(suffix).png"))
    }
}
