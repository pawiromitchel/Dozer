# Changelog

## Version 5.0.0 (community fork)
Dozer is maintained again in this fork, after four years without upstream updates.

Fixed:
* Crash when the screen locks or the display sleeps. The menu bar check force-cast window bounds to integers, which failed on fractional coordinates (upstream #186, #189, #193, #183).
* Icon positions forgotten after a restart: icons now use `autosaveName`, so macOS remembers where you put them (#118, #140).
* "Hide after delay" never noticed menu bar use on notched MacBooks (it assumed a 22pt menu bar), and it can't see other apps' status items on macOS 26. It now checks the pointer position against the real menu bar height and checks for open menus (#151).
* The "remove" icon could resize the normal icons, because they shared one image instance.
* Removed every `fatalError`/force-unwrap path in the icon logic.
* Native Apple Silicon: universal binary (arm64 + x86_64) (#153, #162, #203, #210).

New:
* Rewritten settings window in SwiftUI.
* Right-click menu: Show All Icons, Settings…, Check for Updates…, Quit.
* `dozer://` URL scheme for automation (Shortcuts, Raycast, scripts): `toggle`, `show`, `hide`, `show-all`, `settings`.
* Longer auto-hide delays, up to 5 minutes (#151).
* Ctrl-click opens the menu, same as right-click.
* Debug logging: `log stream --level debug --predicate 'subsystem == "com.mortennn.Dozer"'`.

Under the hood:
* Builds with Swift Package Manager and only the Xcode Command Line Tools (`make app`). Carthage, XcodeGen, SwiftGen and the XIBs are gone.
* Requires macOS 13 Ventura or later.
* Dependencies went from 5 to 1. Launch at login uses `SMAppService`. Sparkle 1.x became a GitHub Releases check. MASShortcut became KeyboardShortcuts (vendored). Defaults and Preferences were replaced by plain `UserDefaults` and SwiftUI.
* Swift 6 language mode with strict concurrency.
* One 1s auto-hide timer replaces two timers, one of which polled the window list every 0.5s.
* Settings and the keyboard shortcut from Dozer 4.x are migrated automatically.
* Unit tests (`make test`) and GitHub Actions CI.

## Version 4.2.0
New features:
* Configure amount of seconds to hide the icons after #104. @blakedgordon
* Resize icons and padding capability added #101. @blakedgordon

Fixed:
* Fix both dozer icons from being hidden #105. @blakedgordon

Thank you @blakedgordon for the contributions🙌

## Version 4.1.0
New features:
* Hide status bar icons at launch #78. @aonez

Fixed:
* Reduce CPU usage when "Hide status bar icons after 10 seconds" is checked #78. @aonez

Thank you @aonez for the contributions🙌

## Version 4
New features:
* ”Remove”-icon. Additional icon to hide/show icons with `option+click`
* Auto-hide status bar icons #22
* ”No Icon”-mode. Hide/show only using keyboard shortcut

Other:
* Improved UI in preferences
