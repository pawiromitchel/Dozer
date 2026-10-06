/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
import Combine
import os
@preconcurrency import KeyboardShortcuts

/// Owns Dozer's status icons and the show/hide logic.
///
/// - The bulldozer: clicking it hides/shows everything to its left. While hidden it shows how many.
/// - The wall: an invisible item glued directly left of the bulldozer that stretches to do the hiding.
/// - (Optional) The "remove" icon: it and everything to its left stays hidden until option-click.
///
/// In "no icon" mode (requires a keyboard shortcut) the bulldozer hides itself too.
@MainActor
final class DozerIcons {
    static let shared = DozerIcons()
    static let log = Logger(subsystem: "com.mortennn.Dozer", category: "icons")

    private let settings = AppSettings.shared
    private var bulldozer: StatusIcon?
    private var wall: StatusIcon?
    private var removeIcon: StatusIcon?
    private var gluedPosition: Double?
    private var autoHideTimer: Timer?
    private var lastInteraction = Date()
    private var previousApp: NSRunningApplication?
    private var cancellables: Set<AnyCancellable> = []

    /// Called when the user asks for the menu (right-click on a Dozer icon).
    var onMenuRequested: ((StatusIcon) -> Void)?

    private init() {}

    func start() {
        migratePosition()
        bulldozer = StatusIcon(kind: .bulldozer, autosaveName: Self.bulldozerName) { [weak self] icon, event in
            self?.handleClick(on: icon, event: event)
        }
        glueWall()
        updateRemoveIcon()
        revealIcons()
        observeSettings()
        observeSystem()
        KeyboardShortcuts.onKeyUp(for: .toggleMenuItems) { [weak self] in
            self?.toggle()
        }
        updateAutoHideTimer()
    }

    var isShortcutSet: Bool {
        KeyboardShortcuts.getShortcut(for: .toggleMenuItems) != nil
    }

    private var isNoIconModeActive: Bool {
        settings.noIconMode && isShortcutSet
    }

    // MARK: Icons

    private static let bulldozerName = "Dozer-Bulldozer"
    private static let wallName = "Dozer-Wall"

    /// macOS stores each item's position under this key: the distance from the right end of the menu
    /// bar, so a larger value is further left.
    private static func positionKey(_ name: String) -> String {
        "NSStatusItem Preferred Position \(name)"
    }

    /// Earlier builds used the separator's spot for the hiding boundary; start the bulldozer there.
    private func migratePosition(defaults: UserDefaults = .standard) {
        let key = Self.positionKey(Self.bulldozerName)
        guard defaults.object(forKey: key) == nil,
              let old = defaults.object(forKey: Self.positionKey("Dozer-Separator")) else {
            return
        }
        defaults.set(old, forKey: key)
    }

    /// (Re)creates the wall directly left of the bulldozer. macOS only places an item at its saved
    /// position when it's created, so moving the wall means recreating it.
    private func glueWall(defaults: UserDefaults = .standard) {
        let wasHidden = isHidden
        wall?.remove()
        let position = defaults.object(forKey: Self.positionKey(Self.bulldozerName)) as? Double
        if let position {
            defaults.set(position + 1, forKey: Self.positionKey(Self.wallName))
        }
        gluedPosition = position
        wall = StatusIcon(kind: .wall, autosaveName: Self.wallName) { _, _ in }
        if wasHidden {
            wall?.hide()
        }
        Self.log.debug("wall glued at \(position ?? -1)")
    }

    /// Called when defaults change: if the user ⌘-dragged the bulldozer, bring the wall along.
    private func bulldozerMaybeMoved(defaults: UserDefaults = .standard) {
        let position = defaults.object(forKey: Self.positionKey(Self.bulldozerName)) as? Double
        guard let position, position != gluedPosition, !isHidden else {
            return
        }
        glueWall()
    }

    private func updateRemoveIcon() {
        if settings.removeIconEnabled, removeIcon == nil {
            removeIcon = StatusIcon(kind: .remove, autosaveName: "Dozer-Remove") { [weak self] icon, event in
                self?.handleClick(on: icon, event: event)
            }
        } else if !settings.removeIconEnabled, let icon = removeIcon {
            icon.remove()
            removeIcon = nil
        }
    }

    // MARK: Actions

    var isHidden: Bool {
        !(wall?.isShown ?? true)
    }

    func hide() {
        Self.log.debug("hide")
        removeIcon?.hide()
        wall?.hide()
        if isNoIconModeActive {
            bulldozer?.hide()
        }
        stopAutoHideTimer()
        hideIconAndMenu()
        logLayout()
        // Count once the items have been pushed off-screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateCount()
        }
    }

    func show() {
        Self.log.debug("show")
        revealIcons()
        showIconAndMenu()
        logLayout()
    }

    /// Shows the first group of icons; the "remove" group stays hidden.
    private func revealIcons() {
        removeIcon?.hide()
        wall?.show()
        bulldozer?.show()
        updateCount()
        didShow()
    }

    /// While hidden, the bulldozer shows how many icons it dozered.
    private func updateCount() {
        guard let bulldozer, let wall else {
            return
        }
        if isHidden, let count = HiddenItems.count(leftOf: wall, excluding: removeIcon.map { [$0] } ?? []) {
            Self.log.debug("hidden items: \(count)")
            bulldozer.hiddenCount = count
        } else {
            bulldozer.hiddenCount = nil
        }
    }

    func toggle() {
        isHidden ? show() : hide()
    }

    /// Shows everything, including icons behind the "remove" icon.
    func showAll() {
        Self.log.debug("showAll")
        wall?.show()
        bulldozer?.show()
        removeIcon?.show()
        updateCount()
        didShow()
        logLayout()
    }

    /// First launch: explain where to put icons. The bulldozer first appears left of every other icon,
    /// so without this a click seems to do nothing.
    func showOnboardingIfNeeded(defaults: UserDefaults = .standard) {
        let key = "didShowOnboarding"
        guard !defaults.bool(forKey: key), let button = bulldozer?.item.button else {
            return
        }
        defaults.set(true, forKey: key)

        let label = NSTextField(wrappingLabelWithString: """
            Click the bulldozer to hide every icon to its left.

            Hold ⌘ and drag icons you always want to see to the right of the bulldozer. \
            Right-click it for settings.
            """)
        label.preferredMaxLayoutWidth = 260
        let container = NSView()
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            label.widthAnchor.constraint(equalToConstant: 260)
        ])
        let controller = NSViewController()
        controller.view = container

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        // Let macOS place the restored icons first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func hideAtLaunch() {
        guard settings.hideAtLaunch else {
            return
        }
        // Give macOS a moment to restore saved icon positions before collapsing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.hide()
        }
    }

    /// `event` can be nil: on recent macOS the click may arrive without a current event. Treat that as a plain left-click.
    private func handleClick(on icon: StatusIcon, event: NSEvent?) {
        let flags = (event?.modifierFlags ?? []).intersection(.deviceIndependentFlagsMask)
        let isRightClick = event?.type == .rightMouseDown || event?.type == .rightMouseUp || flags.contains(.control)

        if isRightClick {
            onMenuRequested?(icon)
            return
        }

        if flags.contains(.option), !flags.contains(.command) {
            handleOptionClick()
            return
        }

        if icon.kind == .remove {
            icon.toggle()
            didShow()
        } else {
            toggle()
        }
    }

    private func handleOptionClick() {
        guard let removeIcon else {
            toggle()
            return
        }
        showIconAndMenu()
        if isHidden {
            wall?.show()
            bulldozer?.show()
            removeIcon.show()
        } else {
            removeIcon.toggle()
        }
        updateCount()
        didShow()
    }

    // MARK: "Show icon and menu" mode

    /// Temporarily makes Dozer the active app, replacing the frontmost app's (often long)
    /// menu with Dozer's short one so more status icons fit.
    private func showIconAndMenu() {
        guard settings.showIconAndMenu else {
            return
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideIconAndMenu() {
        guard settings.showIconAndMenu else {
            return
        }
        NSApp.setActivationPolicy(.accessory)
        if NSApp.isActive {
            previousApp?.activate()
        }
    }

    // MARK: Auto-hide

    private func didShow() {
        lastInteraction = Date()
        updateAutoHideTimer()
    }

    private func updateAutoHideTimer() {
        guard settings.hideAfterDelayEnabled, !isHidden else {
            stopAutoHideTimer()
            return
        }
        lastInteraction = Date()
        guard autoHideTimer == nil else {
            return
        }
        // A single cheap 1s tick replaces Dozer 4's two timers (one of them polling the window list every 0.5s).
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.autoHideTick()
            }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        autoHideTimer = timer
    }

    private func stopAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    private func autoHideTick() {
        guard !isHidden else {
            stopAutoHideTimer()
            return
        }
        if MenuBarInteraction.isUserInteracting() {
            lastInteraction = Date()
            return
        }
        if Date().timeIntervalSince(lastInteraction) >= settings.hideAfterDelay {
            Self.log.debug("auto-hide after \(self.settings.hideAfterDelay)s")
            hide()
        }
    }

    // MARK: Observation

    private func observeSettings() {
        settings.$noIconMode.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.shortcutDidChange() }
            .store(in: &cancellables)

        settings.$removeIconEnabled.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRemoveIcon()
                self?.showAll()
            }
            .store(in: &cancellables)

        Publishers.Merge(settings.$iconSize.map { _ in () }, settings.$buttonPadding.map { _ in () })
            .dropFirst(2).receive(on: RunLoop.main)
            .sink { [weak self] in self?.allIcons.forEach { $0.updateAppearance() } }
            .store(in: &cancellables)

        Publishers.Merge(settings.$hideAfterDelayEnabled.map { _ in () }, settings.$hideAfterDelay.map { _ in () })
            .dropFirst(2).receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateAutoHideTimer() }
            .store(in: &cancellables)

        settings.$showIconAndMenu.dropFirst().receive(on: RunLoop.main)
            .sink { enabled in
                if !enabled {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
            .store(in: &cancellables)
    }

    private func observeSystem() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.bulldozerMaybeMoved() }
            .store(in: &cancellables)

        // Icons can be re-laid out after waking, unlocking or display changes; re-apply our state.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let names: [(NotificationCenter, Notification.Name)] = [
            (workspaceCenter, NSWorkspace.didWakeNotification),
            (workspaceCenter, NSWorkspace.screensDidWakeNotification),
            (workspaceCenter, NSWorkspace.sessionDidBecomeActiveNotification),
            (NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        ]
        for (center, name) in names {
            center.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.reapplyState() }
                .store(in: &cancellables)
        }
    }

    private func reapplyState() {
        let hidden = isHidden
        allIcons.forEach { $0.updateAppearance() }
        if hidden {
            hide()
        }
    }

    func shortcutDidChange() {
        revealIcons()
    }

    /// Logs icon positions, viewable with `log stream --level debug --predicate 'subsystem == "com.mortennn.Dozer"'`.
    private func logLayout() {
        for delay in [0.3, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else {
                    return
                }
                let layout = allIcons.map { icon in
                    let role = String(describing: icon.kind)
                    return "\(role)@\(icon.xPosition.map { String(Int($0)) } ?? "?")(\(icon.isShown ? "shown" : "collapsed"))"
                }
                Self.log.debug("layout+\(delay)s: \(layout.joined(separator: " "), privacy: .public) hidden=\(self.isHidden)")
            }
        }
    }

    private var allIcons: [StatusIcon] {
        [bulldozer, wall, removeIcon].compactMap { $0 }
    }
}
