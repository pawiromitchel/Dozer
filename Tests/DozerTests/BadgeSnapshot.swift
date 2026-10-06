import Cocoa
import Testing
@testable import Dozer

@MainActor
struct BadgeSnapshot {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOZER_SNAPSHOT"] != nil))
    func menuBarPreview() throws {
        let path = try #require(ProcessInfo.processInfo.environment["DOZER_SNAPSHOT"])
        let images: [NSImage] = [DozerGlyph.image(height: 16),
                                 DozerGlyph.image(height: 16, count: 3), DozerGlyph.image(height: 16, count: 12)]
        let scale: CGFloat = 4
        let size = NSSize(width: 200 * scale, height: 33 * scale)
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(calibratedRed: 0.22, green: 0.42, blue: 0.62, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        var x: CGFloat = 20
        for image in images {
            // Template images render white on a dark menu bar.
            let tinted = NSImage(size: image.size, flipped: false) { rect in
                image.draw(in: rect)
                NSColor.white.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            let s = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            tinted.draw(in: NSRect(x: x * scale, y: (size.height - s.height) / 2, width: s.width, height: s.height))
            x += image.size.width + 30
        }
        NSGraphicsContext.restoreGraphicsState()
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
    }
}
