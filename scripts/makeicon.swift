// Draws AppIcon.png (1024px): night-to-ocean gradient tile, soft waves, white notes glyph.
import AppKit
let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)   // Apple's icon grid: 824pt tile on a 1024 canvas
let shape = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set(); NSColor.black.setFill(); shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(colors: [NSColor(red: 0.10, green: 0.62, blue: 0.72, alpha: 1), NSColor(red: 0.16, green: 0.20, blue: 0.56, alpha: 1),
                    NSColor(red: 0.13, green: 0.10, blue: 0.36, alpha: 1)])!.draw(in: tile, angle: 90)
// Three overlapping waves along the bottom.
for (i, alpha) in [0.14, 0.18, 0.24].enumerated() {
    let base = 380.0 - Double(i) * 70, amp = 26.0, phase = Double(i) * 1.9
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: tile.minX, y: tile.minY))
    for x in stride(from: tile.minX, through: tile.maxX, by: 4) {
        wave.line(to: NSPoint(x: x, y: base + amp * sin((x - tile.minX) / 824 * 2.4 * .pi + phase)))
    }
    wave.line(to: NSPoint(x: tile.maxX, y: tile.minY)); wave.close()
    NSColor.white.withAlphaComponent(alpha).setFill(); wave.fill()
}
NSGraphicsContext.restoreGraphicsState()

// White notes glyph, tinted by filling over the symbol's alpha.
let symbol = NSImage(systemSymbolName: "music.quarternote.3", accessibilityDescription: nil)!
    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 400, weight: .semibold))!
let glyphWidth = 470.0, glyphSize = NSSize(width: glyphWidth, height: glyphWidth * symbol.size.height / symbol.size.width)
let white = NSImage(size: glyphSize, flipped: false) { rect in
    symbol.draw(in: rect); NSColor.white.set(); rect.fill(using: .sourceAtop); return true
}
NSGraphicsContext.saveGraphicsState()
let glyphShadow = NSShadow()
glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.25); glyphShadow.shadowBlurRadius = 18; glyphShadow.shadowOffset = NSSize(width: 0, height: -8)
glyphShadow.set()
white.draw(in: NSRect(x: (1024 - glyphSize.width) / 2, y: (1024 - glyphSize.height) / 2 + 50, width: glyphSize.width, height: glyphSize.height))
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.current?.flushGraphics()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
