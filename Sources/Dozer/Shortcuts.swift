/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    nonisolated(unsafe) static let toggleMenuItems = Self("toggleMenuItems")
}

enum LegacyShortcutMigration {
    /// Key Dozer 4.x (MASShortcut) stored the toggle shortcut under.
    static let legacyKey = "toggleMenuItems"

    /// Imports a shortcut recorded by Dozer 4.x, once, then removes the old value.
    @MainActor
    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: legacyKey) else {
            return
        }
        defaults.removeObject(forKey: legacyKey)

        guard KeyboardShortcuts.getShortcut(for: .toggleMenuItems) == nil,
              let (keyCode, flags) = decode(data) else {
            return
        }
        let shortcut = KeyboardShortcuts.Shortcut(
            KeyboardShortcuts.Key(rawValue: keyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: flags).intersection(.deviceIndependentFlagsMask)
        )
        KeyboardShortcuts.setShortcut(shortcut, for: .toggleMenuItems)
    }

    /// Decodes an `NSKeyedArchiver` archive of a `MASShortcut`.
    static func decode(_ data: Data) -> (keyCode: Int, modifierFlags: UInt)? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            return nil
        }
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(LegacyMASShortcut.self, forClassName: "MASShortcut")
        defer { unarchiver.finishDecoding() }
        guard let shortcut = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyMASShortcut else {
            return nil
        }
        return (shortcut.keyCode, shortcut.modifierFlags)
    }
}

/// Stand-in for MASShortcut's archived representation.
@objc(DozerLegacyMASShortcut)
final class LegacyMASShortcut: NSObject, NSCoding {
    let keyCode: Int
    let modifierFlags: UInt

    init(keyCode: Int, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    required init?(coder: NSCoder) {
        keyCode = coder.decodeInteger(forKey: "KeyCode")
        modifierFlags = UInt(truncatingIfNeeded: coder.decodeInteger(forKey: "ModifierFlags"))
    }

    func encode(with coder: NSCoder) {
        coder.encode(keyCode, forKey: "KeyCode")
        coder.encode(Int(truncatingIfNeeded: modifierFlags), forKey: "ModifierFlags")
    }
}
