/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.mainMenu = makeMainMenu()
        LegacyShortcutMigration.migrateIfNeeded()

        let icons = DozerIcons.shared
        icons.onMenuRequested = { [weak self] icon in
            self?.showContextMenu(for: icon)
        }
        icons.start()
        icons.showOnboardingIfNeeded()
        icons.hideAtLaunch()

        UpdateChecker.checkInBackgroundIfDue()
    }

    /// Opening Dozer again (from Finder, Spotlight, …) reveals all icons and the settings.
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        DozerIcons.shared.showAll()
        SettingsWindowController.shared.present()
        return false
    }

    /// Automation hooks: `open dozer://toggle` (also `show`, `hide`, `show-all`, `settings`).
    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "dozer" {
            let icons = DozerIcons.shared
            switch url.host {
            case "toggle": icons.toggle()
            case "show": icons.show()
            case "hide": icons.hide()
            case "show-all": icons.showAll()
            case "settings": SettingsWindowController.shared.present()
            default: NSSound.beep()
            }
        }
    }

    // MARK: Menus

    private func showContextMenu(for icon: StatusIcon) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show All Icons", action: #selector(showAllIcons), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Dozer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        guard let button = icon.item.button else {
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Dozer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Dozer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Dozer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        return main
    }

    @objc
    private func openSettings() {
        SettingsWindowController.shared.present()
    }

    @objc
    private func showAllIcons() {
        DozerIcons.shared.showAll()
    }

    @objc
    private func checkForUpdates() {
        UpdateChecker.checkInteractively()
    }
}
