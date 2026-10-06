/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import SwiftUI
@preconcurrency import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var settings: AppSettings = .shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var hasShortcut = DozerIcons.shared.isShortcutSet

    var body: some View {
        Form {
            Section {
                Toggle("Hide icons when Dozer launches", isOn: $settings.hideAtLaunch)
                Toggle("Hide icons automatically", isOn: $settings.hideAfterDelayEnabled)
                Picker("Hide after", selection: $settings.hideAfterDelay) {
                    ForEach(Self.delayChoices, id: \.self) { seconds in
                        Text(Self.format(seconds: seconds)).tag(seconds)
                    }
                }
                .disabled(!settings.hideAfterDelayEnabled)
            } header: {
                Text("Behavior")
            } footer: {
                Text("Auto-hide waits while your pointer is in the menu bar or a menu is open.")
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Show/hide icons", name: .toggleMenuItems) { _ in
                    hasShortcut = DozerIcons.shared.isShortcutSet
                    DozerIcons.shared.shortcutDidChange()
                }
                Toggle("Hide the Dozer icons too (shortcut only)", isOn: $settings.noIconMode)
                    .disabled(!hasShortcut)
            }

            Section {
                Toggle("Enable the “remove” icon (option-click)", isOn: $settings.removeIconEnabled)
                Toggle("Show Dozer’s menu while icons are shown", isOn: $settings.showIconAndMenu)
                Picker("Icon size", selection: $settings.iconSize) {
                    ForEach(Self.iconSizeChoices, id: \.self) { Text("\($0) px").tag($0) }
                }
                Picker("Icon spacing", selection: $settings.buttonPadding) {
                    ForEach(Self.paddingChoices, id: \.self) { Text("\(Int($0)) px").tag($0) }
                }
            } header: {
                Text("Icons")
            } footer: {
                Text("⌘-drag menu bar icons to arrange them. Everything left of the left dot hides on click; everything left of the small “remove” dot hides until you option-click. Showing Dozer’s menu replaces the current app’s menu to free up room.")
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            try LaunchAtLogin.set(enabled: enabled)
                            launchAtLoginError = nil
                        } catch {
                            launchAtLoginError = error.localizedDescription
                        }
                        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Automatically check for updates", isOn: $settings.automaticallyCheckForUpdates)
            }

            Section {
                HStack {
                    Text("Dozer \(AppInfo.version) (\(AppInfo.build))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check for Updates…") { UpdateChecker.checkInteractively() }
                    Button("Quit Dozer") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Includes the current value so custom values (set via `defaults write`) still show up.
    private static var delayChoices: [TimeInterval] {
        Array(Set(AppSettings.hideAfterDelayChoices + [AppSettings.shared.hideAfterDelay])).sorted()
    }

    private static var iconSizeChoices: [Int] {
        Array(Set(AppSettings.iconSizeChoices + [AppSettings.shared.iconSize])).sorted()
    }

    private static var paddingChoices: [CGFloat] {
        Array(Set(AppSettings.buttonPaddingChoices + [AppSettings.shared.buttonPadding])).sorted()
    }

    private static func format(seconds: TimeInterval) -> String {
        seconds < 60 ? "\(Int(seconds)) seconds" : "\(Int(seconds / 60)) minute\(seconds >= 120 ? "s" : "")"
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = "Dozer Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView())
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        // Recreate the view so values changed elsewhere (e.g. launch at login in System Settings) are fresh.
        window?.contentViewController = NSHostingController(rootView: SettingsView())
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
