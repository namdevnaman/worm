#!/bin/bash
# Install Worm.app into /Applications and register it with LaunchServices.
#
# Safe to re-run: the existing bundle is replaced, not duplicated, and the old
# one goes to the Trash so an accidental second copy never lingers.
set -euo pipefail

cd "$(dirname "$0")/.."
SOURCE="$PWD/dist/Worm.app"
TARGET="/Applications/Worm.app"

if [ ! -d "$SOURCE" ]; then
    echo "Build first: ./scripts/build-app.sh" >&2
    exit 1
fi

if [ -e "$TARGET" ]; then
    echo "▸ Replacing existing install at $TARGET"
    # Trash rather than rm: a bad build should be recoverable.
    TRASH="$HOME/.Trash/Worm-replaced-$(date +%Y%m%d-%H%M%S).app"
    mv "$TARGET" "$TRASH" && echo "  old copy moved to $TRASH"
fi

echo "▸ Installing"
cp -R "$SOURCE" "$TARGET"

# Clear the quarantine flag we never set, and refresh LaunchServices so the app
# appears in Spotlight and 'Open With' immediately.
xattr -cr "$TARGET" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$TARGET" 2>/dev/null || true

codesign --verify --verbose=1 "$TARGET" 2>&1 | sed 's/^/  /'

echo
echo "✓ Installed $TARGET"
echo
echo "First run: open Worm, and grant Full Disk Access when macOS asks."
echo "Without it, mail, Messages and some app containers read as empty."
echo "  System Settings → Privacy & Security → Full Disk Access"