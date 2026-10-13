#!/bin/zsh
# Apply MacCleaner branded Finder layout to a read-write DMG volume.
# Usage: style-dmg.sh <mount_point> <background_png_1x> [volume_name]
set -euo pipefail

MOUNT="${1:?mount point}"
BG_SRC="${2:?background png}"
VOL_NAME="${3:-}"

if [[ -z "$VOL_NAME" ]]; then
  VOL_NAME="$(diskutil info "$MOUNT" 2>/dev/null | awk -F': *' '/Volume Name/{print $2; exit}')"
fi
if [[ -z "$VOL_NAME" ]]; then
  VOL_NAME="$(basename "$MOUNT")"
fi

BG_DIR="$MOUNT/.background"
mkdir -p "$BG_DIR"
cp -f "$BG_SRC" "$BG_DIR/background.png"
# Ensure Finder can resolve the picture while we style
SetFile -a v "$BG_DIR" 2>/dev/null || true
SetFile -a v "$BG_DIR/background.png" 2>/dev/null || true

BG_POSIX="$MOUNT/.background/background.png"

# Finder window: 720×450 content; icons sit on glass pads
# App (217,238) · Applications (500,240) · icon size 128
osascript <<EOF
tell application "Finder"
  activate
  tell disk "$VOL_NAME"
    open
    delay 0.5
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 160, 920, 610}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 12
    set background picture of viewOptions to POSIX file "$BG_POSIX"
    delay 0.3
    try
      set background picture of viewOptions to file ".background:background.png"
    end try
    set position of item "MacCleaner.app" of container window to {217, 238}
    set position of item "Applications" of container window to {500, 240}
    update without registering applications
    delay 1
    close
    delay 0.5
    open
    delay 1
    set bounds of container window to {200, 160, 920, 610}
    set position of item "MacCleaner.app" of container window to {217, 238}
    set position of item "Applications" of container window to {500, 240}
    delay 1
    close
  end tell
end tell
EOF

# Hide the background folder after Finder has locked the picture in .DS_Store
SetFile -a V "$BG_DIR" 2>/dev/null || true

sync
sleep 2
