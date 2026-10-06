/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// One of Dozer's menu bar items.
///
/// Hiding works by growing the item to a huge length, which pushes every status item to its left off
/// the screen. Items grow leftwards, so the bulldozer is pinned to the item's right edge: it stays put,
/// clickable, while the invisible rest of the item does the dozing.
@MainActor
final class StatusIcon {
    enum Kind {
        /// The bulldozer: everything to its left is hidden/shown on click.
        case bulldozer
        /// The optional, smaller "remove" dot used with option-click.
        case remove
    }

    static let collapsedLength: CGFloat = 10_000

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
        didSet { updateGlyphVisibility() }
    }

    private let glyphView = NSImageView()
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

            if kind == .bulldozer {
                glyphView.translatesAutoresizingMaskIntoConstraints = false
                glyphView.imageScaling = .scaleNone
                button.addSubview(glyphView)
                NSLayoutConstraint.activate([
                    glyphView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Self.glyphInset),
                    glyphView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            }
        }
        updateAppearance()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    var isShown: Bool { item.length < Self.collapsedLength }

    func show() {
        item.length = shownLength
        updateGlyphVisibility()
    }

    func hide() {
        item.length = Self.collapsedLength
        updateGlyphVisibility()
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
            let glyph = DozerGlyph.image(height: glyphHeight, count: hiddenCount)
            if glyphView.image != nil {
                // Fade the badge in and out; the icon's size never changes, so nothing jumps.
                glyphView.wantsLayer = true
                let fade = CATransition()
                fade.type = .fade
                fade.duration = 0.25
                glyphView.layer?.add(fade, forKey: "badge")
            }
            glyphView.image = glyph
            item.button?.setAccessibilityValue(hiddenCount.map { "\($0) hidden" })
        }
        if isShown {
            item.length = shownLength
        }
    }

    private func updateGlyphVisibility() {
        glyphView.isHidden = hidesGlyphWhenCollapsed && !isShown
    }

    private static let glyphInset: CGFloat = 6

    /// The "icon size" setting (6–16, default 10) mapped to an icon height that suits the menu bar.
    private var glyphHeight: CGFloat {
        CGFloat(AppSettings.shared.iconSize) + 6
    }

    private var shownLength: CGFloat {
        let padding = AppSettings.shared.buttonPadding
        guard kind == .bulldozer, let glyph = glyphView.image else {
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
        return glyphView.frame.insetBy(dx: -Self.glyphInset, dy: -button.bounds.height).contains(point)
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
