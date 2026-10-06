import SwiftUI
import Testing
@testable import Dozer

/// Renders the settings window to a PNG for visual review: DOZER_SNAPSHOT=/path/out.png make test
@MainActor
struct SnapshotTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOZER_SNAPSHOT"] != nil))
    func settingsSnapshot() throws {
        let path = try #require(ProcessInfo.processInfo.environment["DOZER_SNAPSHOT"])
        let view = NSHostingView(rootView: SettingsView())
        view.appearance = NSAppearance(named: .aqua)
        view.frame.size = view.fittingSize
        view.layoutSubtreeIfNeeded()
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
    }
}
