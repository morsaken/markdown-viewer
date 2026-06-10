// Generates a 1024x1024 macOS-style app icon PNG for Markdown Viewer.
// Run: swift scripts/make_icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let s = CGFloat(size)
// macOS icons sit on a rounded-rect with margin around the full canvas.
let margin = s * 0.09
let rect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
let corner = rect.width * 0.225
let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

// Background gradient (deep slate -> blue).
ctx.saveGState()
ctx.addPath(path)
ctx.clip()
let colors = [
    NSColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 1).cgColor,
    NSColor(red: 0.10, green: 0.45, blue: 0.85, alpha: 1).cgColor,
]
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad,
    start: CGPoint(x: rect.minX, y: rect.maxY),
    end: CGPoint(x: rect.maxX, y: rect.minY),
    options: [])
ctx.restoreGState()

// Draw the classic Markdown mark: "M" with a down-arrow, in a rounded badge.
func drawMarkdownMark() {
    let inset = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.26)
    let stroke = inset.width * 0.075
    NSColor.white.setStroke()
    NSColor.white.setFill()

    let h = inset.height
    let topY = inset.maxY
    let botY = inset.minY
    let mWidth = inset.width * 0.62
    let x0 = inset.minX
    // "M" shape
    let m = NSBezierPath()
    m.lineWidth = stroke
    m.lineJoinStyle = .round
    m.lineCapStyle = .round
    m.move(to: CGPoint(x: x0, y: botY))
    m.line(to: CGPoint(x: x0, y: topY))
    m.line(to: CGPoint(x: x0 + mWidth * 0.5, y: topY - h * 0.45))
    m.line(to: CGPoint(x: x0 + mWidth, y: topY))
    m.line(to: CGPoint(x: x0 + mWidth, y: botY))
    m.stroke()

    // Down arrow to the right of the M
    let ax = inset.maxX - inset.width * 0.13
    let arrowTop = topY
    let arrowBot = botY + h * 0.06
    let arrow = NSBezierPath()
    arrow.lineWidth = stroke
    arrow.lineJoinStyle = .round
    arrow.lineCapStyle = .round
    arrow.move(to: CGPoint(x: ax, y: arrowTop))
    arrow.line(to: CGPoint(x: ax, y: arrowBot))
    arrow.stroke()
    // arrow head
    let head = NSBezierPath()
    head.lineWidth = stroke
    head.lineJoinStyle = .round
    head.lineCapStyle = .round
    let hw = inset.width * 0.11
    head.move(to: CGPoint(x: ax - hw, y: arrowBot + hw))
    head.line(to: CGPoint(x: ax, y: arrowBot))
    head.line(to: CGPoint(x: ax + hw, y: arrowBot + hw))
    head.stroke()
}
drawMarkdownMark()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8))
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}
