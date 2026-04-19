import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: GenerateIcon.swift <output.{png|tiff}>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let backgroundColor = NSColor(calibratedRed: 0.16, green: 0.66, blue: 0.55, alpha: 1)
let textColor = NSColor.white

func drawIcon(in rect: CGRect, scale: CGFloat) {
    NSColor.clear.setFill()
    rect.fill()

    let tileInset = scale * 72
    let cornerRadius = scale * 220
    let tileRect = rect.insetBy(dx: tileInset, dy: tileInset)
    let iconPath = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundColor.setFill()
    iconPath.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let font = NSFont.systemFont(ofSize: scale * 150, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraph
    ]

    let text = "localsend-\nusb" as NSString
    let textRect = CGRect(
        x: scale * 140,
        y: scale * 300,
        width: scale * 744,
        height: scale * 424
    )
    text.draw(in: textRect, withAttributes: attributes)
}

func makeBitmapRep(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(in: CGRect(x: 0, y: 0, width: size, height: size), scale: CGFloat(size) / 1024)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

switch outputURL.pathExtension.lowercased() {
case "png":
    let rep = makeBitmapRep(size: 1024)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to create png data\n", stderr)
        exit(1)
    }
    try pngData.write(to: outputURL)
case "tif", "tiff":
    let image = NSImage(size: NSSize(width: 1024, height: 1024))
    for size in [16, 32, 48, 128, 256, 512, 1024] {
        image.addRepresentation(makeBitmapRep(size: size))
    }
    guard let tiffData = image.tiffRepresentation else {
        fputs("failed to create tiff data\n", stderr)
        exit(1)
    }
    try tiffData.write(to: outputURL)
default:
    fputs("unsupported output extension\n", stderr)
    exit(1)
}
