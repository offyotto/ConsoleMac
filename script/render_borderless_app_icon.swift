import AppKit
import Foundation

struct IconVariant {
    let filename: String
    let pixels: CGFloat
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let variants: [IconVariant] = [
    .init(filename: "icon_16x16.png", pixels: 16),
    .init(filename: "icon_16x16@2x.png", pixels: 32),
    .init(filename: "icon_32x32.png", pixels: 32),
    .init(filename: "icon_32x32@2x.png", pixels: 64),
    .init(filename: "icon_128x128.png", pixels: 128),
    .init(filename: "icon_128x128@2x.png", pixels: 256),
    .init(filename: "icon_256x256.png", pixels: 256),
    .init(filename: "icon_256x256@2x.png", pixels: 512),
    .init(filename: "icon_512x512.png", pixels: 512),
    .init(filename: "icon_512x512@2x.png", pixels: 1024)
]

for variant in variants {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(variant.pixels),
        pixelsHigh: Int(variant.pixels),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not allocate bitmap for \(variant.filename)")
    }

    representation.size = NSSize(width: variant.pixels, height: variant.pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)

    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true

    let scale = variant.pixels / 1024
    let canvas = CGRect(origin: .zero, size: CGSize(width: variant.pixels, height: variant.pixels))
    NSColor.clear.setFill()
    NSBezierPath(rect: canvas).fill()

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    // Draw only the artwork. No Icon Composer glass plate, baked stroke, or outer shadow.
    let background = NSBezierPath(
        roundedRect: rect(56, 56, 912, 912),
        xRadius: 212 * scale,
        yRadius: 212 * scale
    )
    NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
    background.fill()

    let terminalOuter = NSBezierPath(
        roundedRect: rect(244, 316, 536, 392),
        xRadius: 54 * scale,
        yRadius: 54 * scale
    )
    NSColor.white.setFill()
    terminalOuter.fill()

    NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
    NSBezierPath(rect: rect(300, 372, 424, 280)).fill()

    let chevron = NSBezierPath()
    chevron.move(to: CGPoint(x: 370 * scale, y: 606 * scale))
    chevron.line(to: CGPoint(x: 486 * scale, y: 512 * scale))
    chevron.line(to: CGPoint(x: 370 * scale, y: 418 * scale))
    chevron.lineWidth = max(3, 64 * scale)
    chevron.lineCapStyle = .butt
    chevron.lineJoinStyle = .miter
    NSColor.white.setStroke()
    chevron.stroke()

    NSColor.white.setFill()
    NSBezierPath(roundedRect: rect(548, 404, 156, 54), xRadius: 4 * scale, yRadius: 4 * scale).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = representation.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(variant.filename)")
    }

    try png.write(to: outputDirectory.appendingPathComponent(variant.filename))
}
