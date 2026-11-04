import AppKit
import Foundation

// Original Kernel mark: a seed at the intersection of a K and a conversation.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGradient(starting: NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.16, alpha: 1), ending: NSColor(calibratedRed: 0.04, green: 0.24, blue: 0.28, alpha: 1))!.draw(in: background, angle: 45)
let ring = NSBezierPath(roundedRect: NSRect(x: 152, y: 152, width: 720, height: 720), xRadius: 210, yRadius: 210)
NSColor.white.withAlphaComponent(0.12).setStroke(); ring.lineWidth = 3; ring.stroke()
let mark = NSBezierPath()
mark.move(to: NSPoint(x: 350, y: 292)); mark.line(to: NSPoint(x: 350, y: 732))
mark.move(to: NSPoint(x: 674, y: 732)); mark.line(to: NSPoint(x: 460, y: 516)); mark.line(to: NSPoint(x: 692, y: 292))
mark.lineWidth = 76; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
NSColor(calibratedRed: 0.83, green: 0.98, blue: 0.94, alpha: 1).setStroke(); mark.stroke()
NSColor(calibratedRed: 0.32, green: 0.91, blue: 0.72, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 419, y: 475, width: 82, height: 82)).fill()
image.unlockFocus()
let folder = root.appendingPathComponent("KernelApp/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, String, Int)] = [("20x20", "1x", 20), ("20x20", "2x", 40), ("29x29", "1x", 29), ("29x29", "2x", 58), ("40x40", "1x", 40), ("40x40", "2x", 80), ("76x76", "1x", 76), ("76x76", "2x", 152), ("83.5x83.5", "2x", 167), ("1024x1024", "1x", 1024)]
var entries: [[String: String]] = []
for (size, scale, pixels) in sizes {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let filename = "Kernel-\(pixels).png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(filename))
    entries.append(["size": size, "scale": scale, "idiom": pixels == 1024 ? "ios-marketing" : "ipad", "filename": filename])
}
try JSONSerialization.data(withJSONObject: ["images": entries, "info": ["version": 1, "author": "xcode"]], options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
print("Generated 10 correctly sized Kernel icons")
