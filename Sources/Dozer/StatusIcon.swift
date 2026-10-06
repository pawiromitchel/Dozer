/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// One of Dozer's menu bar items.
///
/// Hiding works by growing the item to a huge length, which pushes every
/// status item to its left off the screen.
@MainActor
final class StatusIcon {
    enum Kind {
        /// The regular dots. The leftmost one is the separator; the other one is a click target.
        case normal
        /// The optional, smaller "remove" dot used with option-click.
        case remove
    }

    enum Style: Equatable {
        /// The clickable Dozer glyph.
        case dot
        /// The glyph followed by how many icons are hidden.
        case badge(Int)
        /// A faint line marking where hidden icons start; only visible while icons are shown.
        case divider
    }

    static let collapsedLength: CGFloat = 10_000
    private static let dividerLength: CGFloat = 12

    let kind: Kind
    var style: Style = .dot {
        didSet {
            if style != oldValue {
                updateAppearance()
            }
        }
    }
    let item: NSStatusItem
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
            // Mouse-up, not mouse-down: macOS 26 won't resize an item while it's being pressed,
            // so clicking the separator itself failed to collapse it.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(kind == .remove ? "Dozer secondary separator" : "Dozer")
        }
        updateAppearance()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    var isShown: Bool { item.length < Self.collapsedLength }

    func show() {
        item.length = shownLength
    }

    func hide() {
        item.length = Self.collapsedLength
    }

    func toggle() {
        isShown ? hide() : show()
    }

    /// Re-applies style and size settings without changing the shown/hidden state.
    func updateAppearance() {
        let image = self.image
        item.button?.image = image
        item.button?.setAccessibilityValue(style == .divider ? nil : badgeAccessibilityValue)
        if isShown {
            item.length = shownLength
        }
    }

    private var image: NSImage {
        let size = CGFloat(AppSettings.shared.iconSize)
        switch (kind, style) {
        case (.remove, _):
            return Self.dot(diameter: size / 2)
        case (_, .divider):
            return Self.divider(height: max(size + 4, 12))
        case (_, .badge(let count)) where count > 0:
            return DozerGlyph.image(height: glyphHeight, count: count)
        default:
            return DozerGlyph.image(height: glyphHeight)
        }
    }

    /// The "icon size" setting (6–16, default 10) mapped to a glyph height that suits the menu bar.
    private var glyphHeight: CGFloat {
        CGFloat(AppSettings.shared.iconSize) + 4
    }

    private var shownLength: CGFloat {
        let padding = AppSettings.shared.buttonPadding
        if style == .divider, kind == .normal {
            return Self.dividerLength
        }
        // Wide badges ("12") need more room than the configured spacing.
        return max(padding, (item.button?.image?.size.width ?? 0) + 10)
    }

    private var badgeAccessibilityValue: String? {
        if case .badge(let count) = style, count > 0 {
            return "\(count) hidden"
        }
        return nil
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
        DozerIcons.log.debug("click on \(self.kind == .remove ? "remove" : "normal", privacy: .public) icon, event: \(event.map { "\($0.type.rawValue) flags=\($0.modifierFlags.rawValue)" } ?? "nil", privacy: .public)")
        onClick(self, event)
    }

    static func divider(height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: 2, height: height), flipped: false) { rect in
            NSColor.black.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        return image
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
