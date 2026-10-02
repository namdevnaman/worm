#!/bin/bash
# Build Worm.app from the SwiftPM package.
#
# SwiftPM produces a bare executable; a macOS app needs a bundle with an
# Info.plist, an icon, and an ad-hoc signature. This script assembles all three.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CONFIG="${CONFIG:-release}"
APP_NAME="Worm"
BUNDLE_ID="dev.local.worm"

# Bundle version. Previously hardcoded to 1.0.1, which shipped stale versions in
# Finder's "Get Info" and in the DMG. Prefer the caller's VERSION (CI passes the
# release tag), then the newest git tag, and only then a literal fallback.
if [ -z "${VERSION:-}" ]; then
    VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
fi
if [ -z "${VERSION:-}" ]; then
    VERSION="1.0.3"
fi

BUILD_DIR="$ROOT/.build/$CONFIG"
APP="$ROOT/dist/$APP_NAME.app"

echo "▸ Building ($CONFIG)"
swift build -c "$CONFIG" --product "$APP_NAME" 2>&1

# Find the compiled binary — SPM places it in different paths depending on
# whether the Xcode toolchain or command-line tools are active, so we probe
# the known locations in order and fall back to a recursive find.
SRC_BIN=""
for CANDIDATE in \
    "$ROOT/.build/$CONFIG/$APP_NAME" \
    "$ROOT/.build/out/Products/$(echo $CONFIG | sed 's/./\U&/')/$APP_NAME" \
    "$ROOT/.build/apple/Products/$(echo $CONFIG | sed 's/./\U&/')/$APP_NAME" \
    "$(swift build -c "$CONFIG" --show-bin-path 2>/dev/null)/$APP_NAME"; do
    if [ -f "$CANDIDATE" ] && [ -x "$CANDIDATE" ]; then
        SRC_BIN="$CANDIDATE"
        break
    fi
done
if [ -z "$SRC_BIN" ]; then
    SRC_BIN="$(find "$ROOT/.build" -type f -name "$APP_NAME" ! -path "*/Intermediates*" ! -path "*-emit-*" 2>/dev/null | head -n 1)"
fi
if [ -z "$SRC_BIN" ] || [ ! -f "$SRC_BIN" ]; then
    echo "Error: could not locate compiled binary '$APP_NAME' under $ROOT/.build" >&2
    find "$ROOT/.build" -name "$APP_NAME" 2>/dev/null || true
    exit 1
fi

echo "▸ Found binary at: $SRC_BIN"
echo "▸ Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SRC_BIN" "$APP/Contents/MacOS/$APP_NAME"

# Generated so the plist and the binary cannot disagree about the version.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>Worm</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Worm for Mac</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <!-- Not sandboxed. Cleaning needs to read and move files anywhere the user
         owns, which the App Sandbox forbids outright. -->
    <key>NSAppleEventsUsageDescription</key>
    <string>Worm asks Finder to reveal folders so you can check what it found.</string>
</dict>
</plist>
PLIST

if [ -d "$ROOT/Resources" ]; then
    cp -R "$ROOT/Resources/"* "$APP/Contents/Resources/"
    if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
            "$APP/Contents/Info.plist" 2>/dev/null || true
    fi
fi

# Ad-hoc signature. Without one, macOS refuses to launch the app at all and the
# first TCC prompt can behave inconsistently across launches.
#
# The designated requirement is pinned to the bundle identifier rather than left
# at the default `cdhash`. That matters more than it looks: TCC matches a privacy
# grant against the app's designated requirement, and an ad-hoc signature defaults
# to a hash of the exact binary. Every rebuild therefore produced a new hash,
# silently voiding the Full Disk Access grant the user had just made — the toggle
# stayed on in System Settings while the app kept reporting that it had no access.
# Keying the requirement to the identifier makes the grant survive rebuilds.
# The leading `=` is required: without it codesign reads the argument as a path
# to a requirements file and fails with "No such file or directory".
REQUIREMENT="=designated => identifier \"$BUNDLE_ID\""
echo "▸ Signing (ad-hoc, stable requirement: $REQUIREMENT)"
codesign --force --deep --sign - --timestamp=none \
    -r "$REQUIREMENT" "$APP" 2>&1 | sed 's/^/  /'
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/  /' || true

echo "▸ Built $APP"
echo
echo "Install with:"
echo "  cp -R \"$APP\" /Applications/"
echo "Then open it and grant Full Disk Access when prompted."