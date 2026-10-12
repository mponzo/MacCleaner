#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/dist/MacCleaner.app"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/MacCleaner.app"

if [[ ! -d "$APP_SRC" ]]; then
  echo "App not packaged yet. Running package-app.sh…"
  "$ROOT/Scripts/package-app.sh"
fi

mkdir -p "$DEST_DIR"
# Remove previous installs (new + legacy names)
rm -rf "$DEST" "$DEST_DIR/Open Clean My Mac.app"
cp -R "$APP_SRC" "$DEST"

echo "Installed: $DEST"
open "$DEST"
echo "In the app: Settings → enable menu bar icon / launch at login"
