#!/bin/bash
# Builds a clean, professional, portable DMG for Worm on macOS.
# Contains:
#  - Worm.app
#  - /Applications symlink (Drag to install)
#  - Open-If-Blocked.command (One-click Gatekeeper / quarantine unblocker)
#  - Readme-Permissions.txt (Plain text step-by-step guidance)

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DIST="$ROOT/dist"
APP="$DIST/Worm.app"
DMG_NAME="Worm-Installer.dmg"
DMG_PATH="$DIST/$DMG_NAME"
VOLUME_NAME="Worm"
STAGE="$ROOT/.build/dmg-staging"

if [ ! -d "$APP" ]; then
    echo "▸ Worm.app not found in $DIST. Running ./scripts/build-app.sh first..."
    ./scripts/build-app.sh
fi

echo "▸ Preparing DMG staging environment"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# 1. Copy Worm.app
echo "▸ Copying Worm.app"
cp -R "$APP" "$STAGE/Worm.app"

# Strip quarantine attribute from the packaged app
xattr -cr "$STAGE/Worm.app" 2>/dev/null || true

# 2. Create symlink to /Applications
echo "▸ Creating Applications shortcut"
ln -s /Applications "$STAGE/Applications"

# 3. Create Open-If-Blocked helper script
cat > "$STAGE/Open-If-Blocked.command" <<'CMD'
#!/bin/bash
clear
echo "=========================================================="
echo "           WORM - macOS GATEKEEPER UNBLOCKER              "
echo "=========================================================="
echo
echo "If macOS displays:"
echo '  "Worm cannot be opened because Apple cannot check it"'
echo "  or Gatekeeper blocks launching,"
echo "this tool clears the quarantine flag immediately."
echo

APP_PATH="/Applications/Worm.app"

if [ ! -d "$APP_PATH" ]; then
    # Check if app is in current directory
    DIR="$(dirname "$0")"
    if [ -d "$DIR/Worm.app" ]; then
        APP_PATH="$DIR/Worm.app"
    fi
fi

if [ -d "$APP_PATH" ]; then
    echo "Found app at: $APP_PATH"
    echo "Clearing quarantine attributes..."
    xattr -cr "$APP_PATH" 2>/dev/null || true
    echo
    echo "✓ Done! Quarantine cleared."
    echo "Opening Worm now..."
    open "$APP_PATH"
else
    echo "Note: Drag Worm.app into Applications first, then run this command."
fi

echo
echo "If macOS still shows a prompt:"
echo "1. Go to System Settings → Privacy & Security"
echo "2. Scroll down to Security"
echo '3. Click "Open Anyway"'
echo
echo "Closing in 5 seconds..."
sleep 5
CMD
chmod +x "$STAGE/Open-If-Blocked.command"

# 4. Create Readme-Permissions.txt
cat > "$STAGE/Quick-Start & Privacy Guide.txt" <<'TXT'
WORM FOR MACOS - INSTALLATION & PRIVACY INSTRUCTIONS
====================================================

1. INSTALLATION:
   Drag Worm.app into the "Applications" shortcut icon.

2. IF BLOCKED BY MACOS GATEKEEPER:
   ("Worm cannot be opened because Apple cannot check it for malicious software")

   Option A (Fastest):
   - Double-click "Open-If-Blocked.command" in this folder. It removes the
     quarantine flag automatically and opens the app.

   Option B (System Settings):
   - Open System Settings → Privacy & Security
   - Scroll down to "Security"
   - Click "Open Anyway" next to Worm

   Option C (Right-Click):
   - Right-click (or Control-click) Worm.app in /Applications
   - Select "Open", then click "Open" in the dialog box.

3. FULL DISK ACCESS:
   Worm inspects system containers (~/Library/Containers) and leftovers.
   To see accurate sizes and clean without missing files:
   - System Settings → Privacy & Security → Full Disk Access
   - Toggle Worm to ON.
TXT

# Remove old DMG if present
rm -f "$DMG_PATH"

echo "▸ Creating disk image: $DMG_NAME"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGE"

echo
echo "✓ Universal DMG successfully created at:"
echo "  $DMG_PATH"
echo
echo "Users can now install Worm with drag-and-drop and unblock Gatekeeper with 1 click."
