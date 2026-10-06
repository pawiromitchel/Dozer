/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// One of Dozer's menu bar items.
///
/// Hiding works by growing an item to a huge length, which pushes every status item to its left off the
/// screen. macOS 26 doesn't draw an item that no longer fits, so the stretching is done by an invisible
/// "wall" glued to the bulldozer's left, and the bulldozer itself never stretches.
///
/// Even at zero length an item takes ~16pt of padding, so while icons are shown the wall is removed
/// from the menu bar entirely (`isVisible = false`) and comes back, re-glued, when hiding.
@MainActor
final class StatusIcon {
    enum Kind {
        /// The visible bulldozer: click it to hide/show everything to its left.
        case bulldozer
        /// Invisible item directly left of the bulldozer that stretches to hide icons; only in the menu bar
        /// while hiding.
        case wall
        /// The optional, smaller "remove" dot used with option-click.
        case remove
    }

    static let collapsedLength: CGFloat = 10_000
    /// macOS needs a moment to lay the icons back out after the wall shrinks; removing it sooner
    /// leaves them off-screen.
    private static let wallRemovalDelay: TimeInterval = 0.5

    let kind: Kind
    let item: NSStatusItem
    /// How many icons are hidden; shown as a badge on the bulldozer.
    var hiddenCount: Int? {
        didSet {
            if hiddenCount != oldValue {
                updateAppearance()
            }
        }
    }
    private(set) var isShown = true
    private let onClick: (StatusIcon, NSEvent?) -> Void

    init(kind: Kind, autosaveName: String, onClick: @escaping (StatusIcon, NSEvent?) -> Void) {
        self.kind = kind
        self.onClick = onClick
        item = NSStatusBar.system.statusItem(withLength: 0)
        // Lets macOS remember where the user dragged the icon, across relaunches and reboots.
        item.autosaveName = autosaveName
        item.behavior = []

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            // Mouse-up, not mouse-down: macOS 26 won't resize an item while it's being pressed.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imageScaling = .scaleNone
            switch kind {
            case .bulldozer: button.setAccessibilityLabel("Dozer")
            case .wall: button.setAccessibilityElement(false)
            case .remove: button.setAccessibilityLabel("Dozer secondary separator")
            }
        }
        updateAppearance()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    func show() {
        isShown = true
        updateAppearance()
        if kind == .wall {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.wallRemovalDelay) { [weak self] in
                guard let self, self.isShown else {
                    return
                }
                self.item.isVisible = false
            }
        }
    }

    /// The wall and the remove icon stretch to hide what's left of them; the bulldozer just disappears
    /// (only in "no icon" mode).
    func hide() {
        isShown = false
        if kind == .wall {
            item.isVisible = true
        }
        updateAppearance()
    }

    func toggle() {
        isShown ? hide() : show()
    }

    /// Re-applies image and length for the current state and settings.
    func updateAppearance() {
        let button = item.button
        switch kind {
        case .bulldozer:
            // Same size with or without the badge, so the bulldozer never shifts.
            let glyph = DozerGlyph.image(height: glyphHeight, count: hiddenCount)
            button?.image = isShown ? glyph : nil
            button?.setAccessibilityValue(hiddenCount.map { "\($0) hidden" })
            // Sized by macOS like any other icon.
            item.length = isShown ? NSStatusItem.variableLength : 0
        case .wall:
            button?.image = nil
            item.length = isShown ? 0 : Self.collapsedLength
        case .remove:
            button?.image = Self.dot(diameter: CGFloat(AppSettings.shared.iconSize) / 2)
            item.length = isShown ? AppSettings.shared.buttonPadding : Self.collapsedLength
        }
    }

    /// The "icon size" setting (6–16, default 10) mapped to an icon height that suits the menu bar.
    private var glyphHeight: CGFloat {
        CGFloat(AppSettings.shared.iconSize) + 6
    }

    /// Left edge of the icon on screen, or `nil` if it is not currently laid out.
    var xPosition: CGFloat? {
        guard let window = item.button?.window, window.isVisible else {
            return nil
        }
        return window.frame.minX
    }

    @objc
    private func clicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        DozerIcons.log.debug("click on \(String(describing: self.kind), privacy: .public), event: \(event.map { "\($0.type.rawValue) flags=\($0.modifierFlags.rawValue)" } ?? "nil", privacy: .public)")
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
