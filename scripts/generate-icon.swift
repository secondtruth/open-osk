// Renders the OpenOSK app icon (keyboard glyph on a gradient) into an
// .iconset directory. Run via scripts/generate-icon.sh, which also converts
// the set to Assets/OpenOSK.icns using iconutil.
import AppKit

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/OpenOSK.iconset"

try? FileManager.default.createDirectory(
    atPath: outputDir, withIntermediateDirectories: true)

func drawIcon(canvas: CGFloat) {
    let inset = canvas * 0.05
    let bgRect = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    let background = NSBezierPath(roundedRect: bgRect, xRadius: canvas * 0.2, yRadius: canvas * 0.2)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.20, green: 0.42, blue: 0.95, alpha: 1),
        ending: NSColor(calibratedRed: 0.07, green: 0.14, blue: 0.42, alpha: 1)
    )!
    gradient.draw(in: background, angle: -90)

    let columns = 5
    let gap = canvas * 0.035
    let areaInset = canvas * 0.17
    let keyWidth = (canvas - 2 * areaInset - CGFloat(columns - 1) * gap) / CGFloat(columns)
    let keyHeight = keyWidth * 0.78
    let radius = keyWidth * 0.22

    NSColor.white.withAlphaComponent(0.93).setFill()
    var y = canvas - areaInset - keyHeight
    for _ in 0..<3 {
        var x = areaInset
        for _ in 0..<columns {
            NSBezierPath(
                roundedRect: NSRect(x: x, y: y, width: keyWidth, height: keyHeight),
                xRadius: radius, yRadius: radius
            ).fill()
            x += keyWidth + gap
        }
        y -= keyHeight + gap
    }

    NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.18, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: NSRect(
            x: areaInset, y: y, width: canvas - 2 * areaInset, height: keyHeight),
        xRadius: radius, yRadius: radius
    ).fill()
}

func render(pixels: Int, filename: String) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create bitmap for \(filename)")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(canvas: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(filename)")
    }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
    try! data.write(to: url)
}

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (pixels, filename) in variants {
    render(pixels: pixels, filename: filename)
}
print("Rendered iconset at \(outputDir)")
