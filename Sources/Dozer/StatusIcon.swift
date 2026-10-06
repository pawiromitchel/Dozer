/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// One of Dozer's dots in the menu bar.
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

    static let collapsedLength: CGFloat = 10_000

    let kind: Kind
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
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.setAccessibilityLabel(kind == .remove ? "Dozer secondary separator" : "Dozer")
        }
        updateAppearance()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    var isShown: Bool { item.length < Self.collapsedLength }

    func show() {
        item.length = AppSettings.shared.buttonPadding
    }

    func hide() {
        item.length = Self.collapsedLength
    }

    func toggle() {
        isShown ? hide() : show()
    }

    /// Re-applies size settings without changing the shown/hidden state.
    func updateAppearance() {
        if isShown {
            item.length = AppSettings.shared.buttonPadding
        }
        let diameter = CGFloat(AppSettings.shared.iconSize) / (kind == .remove ? 2 : 1)
        item.button?.image = Self.dot(diameter: diameter)
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
