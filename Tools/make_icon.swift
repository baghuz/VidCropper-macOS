import AppKit
import Foundation

// Renders the VidCropper app icon as an .icns bundle.
// Usage: swift Tools/make_icon.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("Resources/AppIcon.iconset")
let icnsURL = root.appendingPathComponent("Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(in size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    let scale = size / 1024.0

    context.saveGState()
    context.scaleBy(x: scale, y: scale)

    let outer = NSRect(x: 40, y: 40, width: 944, height: 944)
    let outerPath = roundedRect(outer, radius: 210)
    outerPath.addClip()

    let background = NSGradient(colors: [
        color(0x171A20),
        color(0x08090C)
    ])!
    background.draw(in: outerPath, angle: -90)

    let glow = NSGradient(colors: [
        color(0xC8F65C, alpha: 0.16),
        color(0xC8F65C, alpha: 0)
    ])!
    glow.draw(
        fromCenter: NSPoint(x: 300, y: 780),
        radius: 20,
        toCenter: NSPoint(x: 300, y: 780),
        radius: 620,
        options: []
    )

    // Video thumbnail.
    let videoRect = NSRect(x: 176, y: 332, width: 672, height: 374)
    let videoPath = roundedRect(videoRect, radius: 46)
    context.saveGState()
    videoPath.addClip()

    let videoGradient = NSGradient(colors: [
        color(0x4737E0),
        color(0xA23EA6),
        color(0xE39357)
    ])!
    videoGradient.draw(in: videoPath, angle: -35)

    // Sun.
    color(0xFFF4CE, alpha: 0.75).setFill()
    NSBezierPath(ovalIn: NSRect(x: 250, y: 585, width: 76, height: 76)).fill()

    // Mountain silhouettes.
    color(0x0B0C10, alpha: 0.16).setFill()
    let backMountain = NSBezierPath()
    backMountain.move(to: NSPoint(x: 176, y: 332))
    backMountain.line(to: NSPoint(x: 380, y: 540))
    backMountain.line(to: NSPoint(x: 535, y: 405))
    backMountain.line(to: NSPoint(x: 700, y: 560))
    backMountain.line(to: NSPoint(x: 848, y: 430))
    backMountain.line(to: NSPoint(x: 848, y: 332))
    backMountain.close()
    backMountain.fill()

    color(0x0B0C10, alpha: 0.28).setFill()
    let frontMountain = NSBezierPath()
    frontMountain.move(to: NSPoint(x: 176, y: 332))
    frontMountain.line(to: NSPoint(x: 470, y: 500))
    frontMountain.line(to: NSPoint(x: 650, y: 390))
    frontMountain.line(to: NSPoint(x: 848, y: 515))
    frontMountain.line(to: NSPoint(x: 848, y: 332))
    frontMountain.close()
    frontMountain.fill()

    context.restoreGState()

    // Dim everything outside a vertical 9:16 crop.
    let cropRect = NSRect(x: 408, y: 332, width: 208, height: 374)
    let dimPath = NSBezierPath(rect: videoRect)
    dimPath.append(roundedRect(cropRect, radius: 18))
    dimPath.windingRule = .evenOdd
    color(0x050609, alpha: 0.56).setFill()
    dimPath.fill()

    // Crop frame.
    color(0xC8F65C).setStroke()
    let frame = roundedRect(cropRect.insetBy(dx: 2, dy: 2), radius: 18)
    frame.lineWidth = 14
    frame.stroke()

    // Corner handles.
    color(0xC8F65C).setFill()
    let dotSize: CGFloat = 42
    for point in [
        NSPoint(x: cropRect.minX, y: cropRect.minY),
        NSPoint(x: cropRect.maxX, y: cropRect.minY),
        NSPoint(x: cropRect.minX, y: cropRect.maxY),
        NSPoint(x: cropRect.maxX, y: cropRect.maxY)
    ] {
        color(0x08090C).setStroke()
        let outerDot = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - dotSize / 2 - 4,
                y: point.y - dotSize / 2 - 4,
                width: dotSize + 8,
                height: dotSize + 8
            )
        )
        outerDot.lineWidth = 8
        outerDot.stroke()
        color(0xC8F65C).setFill()
        NSBezierPath(
            ovalIn: NSRect(
                x: point.x - dotSize / 2,
                y: point.y - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
        ).fill()
    }

    context.restoreGState()

    // Subtle outer border.
    let border = roundedRect(outer.insetBy(dx: 1, dy: 1), radius: 209)
    border.lineWidth = 2
    color(0xFFFFFF, alpha: 0.12).setStroke()
    border.stroke()

    return image
}

let base = drawIcon(in: 1024)

func writePNG(size: Int, name: String) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "icon", code: 1)
    }

    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    base.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2)
    }
    try data.write(to: iconsetURL.appendingPathComponent(name))
}

let entries: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in entries {
    try writePNG(size: size, name: name)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Created \(icnsURL.path)")
} else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
