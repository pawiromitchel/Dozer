import Cocoa
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Dozer

/// Renders the README demo (Stuff/demo.gif) with Dozer's real glyph and divider drawing code.
///   make demo-gif
@MainActor
struct DemoGIF {
    // Canvas in points; rendered at 2x for Retina READMEs.
    static let size = CGSize(width: 720, height: 112)
    static let scale: CGFloat = 2
    static let barHeight: CGFloat = 26
    static let fps: Double = 25
    static let duration: Double = 9

    struct Item {
        let id: String
        let symbol: String?
        var width: CGFloat = 30
    }

    // Right to left, as the menu bar lays them out.
    static let fixedRight: [Item] = [
        Item(id: "clock", symbol: nil, width: 112),
        Item(id: "battery", symbol: "battery.75percent", width: 34),
        Item(id: "wifi", symbol: "wifi"),
        Item(id: "search", symbol: "magnifyingglass"),
        Item(id: "control", symbol: "switch.2")
    ]
    static let hideable: [Item] = [
        Item(id: "music", symbol: "music.note"),
        Item(id: "cloud", symbol: "icloud"),
        Item(id: "bolt", symbol: "bolt.horizontal"),
        Item(id: "drive", symbol: "externaldrive")
    ]
    static let dragged = Item(id: "cup", symbol: "cup.and.saucer")

    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOZER_DEMO_GIF"] != nil))
    func render() throws {
        let path = try #require(ProcessInfo.processInfo.environment["DOZER_DEMO_GIF"])
        let frameCount = Int(Self.duration * Self.fps)
        let url = URL(fileURLWithPath: path) as CFURL
        let destination = try #require(CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, frameCount, nil))
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / Self.fps]
        ] as CFDictionary
        for index in 0..<frameCount {
            let image = try #require(frame(at: Double(index) / Self.fps))
            CGImageDestinationAddImage(destination, image, frameProperties)
        }
        #expect(CGImageDestinationFinalize(destination))
    }

    // MARK: Timeline

    /// 0–1 progress of `t` through [start, end], eased.
    func progress(_ t: Double, _ start: Double, _ end: Double) -> CGFloat {
        let p = min(max((t - start) / (end - start), 0), 1)
        return CGFloat(p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2)
    }

    func mix(_ a: CGPoint, _ b: CGPoint, _ p: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p)
    }

    // MARK: Drawing

    func frame(at t: Double) -> CGImage? {
        let pixels = CGSize(width: Self.size.width * Self.scale, height: Self.size.height * Self.scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            return nil
        }
        rep.size = Self.size
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let bitmapContext = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        // Work in a top-left origin like the screen; a flipped context keeps images and text upright.
        let cgContext = bitmapContext.cgContext
        cgContext.translateBy(x: 0, y: Self.size.height)
        cgContext.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: true)

        drawWallpaper()
        drawMenuBar(at: t)
        return rep.cgImage
    }

    func drawWallpaper() {
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.20, green: 0.33, blue: 0.58, alpha: 1),
            NSColor(calibratedRed: 0.36, green: 0.28, blue: 0.55, alpha: 1)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: Self.size), angle: 90)
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSRect(x: 0, y: 0, width: Self.size.width, height: Self.barHeight).fill()
    }

    func drawMenuBar(at t: Double) {
        // Story beats (seconds).
        let dragStart = 1.0, dragEnd = 2.4
        let hideClick = 3.6, hideEnd = 3.95
        let showClick = 6.2, showEnd = 6.55

        // App menus on the left.
        drawSymbol("apple.logo", centeredAt: CGPoint(x: 20, y: Self.barHeight / 2), pointSize: 14)
        var x: CGFloat = 40
        for (index, title) in ["Finder", "File", "Edit", "View"].enumerated() {
            let font = NSFont.systemFont(ofSize: 13, weight: index == 0 ? .bold : .regular)
            x += drawText(title, at: CGPoint(x: x, y: Self.barHeight / 2), font: font) + 18
        }

        // Status items, laid out right to left.
        var right = Self.size.width - 8
        var positions: [String: CGFloat] = [:]
        func place(_ item: Item) {
            positions[item.id] = right - item.width / 2
            right -= item.width
        }
        Self.fixedRight.forEach(place)

        let dragProgress = progress(t, dragStart, dragEnd)
        // The cup starts right of Dozer and ends up among the hidden icons.
        let cupStart = right - Self.dragged.width / 2
        if t < dragStart + (dragEnd - dragStart) / 2 {
            place(Self.dragged)
        }
        let glyphWidth = DozerGlyph.image(height: 14).size.width + 12
        positions["dozer"] = right - glyphWidth / 2
        right -= glyphWidth
        positions["divider"] = right - 6
        let dividerX = right - 6
        right -= 12
        if t >= dragStart + (dragEnd - dragStart) / 2 {
            place(Self.dragged)
        }
        Self.hideable.forEach(place)
        let cupEnd = positions[Self.dragged.id] ?? cupStart

        // Hide/show animation: hidden icons slide left and fade.
        let hideProgress = progress(t, hideClick, hideEnd) * (1 - progress(t, showClick, showEnd))
        let hiddenIDs = Set(Self.hideable.map(\.id) + [Self.dragged.id])
        let isHidden = t >= hideEnd && t < showClick

        let cupX: CGFloat
        if t < dragStart || t >= dragEnd {
            cupX = t < dragStart ? cupStart : cupEnd
        } else {
            cupX = cupStart + (cupEnd - cupStart) * dragProgress
        }

        for item in Self.hideable + [Self.dragged] {
            guard var center = positions[item.id], let symbol = item.symbol else {
                continue
            }
            if item.id == Self.dragged.id {
                center = cupX
            }
            let alpha = hiddenIDs.contains(item.id) && t >= dragEnd ? 1 - hideProgress : 1
            let lifted = item.id == Self.dragged.id && t >= dragStart && t < dragEnd ? 1.0 : 0.0
            drawSymbol(symbol, centeredAt: CGPoint(x: center - 26 * hideProgress, y: Self.barHeight / 2 - lifted),
                       pointSize: 14, alpha: alpha * (lifted > 0 ? 0.75 : 1))
        }

        // Divider (visible only while shown) and the Dozer glyph with its count.
        drawImage(StatusIcon.divider(height: 14), centeredAt: CGPoint(x: dividerX, y: Self.barHeight / 2), alpha: 1 - hideProgress)
        let glyph = isHidden ? DozerGlyph.image(height: 14, count: Self.hideable.count + 1) : DozerGlyph.image(height: 14)
        let dozerCenter = positions["dozer"] ?? 0
        let glyphRight = dozerCenter + DozerGlyph.image(height: 14).size.width / 2
        drawImage(glyph, at: CGPoint(x: glyphRight - glyph.size.width, y: Self.barHeight / 2 - 7))

        // Fixed items.
        for item in Self.fixedRight {
            guard let center = positions[item.id] else {
                continue
            }
            if let symbol = item.symbol {
                drawSymbol(symbol, centeredAt: CGPoint(x: center, y: Self.barHeight / 2), pointSize: 14)
            } else {
                let width = drawText("Tue 6 Oct  11:42", at: .zero, font: .systemFont(ofSize: 13), measureOnly: true)
                _ = drawText("Tue 6 Oct  11:42", at: CGPoint(x: center - width / 2, y: Self.barHeight / 2), font: .systemFont(ofSize: 13))
            }
        }

        // Cursor path and captions.
        let idle = CGPoint(x: cupStart + 30, y: 70)
        let onCup = CGPoint(x: cupStart, y: Self.barHeight / 2)
        let onCupEnd = CGPoint(x: cupEnd, y: Self.barHeight / 2)
        let onDozer = CGPoint(x: dozerCenter, y: Self.barHeight / 2 + 2)
        let cursor: CGPoint
        switch t {
        case ..<0.4: cursor = idle
        case ..<dragStart: cursor = mix(idle, onCup, progress(t, 0.4, dragStart))
        case ..<dragEnd: cursor = CGPoint(x: cupX, y: onCupEnd.y)
        case ..<(hideClick - 0.1): cursor = mix(onCupEnd, onDozer, progress(t, dragEnd + 0.2, hideClick - 0.1))
        case ..<(showClick + 0.6): cursor = onDozer
        default: cursor = mix(onDozer, idle, progress(t, showClick + 0.6, Self.duration - 0.6))
        }
        for click in [hideClick, showClick] where t >= click && t < click + 0.35 {
            let p = CGFloat((t - click) / 0.35)
            NSColor.white.withAlphaComponent(0.5 * (1 - p)).setStroke()
            let radius = 6 + 10 * p
            let ring = NSBezierPath(ovalIn: NSRect(x: cursor.x - radius, y: cursor.y - radius, width: radius * 2, height: radius * 2))
            ring.lineWidth = 2
            ring.stroke()
        }
        drawCursor(at: cursor)

        let caption: String?
        switch t {
        case 0.6..<(dragEnd + 0.5): caption = "⌘ + drag icons left of the line"
        case (hideClick - 0.3)..<(showClick - 0.4): caption = isHidden || t < hideEnd ? "Click to hide — Dozer counts them" : nil
        case (showClick - 0.3)..<(showClick + 1.4): caption = "Click to show"
        default: caption = nil
        }
        if let caption {
            drawCaption(caption)
        }
    }

    func drawCaption(_ text: String) {
        let font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let width = drawText(text, at: .zero, font: font, measureOnly: true)
        let rect = NSRect(x: (Self.size.width - width) / 2 - 16, y: 58, width: width + 32, height: 34)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
        _ = drawText(text, at: CGPoint(x: rect.minX + 16, y: rect.midY), font: font)
    }

    /// A classic macOS arrow (NSCursor's image doesn't render headlessly), tip at `point`.
    func drawCursor(at point: CGPoint) {
        let shape: [CGPoint] = [(0, 0), (0, 16), (4, 12.5), (6.8, 18.6), (9.2, 17.6), (6.5, 11.6), (11.6, 11.6)]
            .map { CGPoint(x: point.x + $0.0, y: point.y + $0.1) }
        let path = NSBezierPath()
        path.move(to: shape[0])
        shape.dropFirst().forEach { path.line(to: $0) }
        path.close()
        path.lineJoinStyle = .round
        path.lineWidth = 1.6
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.set()
        NSColor.white.setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.black.setFill()
        path.fill()
    }

    /// Draws white text vertically centered on `point.y`; returns its width.
    @discardableResult
    func drawText(_ text: String, at point: CGPoint, font: NSFont, measureOnly: Bool = false) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attributes)
        if !measureOnly {
            (text as NSString).draw(at: CGPoint(x: point.x, y: point.y - size.height / 2), withAttributes: attributes)
        }
        return size.width
    }

    func drawSymbol(_ name: String, centeredAt point: CGPoint, pointSize: CGFloat, alpha: CGFloat = 1) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return
        }
        drawImage(symbol, centeredAt: point, alpha: alpha)
    }

    func drawImage(_ image: NSImage, centeredAt point: CGPoint, alpha: CGFloat = 1) {
        drawImage(image, at: CGPoint(x: point.x - image.size.width / 2, y: point.y - image.size.height / 2), alpha: alpha)
    }

    /// Draws a template image tinted white, like the menu bar does on a dark wallpaper.
    func drawImage(_ image: NSImage, at origin: CGPoint, alpha: CGFloat = 1) {
        guard alpha > 0.01 else {
            return
        }
        let tinted = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: NSRect(origin: origin, size: image.size), from: .zero, operation: .sourceOver,
                    fraction: alpha, respectFlipped: true, hints: nil)
    }
}
