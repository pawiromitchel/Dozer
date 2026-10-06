#!/bin/bash
# Builds Dozer.app with SwiftPM. Only the Xcode Command Line Tools are required.
#
#   Scripts/build-app.sh [debug|release]
#
# Environment:
#   SIGN_IDENTITY  codesign identity (default: "-" for ad-hoc signing)
#   ARCHS          space-separated architectures for release builds (default: "arm64 x86_64")
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Dozer.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS="${ARCHS:-arm64 x86_64}"

cd "$ROOT"

BINARIES=()
if [[ "$CONFIG" == "release" ]]; then
    # One build per architecture, merged with lipo (`--arch a --arch b` needs Xcode's build system).
    for arch in $ARCHS; do
        swift build -c release --triple "$arch-apple-macosx13.0"
        BINARIES+=("$(swift build -c release --triple "$arch-apple-macosx13.0" --show-bin-path)/Dozer")
    done
else
    swift build -c debug
    BINARIES+=("$(swift build -c debug --show-bin-path)/Dozer")
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/Dozer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# KeyboardShortcuts localizations (see Vendor/KeyboardShortcuts/VENDORED.md).
for lproj in Vendor/KeyboardShortcuts/Localization/*.lproj; do
    name="$(basename "$lproj")"
    mkdir -p "$APP/Contents/Resources/$name"
    cp "$lproj/Localizable.strings" "$APP/Contents/Resources/$name/KeyboardShortcuts.strings"
done

codesign --force --options runtime --timestamp=none \
    --entitlements Resources/Dozer.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

echo "Built $APP"
