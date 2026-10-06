Vendored from https://github.com/sindresorhus/KeyboardShortcuts v1.17.0 (MIT, see LICENSE).

Changes, both so Dozer builds and signs with only the Xcode Command Line Tools:

- Removed the `#Preview` blocks in `Recorder.swift`. The Previews macro plugin ships only with Xcode.
- `String.localized` (in `Utilities.swift`) reads the `KeyboardShortcuts` strings table from the main bundle
  instead of SwiftPM's `Bundle.module`. SwiftPM expects that resource bundle at the root of the `.app`,
  which breaks code signing. `make app` copies `Localization/*.lproj/Localizable.strings` into
  `Dozer.app/Contents/Resources/*.lproj/KeyboardShortcuts.strings`.
