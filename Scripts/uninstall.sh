#!/bin/zsh
set -euo pipefail

DEST="$HOME/Applications/MacCleaner.app"
LEGACY="$HOME/Applications/Open Clean My Mac.app"
BUNDLE_ID="com.maccleaner.app"

osascript -e 'tell application "MacCleaner" to quit' 2>/dev/null || true
osascript -e 'tell application "Open Clean My Mac" to quit' 2>/dev/null || true
sleep 0.5
pkill -f "MacCleaner.app/Contents/MacOS/OpenCleanMyMac" 2>/dev/null || true
pkill -f "Open Clean My Mac.app/Contents/MacOS/OpenCleanMyMac" 2>/dev/null || true

removed=0
for path in "$DEST" "$LEGACY"; do
  if [[ -d "$path" ]]; then
    rm -rf "$path"
    echo "Removed $path"
    removed=1
  fi
done

if [[ "$removed" -eq 0 ]]; then
  echo "Not installed at $DEST"
fi

if command -v sfltool >/dev/null 2>&1; then
  echo "If Launch at Login remains, remove it in System Settings → General → Login Items ($BUNDLE_ID)."
fi

echo "Uninstall complete."
