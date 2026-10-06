/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// One of Dozer's menu bar items.
///
/// Hiding works by growing the item to a huge length, which pushes every status item to its left off
/// the screen. Items grow leftwards, so the bulldozer is drawn at the item's right edge: it stays put,
/// clickable, while the invisible rest of the item does the dozing.
///
/// On macOS 26 the system draws status items itself and only shows the button's image (not subviews),
/// so while stretched the image is as wide as the button, with the bulldozer at its right end.
@MainActor
final class StatusIcon {
    enum Kind {
        /// The bulldozer: everything to its left is hidden/shown on click.
        case bulldozer
        /// The optional, smaller "remove" dot used with option-click.
        case remove
    }

    /// Used when the item's position is unknown, and for the invisible "remove" icon.
    static let fallbackCollapsedLength: CGFloat = 10_000

    let kind: Kind
    let item: NSStatusItem
    /// How many icons are hidden; shown next to the bulldozer while collapsed.
    var hiddenCount: Int? {
        didSet {
            if hiddenCount != oldValue {
                updateAppearance()
            }
        }
    }
    /// Hides the bulldozer glyph itself while collapsed ("no icon" mode, shortcut only).
    var hidesGlyphWhenCollapsed = false {
        didSet { renderButtonImage() }
    }

    private var glyph: NSImage?
    private var frameObserver: NSObjectProtocol?
    private let onClick: (StatusIcon, NSEvent?) -> Void

    init(kind: Kind, autosaveName: String, onClick: @escaping (StatusIcon, NSEvent?) -> Void) {
        self.kind = kind
        self.onClick = onClick
        item = NSStatusBar.system.statusItem(withLength: AppSettings.shared.buttonPadding)
        // Lets macOS remember where the user dragged the icon, across relaunches and reboots.
        item.autosaveName = autosaveName
        item.behavior = []

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            // Mouse-up, not mouse-down: macOS 26 won't resize an item while it's being pressed.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(kind == .remove ? "Dozer secondary separator" : "Dozer")
            // A stretched item would otherwise highlight across the whole menu bar when clicked.
            (button.cell as? NSButtonCell)?.highlightsBy = []

            button.imageScaling = .scaleNone

            if kind == .bulldozer {
                // Re-render once macOS has applied a new length, so the bulldozer lands on the right edge.
                button.postsFrameChangedNotifications = true
                frameObserver = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification, object: button, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.renderButtonImage() }
                }
            }
        }
        updateAppearance()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    private(set) var isShown = true

    func show() {
        isShown = true
        item.length = shownLength
        renderButtonImage()
    }

    func hide() {
        let length = collapsedLength
        isShown = false
        item.length = length
        renderButtonImage()
    }

    /// Just long enough to push everything left of the item past the screen's left edge.
    ///
    /// Not a fixed 10,000pt: macOS caps that around 5,000pt, and at 2x that's wider than the system
    /// will draw, so the bulldozer drawn on a stretched item disappeared.
    private var collapsedLength: CGFloat {
        guard kind == .bulldozer, let window = item.button?.window, let screen = window.screen ?? NSScreen.main else {
            return Self.fallbackCollapsedLength
        }
        // The right edge doesn't move while the item grows, so this also works when already collapsed.
        return ceil(window.frame.maxX - screen.frame.minX + 8)
    }

    func toggle() {
        isShown ? hide() : show()
    }

    /// Re-applies style and size settings without changing the shown/hidden state.
    func updateAppearance() {
        switch kind {
        case .remove:
            item.button?.image = Self.dot(diameter: CGFloat(AppSettings.shared.iconSize) / 2)
        case .bulldozer:
            // Same size with or without the badge, so the bulldozer never shifts.
            glyph = DozerGlyph.image(height: glyphHeight, count: hiddenCount)
            item.button?.setAccessibilityValue(hiddenCount.map { "\($0) hidden" })
        }
        if isShown {
            item.length = shownLength
        }
        renderButtonImage()
    }

    /// Shown: just the bulldozer. Stretched: a transparent image as wide as the button with the bulldozer
    /// at its right end (the button centers its image, so this puts the bulldozer on the right edge).
    private func renderButtonImage() {
        guard kind == .bulldozer, let glyph, let button = item.button else {
            return
        }
        if isShown {
            button.image = glyph
            return
        }
        if hidesGlyphWhenCollapsed {
            button.image = nil
            return
        }
        let width = max(button.bounds.width, glyph.size.width)
        let canvas = NSImage(size: NSSize(width: width, height: glyph.size.height), flipped: false) { rect in
            glyph.draw(in: NSRect(x: rect.maxX - glyph.size.width - Self.glyphInset, y: 0,
                                  width: glyph.size.width, height: glyph.size.height))
            return true
        }
        canvas.isTemplate = true
        button.image = canvas
        DozerIcons.log.debug("stretched image: button width \(Int(button.bounds.width)), window \(Int(button.window?.frame.width ?? 0))")
    }

    private static let glyphInset: CGFloat = 6

    /// The "icon size" setting (6–16, default 10) mapped to an icon height that suits the menu bar.
    private var glyphHeight: CGFloat {
        CGFloat(AppSettings.shared.iconSize) + 6
    }

    private var shownLength: CGFloat {
        let padding = AppSettings.shared.buttonPadding
        guard kind == .bulldozer, let glyph else {
            return padding
        }
        return max(padding, glyph.size.width + Self.glyphInset * 2)
    }

    /// Left edge of the icon on screen, or `nil` if it is not currently laid out.
    var xPosition: CGFloat? {
        guard let window = item.button?.window, window.isVisible else {
            return nil
        }
        return window.frame.minX
    }

    /// While collapsed, the item spans the empty menu bar to the bulldozer's left; only clicks on
    /// the bulldozer itself count.
    private func isOnGlyph(_ event: NSEvent?) -> Bool {
        guard kind == .bulldozer, !isShown, let event, let button = item.button,
              event.window === button.window else {
            return true
        }
        let point = button.convert(event.locationInWindow, from: nil)
        let glyphWidth = glyph?.size.width ?? 0
        return point.x >= button.bounds.maxX - glyphWidth - Self.glyphInset * 2
    }

    @objc
    private func clicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let onGlyph = isOnGlyph(event)
        DozerIcons.log.debug("click on \(self.kind == .remove ? "remove" : "bulldozer", privacy: .public), event: \(event.map { "\($0.type.rawValue) flags=\($0.modifierFlags.rawValue)" } ?? "nil", privacy: .public) onGlyph=\(onGlyph)")
        guard onGlyph else {
            return
        }
        onClick(self, event)
    }

    /// Each icon gets its own image instance; sharing one let the remove icon resize the normal icons.
    static func dot(diameter: CGFloat) -> NSImage {
        let size = max(diameter, 2)
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
