import Cocoa
import Testing
@testable import Dozer

struct WindowInfoTests {
    @Test func parsesFractionalBounds() throws {
        // Dozer 4 crashed here: it force-cast bounds to [String: Int].
        let info: [String: Any] = [
            kCGWindowLayer as String: NSNumber(value: 25),
            kCGWindowOwnerPID as String: NSNumber(value: 42),
            kCGWindowBounds as String: ["X": 10.5, "Y": 0, "Width": 24.25, "Height": 37.0] as NSDictionary
        ]
        let window = try #require(MenuBarInteraction.WindowInfo(info))
        #expect(window.bounds == CGRect(x: 10.5, y: 0, width: 24.25, height: 37))
        #expect(window.ownerPID == 42)
    }

    @Test func rejectsMalformedInfo() {
        #expect(MenuBarInteraction.WindowInfo([:]) == nil)
        #expect(MenuBarInteraction.WindowInfo([kCGWindowLayer as String: "nope"]) == nil)
    }
}

struct MenuDetectionTests {
    typealias Window = MenuBarInteraction.WindowInfo
    let status = MenuBarInteraction.statusLayer

    @Test func detectsOpenPopUpMenu() {
        let windows = [Window(layer: MenuBarInteraction.popUpMenuLayer, ownerPID: 7, bounds: CGRect(x: 0, y: 30, width: 200, height: 300))]
        #expect(MenuBarInteraction.hasOpenStatusMenu(windows, menuBarHeight: 24, ignoringPID: 1))
    }

    @Test func ignoresOwnWindows() {
        let windows = [Window(layer: MenuBarInteraction.popUpMenuLayer, ownerPID: 1, bounds: .zero)]
        #expect(!MenuBarInteraction.hasOpenStatusMenu(windows, menuBarHeight: 24, ignoringPID: 1))
    }

    @Test func detectsStatusItemPopoverOnNotchedDisplay() {
        let windows = [
            Window(layer: status, ownerPID: 9, bounds: CGRect(x: 1200, y: 0, width: 30, height: 37)),
            Window(layer: 0, ownerPID: 9, bounds: CGRect(x: 1100, y: 40, width: 300, height: 400))
        ]
        #expect(MenuBarInteraction.hasOpenStatusMenu(windows, menuBarHeight: 37, ignoringPID: 1))
    }

    @Test func ignoresRegularWindowsOfStatusItemApps() {
        let windows = [
            Window(layer: status, ownerPID: 9, bounds: CGRect(x: 1200, y: 0, width: 30, height: 24)),
            Window(layer: 0, ownerPID: 9, bounds: CGRect(x: 100, y: 300, width: 800, height: 600))
        ]
        #expect(!MenuBarInteraction.hasOpenStatusMenu(windows, menuBarHeight: 24, ignoringPID: 1))
    }
}

struct VersionTests {
    @Test(arguments: [
        ("v5.0.1", "5.0.0", true),
        ("5.1", "5.0.9", true),
        ("5.0.0", "5.0.0", false),
        ("v4.2.0", "5.0.0", false),
        ("5.0.0-beta.1", "4.2.0", true)
    ])
    func compares(candidate: String, current: String, newer: Bool) {
        #expect(UpdateChecker.isVersion(candidate, newerThan: current) == newer)
    }
}

struct SettingsTests {
    @Test func readsLegacyNumberEncodings() {
        #expect(AppSettings.number(NSNumber(value: 25)) == 25)
        #expect(AppSettings.number("25") == 25)
        #expect(AppSettings.number("[30.0]") == 30)
        #expect(AppSettings.number(nil) == nil)
    }

    @MainActor @Test func defaultsWhenEmpty() throws {
        let suite = "dozer-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.iconSize == 10)
        #expect(settings.buttonPadding == 25)
        #expect(settings.hideAfterDelay == 10)
        #expect(settings.automaticallyCheckForUpdates)
        settings.iconSize = 14
        #expect(AppSettings(defaults: defaults).iconSize == 14)
    }
}

struct LegacyShortcutTests {
    @Test func decodesMASShortcutArchive() throws {
        // Build an archive shaped like MASShortcut's (class name "MASShortcut", KeyCode/ModifierFlags).
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.setClassName("MASShortcut", for: LegacyMASShortcut.self)
        let flags = NSEvent.ModifierFlags([.command, .option]).rawValue
        archiver.encode(LegacyMASShortcut(keyCode: 2, modifierFlags: flags), forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()

        let decoded = try #require(LegacyShortcutMigration.decode(archiver.encodedData))
        #expect(decoded.keyCode == 2)
        #expect(decoded.modifierFlags == flags)
    }

    @Test func rejectsGarbage() {
        #expect(LegacyShortcutMigration.decode(Data([1, 2, 3])) == nil)
    }
}
