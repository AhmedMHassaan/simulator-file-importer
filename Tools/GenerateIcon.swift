import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let frame = NSRect(x: p * 0.06, y: p * 0.06, width: p * 0.88, height: p * 0.88)
        let background = NSBezierPath(roundedRect: frame, xRadius: p * 0.20, yRadius: p * 0.20)
        NSGradient(starting: NSColor(calibratedRed: 0.18, green: 0.57, blue: 1, alpha: 1),
                   ending: NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.80, alpha: 1))!.draw(in: background, angle: -70)
        let symbol = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil)!
        let config = NSImage.SymbolConfiguration(pointSize: p * 0.49, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        symbol.withSymbolConfiguration(config)!.draw(in: NSRect(x: p * 0.23, y: p * 0.24, width: p * 0.54, height: p * 0.52))
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
