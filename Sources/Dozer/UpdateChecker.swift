/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa

/// Checks GitHub Releases for a newer version. Replaces Sparkle 1.x, whose appcast and signing key belonged to upstream.
@MainActor
enum UpdateChecker {
    struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    enum Result {
        case updateAvailable(Release)
        case upToDate
        case failed(String)
    }

    static func checkInBackgroundIfDue() {
        let settings = AppSettings.shared
        guard settings.automaticallyCheckForUpdates else {
            return
        }
        if let last = settings.lastUpdateCheck, Date().timeIntervalSince(last) < 60 * 60 * 24 {
            return
        }
        Task {
            if case .updateAvailable(let release) = await check() {
                presentUpdate(release)
            }
        }
    }

    static func checkInteractively() {
        Task {
            let alert = NSAlert()
            switch await check() {
            case .updateAvailable(let release):
                presentUpdate(release)
                return
            case .upToDate:
                alert.messageText = "You’re up to date"
                alert.informativeText = "Dozer \(AppInfo.version) is the latest version."
            case .failed(let reason):
                alert.messageText = "Couldn’t check for updates"
                alert.informativeText = reason
            }
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    static func check() async -> Result {
        AppSettings.shared.lastUpdateCheck = Date()
        let url = URL(string: "https://api.github.com/repos/\(AppInfo.repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 404 {
                return .upToDate
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            return isVersion(release.tagName, newerThan: AppInfo.version) ? .updateAvailable(release) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func presentUpdate(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "A new version of Dozer is available"
        alert.informativeText = "Dozer \(release.tagName) is available. You have \(AppInfo.version)."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
        }
    }

    /// Compares dotted version strings, ignoring a leading "v".
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        func parts(_ version: String) -> [Int] {
            version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".")
                .map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let lhs = parts(candidate)
        let rhs = parts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }
}
