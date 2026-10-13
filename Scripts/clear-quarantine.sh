#!/bin/zsh
# Strip Gatekeeper quarantine from a local MacCleaner.app so it can launch
# before notarization is set up. Safe on your own downloads.
set -euo pipefail

TARGETS=(
  "${1:-}"
  "$HOME/Applications/MacCleaner.app"
  "/Applications/MacCleaner.app"
  "$(cd "$(dirname "$0")/.." && pwd)/dist/MacCleaner.app"
)

cleared=0
for app in "${TARGETS[@]}"; do
  [[ -z "$app" || ! -d "$app" ]] && continue
  if xattr -p com.apple.quarantine "$app" >/dev/null 2>&1; then
    echo "==> Clearing quarantine: $app"
    xattr -cr "$app"
    cleared=1
  else
    echo "==> No quarantine on: $app"
  fi
done

if [[ "$cleared" -eq 0 && -z "${1:-}" ]]; then
  cat <<EOF
No quarantined MacCleaner.app found in ~/Applications, /Applications, or dist/.

Usage:
  ./Scripts/clear-quarantine.sh /path/to/MacCleaner.app

Or after dragging from the DMG:
  xattr -cr ~/Applications/MacCleaner.app
  open ~/Applications/MacCleaner.app

Permanent fix (no Gatekeeper warning for downloaders):
  store notary credentials → ./Scripts/sign-and-notarize.sh
  See docs/NOTARIZATION.md
EOF
  exit 1
fi

echo "Done. Open with: open \"${1:-$HOME/Applications/MacCleaner.app}\""
