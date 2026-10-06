/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// Dozer's menu bar glyph: a one-color bulldozer traced from the app icon, drawn as a template image
/// so it follows the menu bar's light/dark appearance.
enum DozerGlyph {
    /// The app icon's bulldozer spans this box (in its 1024px artwork); the glyph is drawn in those units.
    private static let artBox = CGRect(x: 150, y: 262, width: 732, height: 515)

    static func image(height: CGFloat) -> NSImage {
        let scale = height / artBox.height
        let size = NSSize(width: ceil(artBox.width * scale), height: height)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current else {
                return false
            }
            let transform = NSAffineTransform()
            transform.scale(by: scale)
            transform.translateX(by: -artBox.minX, yBy: -artBox.minY)
            transform.concat()
            draw(in: context)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Dozer"
        return image
    }

    /// A number followed by the glyph, e.g. "3 🚜" for three hidden icons (they sit to its left).
    static func image(height: CGFloat, count: Int) -> NSImage {
        let glyph = image(height: height)
        let text = count > 99 ? "99+" : String(count)
        let font = NSFont.monospacedDigitSystemFont(ofSize: height * 0.85, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let spacing = round(height * 0.25)
        let textWidth = ceil(textSize.width)
        let size = NSSize(width: textWidth + spacing + glyph.size.width, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            (text as NSString).draw(at: NSPoint(x: 0, y: rect.midY - textSize.height / 2), withAttributes: attributes)
            glyph.draw(in: NSRect(origin: NSPoint(x: textWidth + spacing, y: 0), size: glyph.size))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Dozer, \(count) hidden"
        return image
    }

    private static func draw(in context: NSGraphicsContext) {
        NSColor.black.setFill()

        // Cab, body and engine hood with exhaust.
        NSBezierPath(roundedRect: NSRect(x: 220, y: 262, width: 252, height: 230), xRadius: 34, yRadius: 34).fill()
        NSBezierPath(roundedRect: NSRect(x: 170, y: 445, width: 528, height: 200), xRadius: 56, yRadius: 56).fill()
        NSBezierPath(roundedRect: NSRect(x: 470, y: 443, width: 228, height: 120), xRadius: 30, yRadius: 30).fill()
        NSRect(x: 562, y: 372, width: 40, height: 80).fill()

        // Blade and the arm holding it.
        let blade = NSBezierPath()
        blade.move(to: NSPoint(x: 732, y: 443))
        blade.line(to: NSPoint(x: 768, y: 443))
        blade.curve(to: NSPoint(x: 882, y: 722), controlPoint1: NSPoint(x: 772, y: 600), controlPoint2: NSPoint(x: 800, y: 712))
        blade.line(to: NSPoint(x: 882, y: 777))
        blade.line(to: NSPoint(x: 732, y: 777))
        blade.close()
        blade.fill()
        NSRect(x: 660, y: 640, width: 80, height: 34).fill()

        // Knock-outs: window, and a gap separating the track from the body.
        context.compositingOperation = .destinationOut
        NSBezierPath(rect: NSRect(x: 280, y: 322, width: 150, height: 112)).fill()
        let trackRect = NSRect(x: 152, y: 557, width: 513, height: 220)
        NSBezierPath(roundedRect: trackRect.insetBy(dx: -22, dy: -22), xRadius: 132, yRadius: 132).fill()

        // Track with its wheels knocked out.
        context.compositingOperation = .sourceOver
        NSBezierPath(roundedRect: trackRect, xRadius: 110, yRadius: 110).fill()
        context.compositingOperation = .destinationOut
        for x in [262.0, 360, 458, 556] {
            NSBezierPath(ovalIn: NSRect(x: x - 30, y: 637, width: 60, height: 60)).fill()
        }
        context.compositingOperation = .sourceOver
    }
}
