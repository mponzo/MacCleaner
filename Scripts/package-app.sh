#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/OpenCleanMyMac"
DIST="$ROOT/dist"
RELEASES="$ROOT/releases"
APP_NAME="MacCleaner.app"
APP="$DIST/$APP_NAME"
BIN_NAME="OpenCleanMyMac"
BUNDLE_ID="com.maccleaner.app"
VERSION="0.2.2"
BUILD="4"
ICON_ICNS="$ROOT/packaging/AppIcon.icns"
VERSION_JSON="$RELEASES/version.json"
CASK="$ROOT/Casks/maccleaner.rb"

ZIP="$RELEASES/MacCleaner-${VERSION}.zip"
DMG="$RELEASES/MacCleaner-${VERSION}.dmg"
ZIP_STABLE="$RELEASES/MacCleaner.app.zip"
DMG_STABLE="$RELEASES/MacCleaner.dmg"
RELEASE_BASE="https://github.com/mponzo/MacCleaner/releases/download/v${VERSION}"

echo "==> Building universal release binary (arm64 + x86_64)"
cd "$PKG"
swift build -c release --arch arm64 --arch x86_64 --product OpenCleanMyMac

ARM_BIN="$PKG/.build/arm64-apple-macosx/release/$BIN_NAME"
X86_BIN="$PKG/.build/x86_64-apple-macosx/release/$BIN_NAME"
test -x "$ARM_BIN"
test -x "$X86_BIN"

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

echo "==> Writing versioned zip: $(basename "$ZIP")"
rm -f "$ZIP" "$ZIP_STABLE"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
cp -f "$ZIP" "$ZIP_STABLE"

echo "==> Writing versioned DMG: $(basename "$DMG")"
STAGE="$DIST/dmg-stage"
rm -rf "$STAGE" "$DMG" "$DMG_STABLE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "MacCleaner ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null
cp -f "$DMG" "$DMG_STABLE"
rm -rf "$STAGE"

DMG_SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

cat > "$VERSION_JSON" <<JSON
{
  "version": "${VERSION}",
  "build": ${BUILD},
  "zip_url": "${RELEASE_BASE}/MacCleaner-${VERSION}.zip",
  "dmg_url": "${RELEASE_BASE}/MacCleaner-${VERSION}.dmg",
  "notes": "Versioned DMG + zip installers; Homebrew cask support.",
  "notes_it": "Installer DMG e zip versionati; supporto Homebrew cask."
}
JSON

mkdir -p "$(dirname "$CASK")"
cat > "$CASK" <<RUBY
cask "maccleaner" do
  version "${VERSION}"
  sha256 "${DMG_SHA}"

  url "https://github.com/mponzo/MacCleaner/releases/download/v#{version}/MacCleaner-#{version}.dmg"
  name "MacCleaner"
  desc "Local-first open-source Mac cleaner with zero telemetry"
  homepage "https://github.com/mponzo/MacCleaner"

  depends_on macos: ">= :sonoma"

  app "MacCleaner.app"

  zap trash: [
    "~/Library/Preferences/com.maccleaner.app.plist",
    "~/Library/Application Support/MacCleaner",
  ]
end
RUBY

echo "==> Done: $APP"
echo "==> Zip:  $ZIP (+ stable MacCleaner.app.zip)"
echo "==> DMG:  $DMG (+ stable MacCleaner.dmg)"
echo "==> Cask: $CASK"
echo "==> Manifest: $VERSION_JSON ($VERSION #$BUILD)"
lipo -info "$APP/Contents/MacOS/$BIN_NAME" || true
echo "Install: open $DMG"
echo "Or:      ./Scripts/install.sh"
echo "Brew:    brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner && brew trust mponzo/maccleaner && brew install --cask maccleaner"
