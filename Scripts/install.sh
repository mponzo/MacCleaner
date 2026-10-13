#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/dist/MacCleaner.app"
# Prefer /Applications (what users open from Finder / Dock / Spotlight)
DEST_DIR="/Applications"
DEST="$DEST_DIR/MacCleaner.app"
LEGACY_HOME="$HOME/Applications/MacCleaner.app"
LEGACY_NAME_A="/Applications/Open Clean My Mac.app"
LEGACY_NAME_B="$HOME/Applications/Open Clean My Mac.app"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if [[ ! -d "$APP_SRC" ]]; then
  echo "App not packaged yet. Running package-app.sh…"
  "$ROOT/Scripts/package-app.sh"
fi

echo "==> Quitting running MacCleaner instances"
pkill -f 'MacCleaner.app/Contents/MacOS/OpenCleanMyMac' 2>/dev/null || true
pkill -f '/Contents/MacOS/OpenCleanMyMac$' 2>/dev/null || true
# Drop single-instance lock so the new binary can start
rm -f "$HOME/Library/Application Support/MacCleaner/instance.lock"
sleep 1

echo "==> Removing previous installs (all known locations)"
for old in "$DEST" "$LEGACY_HOME" "$LEGACY_NAME_A" "$LEGACY_NAME_B"; do
  if [[ -d "$old" ]]; then
    echo "    rm $old"
    "$LS" -u "$old" 2>/dev/null || true
    rm -rf "$old"
  fi
done

echo "==> Installing to $DEST"
ditto "$APP_SRC" "$DEST"

# Downloads / DMG copies carry com.apple.quarantine → Gatekeeper blocks until notarized.
xattr -cr "$DEST" 2>/dev/null || true
"$LS" -f "$DEST" 2>/dev/null || true

VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")"

echo "Installed: $DEST  (v${VER} #${BUILD})"
echo "Tip: if Dock still opens an old copy, Remove from Dock, then open from /Applications."
open -n "$DEST"
echo "In the app: Settings → enable menu bar icon / launch at login"
echo "If Gatekeeper still blocks a downloaded build: ./Scripts/clear-quarantine.sh \"$DEST\""
