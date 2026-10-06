/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
import Combine

/// User settings, persisted in `UserDefaults`.
///
/// Key names are kept identical to Dozer 4.x so existing preferences carry over.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Key {
        static let hideAtLaunch = "hideAtLaunchEnabled"
        static let hideAfterDelayEnabled = "hideAfterDelayEnabled"
        static let hideAfterDelay = "hideAfterDelay"
        static let noIconMode = "noIconMode"
        static let removeIconEnabled = "removeStatusIconEnabled"
        static let showIconAndMenu = "showIconAndMenuEnabled"
        static let iconSize = "fontSize"
        static let buttonPadding = "buttonPadding"
        static let automaticallyCheckForUpdates = "automaticallyCheckForUpdates"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    static let hideAfterDelayChoices: [TimeInterval] = [5, 10, 15, 30, 60, 120, 300]
    static let iconSizeChoices: [Int] = [6, 8, 10, 12, 14, 16]
    static let buttonPaddingChoices: [CGFloat] = [10, 15, 20, 25, 30, 35]

    private let defaults: UserDefaults

    @Published var hideAtLaunch: Bool { didSet { defaults.set(hideAtLaunch, forKey: Key.hideAtLaunch) } }
    @Published var hideAfterDelayEnabled: Bool { didSet { defaults.set(hideAfterDelayEnabled, forKey: Key.hideAfterDelayEnabled) } }
    @Published var hideAfterDelay: TimeInterval { didSet { defaults.set(hideAfterDelay, forKey: Key.hideAfterDelay) } }
    @Published var noIconMode: Bool { didSet { defaults.set(noIconMode, forKey: Key.noIconMode) } }
    @Published var removeIconEnabled: Bool { didSet { defaults.set(removeIconEnabled, forKey: Key.removeIconEnabled) } }
    @Published var showIconAndMenu: Bool { didSet { defaults.set(showIconAndMenu, forKey: Key.showIconAndMenu) } }
    @Published var iconSize: Int { didSet { defaults.set(iconSize, forKey: Key.iconSize) } }
    @Published var buttonPadding: CGFloat { didSet { defaults.set(Double(buttonPadding), forKey: Key.buttonPadding) } }
    @Published var automaticallyCheckForUpdates: Bool {
        didSet { defaults.set(automaticallyCheckForUpdates, forKey: Key.automaticallyCheckForUpdates) }
    }

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hideAtLaunch = defaults.bool(forKey: Key.hideAtLaunch)
        hideAfterDelayEnabled = defaults.bool(forKey: Key.hideAfterDelayEnabled)
        hideAfterDelay = Self.number(defaults.object(forKey: Key.hideAfterDelay)) ?? 10
        noIconMode = defaults.bool(forKey: Key.noIconMode)
        removeIconEnabled = defaults.bool(forKey: Key.removeIconEnabled)
        showIconAndMenu = defaults.bool(forKey: Key.showIconAndMenu)
        iconSize = Self.number(defaults.object(forKey: Key.iconSize)).map { Int($0) } ?? 10
        buttonPadding = Self.number(defaults.object(forKey: Key.buttonPadding)).map { CGFloat($0) } ?? 25
        automaticallyCheckForUpdates = defaults.object(forKey: Key.automaticallyCheckForUpdates) as? Bool ?? true
    }

    /// Reads a number stored either natively or as a JSON string (how older `Defaults` versions stored some types).
    nonisolated static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            let trimmed = string.trimmingCharacters(in: CharacterSet(charactersIn: "[] \""))
            return Double(trimmed)
        default:
            return nil
        }
    }
}

enum AppInfo {
    static let repository = "pawiromitchel/Dozer"
    static var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "com.mortennn.Dozer" }
    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
    static var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" }
}
