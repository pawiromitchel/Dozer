/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
import Combine
import os
@preconcurrency import KeyboardShortcuts

/// Owns Dozer's status icons and the show/hide logic.
///
/// Icons, numbered right to left:
/// 1. A click target that can sit anywhere.
/// 2. The separator: it and everything to its left is hidden/shown on click.
/// 3. (Optional) The "remove" icon: it and everything to its left is hidden/shown on option-click.
///
/// In "no icon" mode (requires a keyboard shortcut) only the separator exists, and it hides itself too.
@MainActor
final class DozerIcons {
    static let shared = DozerIcons()
    static let log = Logger(subsystem: "com.mortennn.Dozer", category: "icons")

    private let settings = AppSettings.shared
    private var normalIcons: [StatusIcon] = []
    private var removeIcon: StatusIcon?
    private var autoHideTimer: Timer?
    private var lastInteraction = Date()
    private var previousApp: NSRunningApplication?
    private var cancellables: Set<AnyCancellable> = []

    /// Called when the user asks for the menu (right-click on a Dozer icon).
    var onMenuRequested: ((StatusIcon) -> Void)?

    private init() {}

    func start() {
        rebuildNormalIcons()
        updateRemoveIcon()
        revealIcons()
        // Roles follow position, which macOS restores shortly after the items are created.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateStyles()
        }
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

    private static let autosaveNames = ["Dozer-Separator", "Dozer-Handle"]

    /// Ensures the right number of normal icons exist (1 in no-icon mode, otherwise 2).
    func rebuildNormalIcons() {
        let wanted = isNoIconModeActive ? 1 : 2
        while normalIcons.count > wanted, let right = rightIcon {
            right.remove()
            normalIcons.removeAll { $0 === right }
        }
        while normalIcons.count < wanted {
            let used = Set(normalIcons.map { $0.item.autosaveName ?? "" })
            let name = Self.autosaveNames.first { !used.contains($0) } ?? "Dozer-\(normalIcons.count)"
            normalIcons.append(StatusIcon(kind: .normal, autosaveName: name) { [weak self] icon, event in
                self?.handleClick(on: icon, event: event)
            })
        }
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

    /// The separator: the collapsed icon if there is one, otherwise the leftmost.
    private var leftIcon: StatusIcon? {
        normalIcons.first { !$0.isShown }
            ?? normalIcons.min { ($0.xPosition ?? .infinity) < ($1.xPosition ?? .infinity) }
    }

    private var rightIcon: StatusIcon? {
        normalIcons.last { $0 !== leftIcon } ?? normalIcons.last
    }

    // MARK: Actions

    var isHidden: Bool {
        !(leftIcon?.isShown ?? true)
    }

    func hide() {
        Self.log.debug("hide")
        removeIcon?.hide()
        if isNoIconModeActive {
            normalIcons.forEach { $0.hide() }
        } else {
            leftIcon?.hide()
        }
        stopAutoHideTimer()
        hideIconAndMenu()
        logLayout()
        // Count once the items have been pushed off-screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateStyles()
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
        normalIcons.forEach { $0.show() }
        updateStyles()
        didShow()
    }

    /// One visible dot: the separator draws as a faint line (and vanishes when collapsed),
    /// and the bulldozer shows how many icons are hidden.
    private func updateStyles() {
        guard normalIcons.count > 1, let separator = leftIcon, let handle = rightIcon else {
            normalIcons.forEach { $0.style = .dot }
            return
        }
        separator.style = .divider
        if isHidden, let count = HiddenItems.count(leftOf: separator, excluding: allIcons.filter { $0 !== separator }) {
            Self.log.debug("hidden items: \(count)")
            handle.style = .badge(count)
        } else {
            handle.style = .dot
        }
    }

    func toggle() {
        isHidden ? show() : hide()
    }

    /// Shows everything, including icons behind the "remove" icon.
    func showAll() {
        Self.log.debug("showAll")
        normalIcons.forEach { $0.show() }
        removeIcon?.show()
        updateStyles()
        didShow()
        logLayout()
    }

    /// First launch: explain where to put icons, anchored to the separator. Fresh dots appear left of
    /// every other icon, so without this a click seems to do nothing.
    func showOnboardingIfNeeded(defaults: UserDefaults = .standard) {
        let key = "didShowOnboarding"
        guard !defaults.bool(forKey: key), let button = leftIcon?.item.button else {
            return
        }
        defaults.set(true, forKey: key)

        let label = NSTextField(wrappingLabelWithString: """
            Icons to the left of this line are hidden when you click the Dozer bulldozer.

            Hold ⌘ and drag the icons you want to hide to the left of this line. \
            Right-click the bulldozer for settings.
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
            normalIcons.forEach { $0.show() }
            removeIcon.show()
        } else {
            removeIcon.toggle()
        }
        updateStyles()
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
        rebuildNormalIcons()
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
                    let role = icon.kind == .remove ? "remove" : (icon === leftIcon ? "separator" : "handle")
                    return "\(role)@\(icon.xPosition.map { String(Int($0)) } ?? "?")(\(icon.isShown ? "shown" : "collapsed"))"
                }
                Self.log.debug("layout+\(delay)s: \(layout.joined(separator: " "), privacy: .public) hidden=\(self.isHidden)")
            }
        }
    }

    private var allIcons: [StatusIcon] {
        normalIcons + (removeIcon.map { [$0] } ?? [])
    }
}
