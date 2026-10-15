#!/bin/zsh
# Install the standalone `maccleaner` CLI onto PATH (Homebrew prefix),
# without needing a GitHub CLI release — PureMac-style separate from the GUI cask.
#
# Usage:
#   ./Scripts/install-cli.sh              # build release + install
#   ./Scripts/install-cli.sh --package    # also write releases/*.tar.gz + update Formula sha
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/OpenCleanMyMac"
PRODUCT="maccleaner"
DO_PACKAGE=0

for arg in "$@"; do
  case "$arg" in
    --package) DO_PACKAGE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

PREFIX="$(brew --prefix 2>/dev/null || true)"
if [[ -z "$PREFIX" ]]; then
  PREFIX="/usr/local"
fi
DEST="$PREFIX/bin/$PRODUCT"

if (( DO_PACKAGE )); then
  "$ROOT/Scripts/package-cli.sh"
fi

echo "==> Building release $PRODUCT"
cd "$PKG"
swift build -c release --product "$PRODUCT"

BIN=""
for candidate in \
  "$PKG/.build/apple/Products/Release/$PRODUCT" \
  "$PKG/.build/release/$PRODUCT" \
  "$PKG/.build/arm64-apple-macosx/release/$PRODUCT" \
  "$PKG/.build/x86_64-apple-macosx/release/$PRODUCT"
do
  if [[ -x "$candidate" ]]; then
    BIN="$candidate"
    break
  fi
done
[[ -n "$BIN" ]] || { echo "error: built binary not found" >&2; exit 1; }

echo "==> Installing $BIN → $DEST"
mkdir -p "$PREFIX/bin"
# Prefer a real file install so upgrades replace cleanly (not a dangling .app symlink).
if [[ -w "$PREFIX/bin" ]]; then
  install -m 755 "$BIN" "$DEST"
else
  echo "Destination not writable — trying sudo"
  sudo install -m 755 "$BIN" "$DEST"
fi

hash -r 2>/dev/null || true
echo "==> Installed: $(command -v "$PRODUCT" || echo "$DEST")"
"$DEST" --version
echo ""
echo "Try:  maccleaner"
echo "      maccleaner doctor"
echo "      maccleaner clean --dry-run"
