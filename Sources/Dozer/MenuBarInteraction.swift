/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// Detects whether the user is currently using the menu bar, so auto-hide doesn't yank icons away mid-interaction.
enum MenuBarInteraction {
    /// Snapshot of an on-screen window, parsed defensively from `CGWindowListCopyWindowInfo`.
    struct WindowInfo: Equatable {
        let layer: Int
        let ownerPID: pid_t
        /// In global display coordinates (origin top-left of the main display).
        let bounds: CGRect

        init(layer: Int, ownerPID: pid_t, bounds: CGRect) {
            self.layer = layer
            self.ownerPID = ownerPID
            self.bounds = bounds
        }

        init?(_ info: [String: Any]) {
            guard
                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                // Dozer 4 force-cast bounds to [String: Int] and crashed whenever a window had
                // fractional coordinates, e.g. on the lock screen (upstream #186, #189, #193).
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else {
                return nil
            }
            self.init(layer: layer, ownerPID: pid, bounds: bounds)
        }
    }

    static let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
    static let popUpMenuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))

    @MainActor
    static func isUserInteracting() -> Bool {
        if isMouseInMenuBar() {
            return true
        }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let windows = list.compactMap(WindowInfo.init)
        return hasOpenStatusMenu(
            windows,
            menuBarHeight: NSStatusBar.system.thickness,
            ignoringPID: ProcessInfo.processInfo.processIdentifier
        )
    }

    @MainActor
    static func isMouseInMenuBar() -> Bool {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) else {
            return false
        }
        // Accounts for taller menu bars on notched displays.
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
        return mouse.y >= screen.frame.maxY - menuBarHeight
    }

    /// True when a menu is open, or when an app that owns a status item shows a window hanging
    /// just below the menu bar (a status item popover/panel).
    static func hasOpenStatusMenu(_ windows: [WindowInfo], menuBarHeight: CGFloat, ignoringPID: pid_t) -> Bool {
        let relevant = windows.filter { $0.ownerPID != ignoringPID }

        if relevant.contains(where: { $0.layer == popUpMenuLayer }) {
            return true
        }

        let statusItems = relevant.filter { $0.layer == statusLayer && $0.bounds.height <= menuBarHeight * 2 }
        let statusOwners = Set(statusItems.map(\.ownerPID))
        let menuBarTops = Set(statusItems.map(\.bounds.minY))

        return relevant.contains { window in
            guard window.layer != statusLayer, statusOwners.contains(window.ownerPID) else {
                return false
            }
            // Popovers start right at, or a few points below, the bottom of the menu bar.
            return menuBarTops.contains { top in
                (top + menuBarHeight - 4...top + menuBarHeight * 2 + 12).contains(window.bounds.minY)
            }
        }
    }
}
