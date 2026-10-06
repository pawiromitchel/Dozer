/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// Counts the menu bar items Dozer hides.
///
/// On macOS 26 every status item is a window owned by Control Center, including other apps' items,
/// and they stay in the window list while pushed off-screen. Reading bounds needs no permissions.
enum HiddenItems {
    /// Number of status items left of the separator, on the separator's menu bar.
    ///
    /// - Parameters:
    ///   - separator: The separator's frame, in global display coordinates (origin top-left).
    ///   - excluding: Frames of Dozer's own items, which are not counted.
    static func count(in items: [CGRect], leftOf separator: CGRect, excluding: [CGRect] = []) -> Int {
        items.filter { item in
            abs(item.minY - separator.minY) < 1
                && item.maxX <= separator.minX + 1
                && !excluding.contains { abs($0.minX - item.minX) < 1 && abs($0.width - item.width) < 1 }
        }.count
    }

    @MainActor
    static func count(leftOf separator: StatusIcon, excluding: [StatusIcon]) -> Int? {
        guard let separatorFrame = separator.globalFrame,
              let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let statusItems = list
            .compactMap(MenuBarInteraction.WindowInfo.init)
            .filter { $0.layer == MenuBarInteraction.statusLayer }
            .map(\.bounds)
        return count(in: statusItems, leftOf: separatorFrame, excluding: excluding.compactMap(\.globalFrame))
    }
}

extension StatusIcon {
    /// The item's frame in global display coordinates (origin top-left of the main display), as `CGWindowList` reports it.
    var globalFrame: CGRect? {
        guard let frame = item.button?.window?.frame, let mainHeight = NSScreen.screens.first?.frame.maxY else {
            return nil
        }
        return CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
