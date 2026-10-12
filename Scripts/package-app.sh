#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/OpenCleanMyMac"
DIST="$ROOT/dist"
RELEASES="$ROOT/releases"
APP_NAME="MacCleaner.app"
APP="$DIST/$APP_NAME"
ZIP="$RELEASES/MacCleaner.app.zip"
BIN_NAME="OpenCleanMyMac"
BUNDLE_ID="com.maccleaner.app"
VERSION="0.2.2"
BUILD="4"
ICON_ICNS="$ROOT/packaging/AppIcon.icns"
VERSION_JSON="$RELEASES/version.json"

echo "==> Building universal release binary (arm64 + x86_64)"
cd "$PKG"
swift build -c release --arch arm64 --arch x86_64 --product OpenCleanMyMac

ARM_BIN="$PKG/.build/arm64-apple-macosx/release/$BIN_NAME"
X86_BIN="$PKG/.build/x86_64-apple-macosx/release/$BIN_NAME"
test -x "$ARM_BIN"
test -x "$X86_BIN"

# Resource bundle lives next to either arch build
RESOURCE_BUNDLE=""
for candidate in \
  "$PKG/.build/arm64-apple-macosx/release/${BIN_NAME}_${BIN_NAME}.bundle" \
  "$PKG/.build/x86_64-apple-macosx/release/${BIN_NAME}_${BIN_NAME}.bundle"
do
  if [[ -d "$candidate" ]]; then
    RESOURCE_BUNDLE="$candidate"
    break
  fi
done

echo "==> Assembling $APP_NAME"
rm -rf "$APP"
# Remove legacy packaged name if present
rm -rf "$DIST/Open Clean My Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo -create -output "$APP/Contents/MacOS/$BIN_NAME" "$ARM_BIN" "$X86_BIN"
chmod +x "$APP/Contents/MacOS/$BIN_NAME"

if [[ -n "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
else
  echo "warning: resource bundle not found" >&2
fi

if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "warning: AppIcon.icns missing at $ICON_ICNS" >&2
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>it</string>
  </array>
  <key>CFBundleExecutable</key>
  <string>${BIN_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MacCleaner</string>
  <key>CFBundleDisplayName</key>
  <string>MacCleaner</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
  <key>LSMultipleInstancesProhibited</key>
  <true/>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Prefer Developer ID when present (full notarization: ./Scripts/sign-and-notarize.sh).
# Otherwise ad-hoc so local runs still work.
DEV_ID_IDENTITY="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -n 1
)"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  DEV_ID_IDENTITY="$CODESIGN_IDENTITY"
fi

if [[ -n "$DEV_ID_IDENTITY" ]]; then
  echo "==> Codesign (Developer ID — run sign-and-notarize.sh to notarize)"
  codesign --force --deep --timestamp --options runtime \
    --entitlements "$ROOT/packaging/MacCleaner.entitlements" \
    --sign "$DEV_ID_IDENTITY" \
    "$APP" || true
elif command -v codesign >/dev/null 2>&1; then
  echo "==> Ad-hoc codesign (no Developer ID Application cert found)"
  codesign --force --deep --sign - "$APP" || true
fi

mkdir -p "$RELEASES"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

cat > "$VERSION_JSON" <<JSON
{
  "version": "${VERSION}",
  "build": ${BUILD},
  "zip_url": "https://github.com/mponzo/MacCleaner/raw/main/releases/MacCleaner.app.zip",
  "notes": "Modern Apple-style app icon.",
  "notes_it": "Icona app in stile Apple moderno."
}
JSON

echo "==> Done: $APP"
echo "==> Zip:  $ZIP"
echo "==> Manifest: $VERSION_JSON ($VERSION #$BUILD)"
lipo -info "$APP/Contents/MacOS/$BIN_NAME" || true
echo "Install: unzip releases/MacCleaner.app.zip && open MacCleaner.app"
echo "Or:      ./Scripts/install.sh"
