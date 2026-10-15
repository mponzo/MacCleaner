#!/bin/zsh
# Build a PureMac-style standalone CLI tarball for Homebrew.
# Usage: ./Scripts/package-cli.sh [version]
# Produces: releases/maccleaner-cli-<version>.tar.gz and updates Formula sha256.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/OpenCleanMyMac"
RELEASES="$ROOT/releases"
FORMULA="$ROOT/Formula/maccleaner-cli.rb"
LICENSE="$ROOT/LICENSE"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(
    sed -n 's/.*static let cliVersion = "\([^"]*\)".*/\1/p' \
      "$PKG/Sources/OpenCleanMyMac/CLI/CLISupport.swift" | head -n 1
  )"
fi
[[ -n "$VERSION" ]] || { echo "error: could not resolve CLI version" >&2; exit 1; }

STAGE="$RELEASES/.cli-stage-$$"
ARCHIVE="$RELEASES/maccleaner-cli-${VERSION}.tar.gz"
PRODUCT="maccleaner"

echo "==> Packaging maccleaner CLI v${VERSION}"
mkdir -p "$RELEASES"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cd "$PKG"
echo "==> Building universal release binary"
rm -f \
  "$PKG/.build/arm64-apple-macosx/release/$PRODUCT" \
  "$PKG/.build/x86_64-apple-macosx/release/$PRODUCT"
swift build -c release --arch arm64 --arch x86_64 --product "$PRODUCT"

APPLE_BIN="$PKG/.build/apple/Products/Release/$PRODUCT"
ARM_BIN="$PKG/.build/arm64-apple-macosx/release/$PRODUCT"
X86_BIN="$PKG/.build/x86_64-apple-macosx/release/$PRODUCT"
ARM_OBJ="$PKG/.build/apple/Intermediates.noindex/OpenCleanMyMac.build/Release/OpenCleanMyMac.build/Objects-normal/arm64/Binary/$PRODUCT"
X86_OBJ="$PKG/.build/apple/Intermediates.noindex/OpenCleanMyMac.build/Release/OpenCleanMyMac.build/Objects-normal/x86_64/Binary/$PRODUCT"

OUT="$STAGE/$PRODUCT"
if [[ -x "$APPLE_BIN" ]] && lipo -info "$APPLE_BIN" 2>/dev/null | grep -q 'x86_64' \
  && lipo -info "$APPLE_BIN" 2>/dev/null | grep -q 'arm64'; then
  cp -f "$APPLE_BIN" "$OUT"
elif [[ -x "$ARM_OBJ" && -x "$X86_OBJ" ]]; then
  lipo -create -output "$OUT" "$ARM_OBJ" "$X86_OBJ"
elif [[ -x "$ARM_BIN" && -x "$X86_BIN" ]]; then
  lipo -create -output "$OUT" "$ARM_BIN" "$X86_BIN"
elif [[ -x "$PKG/.build/release/$PRODUCT" ]]; then
  echo "warning: using single-arch .build/release/$PRODUCT" >&2
  cp -f "$PKG/.build/release/$PRODUCT" "$OUT"
else
  echo "error: no release $PRODUCT binary found" >&2
  exit 1
fi
chmod 755 "$OUT"

if ! strings "$OUT" | grep -F 'MacCleanerCLI' >/dev/null; then
  echo "error: binary missing MacCleanerCLI marker" >&2
  exit 1
fi

GOT="$("$OUT" --version 2>/dev/null | head -n 1 || true)"
echo "==> Binary --version: ${GOT}"
echo "==> Architectures: $(lipo -archs "$OUT" 2>/dev/null || echo unknown)"

if [[ -f "$LICENSE" ]]; then
  cp "$LICENSE" "$STAGE/LICENSE"
fi

echo "==> Writing $ARCHIVE"
rm -f "$ARCHIVE"
if [[ -f "$STAGE/LICENSE" ]]; then
  COPYFILE_DISABLE=1 tar -czf "$ARCHIVE" -C "$STAGE" "$PRODUCT" LICENSE
else
  COPYFILE_DISABLE=1 tar -czf "$ARCHIVE" -C "$STAGE" "$PRODUCT"
fi

SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
echo "==> sha256: $SHA"

if [[ -f "$FORMULA" ]]; then
  python3 - "$FORMULA" "$VERSION" "$SHA" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
version, sha = sys.argv[2], sys.argv[3]
text = path.read_text()
text = re.sub(r'(version ")[^"]+(")', rf"\g<1>{version}\2", text, count=1)
url = (
    "https://github.com/mponzo/MacCleaner/releases/download/"
    f"cli-v{version}/maccleaner-cli-{version}.tar.gz"
)
stable = (
    "  # Stable: prebuilt universal tarball (updated by Scripts/package-cli.sh).\n"
    f'  url "{url}"\n'
    f'  sha256 "{sha}"\n'
)
pattern = (
    r"  # Stable:.*?\n"
    r"(?:  # ?url \".*?\"\n)?"
    r"(?:  # ?sha256 \".*?\"\n)?"
    r"(?:  url \".*?\"\n  sha256 \".*?\"\n)?"
)
text, n = re.subn(pattern, stable, text, count=1, flags=re.S)
if n != 1:
    raise SystemExit("error: could not update Formula stable url/sha256 block")
path.write_text(text)
print(f"Updated {path} → v{version} sha256={sha[:12]}…")
PY
fi

rm -rf "$STAGE"

cat <<EOF

CLI package ready:
  $ARCHIVE
  sha256  $SHA

Publish:
  1. gh release create "cli-v${VERSION}" "$ARCHIVE" --title "maccleaner CLI ${VERSION}" --notes "Standalone MacCleaner CLI (TUI)."
  2. Commit Formula/maccleaner-cli.rb with the new sha256.
  3. Users install with:
       brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner
       brew install maccleaner-cli

Local install (no GitHub release):
  ./Scripts/install-cli.sh

EOF
