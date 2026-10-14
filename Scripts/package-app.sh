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
VERSION="0.2.8"
BUILD="10"
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
# Drop stale per-arch products so we never lipo yesterday's binary (SwiftPM now writes
# the fat binary under .build/apple/Products/Release/).
rm -f \
  "$PKG/.build/arm64-apple-macosx/release/$BIN_NAME" \
  "$PKG/.build/x86_64-apple-macosx/release/$BIN_NAME"
swift build -c release --arch arm64 --arch x86_64 --product OpenCleanMyMac

APPLE_BIN="$PKG/.build/apple/Products/Release/$BIN_NAME"
ARM_BIN="$PKG/.build/arm64-apple-macosx/release/$BIN_NAME"
X86_BIN="$PKG/.build/x86_64-apple-macosx/release/$BIN_NAME"
ARM_OBJ="$PKG/.build/apple/Intermediates.noindex/OpenCleanMyMac.build/Release/OpenCleanMyMac.build/Objects-normal/arm64/Binary/$BIN_NAME"
X86_OBJ="$PKG/.build/apple/Intermediates.noindex/OpenCleanMyMac.build/Release/OpenCleanMyMac.build/Objects-normal/x86_64/Binary/$BIN_NAME"

RESOURCE_BUNDLE=""
for candidate in \
  "$PKG/.build/apple/Products/Release/${BIN_NAME}_${BIN_NAME}.bundle" \
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

OUT_BIN="$APP/Contents/MacOS/$BIN_NAME"
if [[ -x "$APPLE_BIN" ]] && lipo -info "$APPLE_BIN" 2>/dev/null | grep -q 'x86_64' \
  && lipo -info "$APPLE_BIN" 2>/dev/null | grep -q 'arm64'; then
  echo "==> Using SwiftPM universal product: $APPLE_BIN"
  cp -f "$APPLE_BIN" "$OUT_BIN"
elif [[ -x "$ARM_OBJ" && -x "$X86_OBJ" ]]; then
  echo "==> lipo from apple Intermediates"
  lipo -create -output "$OUT_BIN" "$ARM_OBJ" "$X86_OBJ"
elif [[ -x "$ARM_BIN" && -x "$X86_BIN" ]]; then
  echo "==> lipo from per-arch release folders"
  lipo -create -output "$OUT_BIN" "$ARM_BIN" "$X86_BIN"
else
  echo "error: no release binary found under .build/" >&2
  exit 1
fi
chmod +x "$OUT_BIN"

# Sanity: refuse to ship a build that is missing known feature markers.
# Avoid `grep -q` under `pipefail` (SIGPIPE from early close looks like failure).
assert_marker() {
  local needle="$1"
  if ! strings "$OUT_BIN" | grep -F "$needle" >/dev/null; then
    echo "error: packaged binary missing ${needle} — refusing stale build" >&2
    exit 1
  fi
}
assert_marker 'DuplicateFinderEngine'
assert_marker 'sidebar.duplicates'
assert_marker 'CleanupScheduler'
assert_marker 'SpaceExplorerEngine'
assert_marker 'CleanupExclusions'
assert_marker 'uninstallApp'
assert_marker 'OrphanFinderEngine'
assert_marker 'StartupEngine'
assert_marker 'DeveloperCleanupEngine'
assert_marker 'PrivacyHubEngine'

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
    <string>de</string>
    <string>fr</string>
    <string>es</string>
    <string>pt-BR</string>
    <string>ja</string>
    <string>zh-Hans</string>
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
  <key>NSDesktopFolderUsageDescription</key>
  <string>MacCleaner needs access to your Desktop to find reclaimable and leftover files.</string>
  <key>NSDocumentsFolderUsageDescription</key>
  <string>MacCleaner needs access to your Documents to find reclaimable and leftover files.</string>
  <key>NSDownloadsFolderUsageDescription</key>
  <string>MacCleaner needs access to your Downloads to find reclaimable and leftover files.</string>
  <key>NSRemovableVolumesUsageDescription</key>
  <string>MacCleaner needs access to removable volumes to scan for reclaimable files.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>MacCleaner uses Apple Events to interact with Finder when revealing or trashing files.</string>
  <key>NSSystemAdministrationUsageDescription</key>
  <string>MacCleaner needs administrator access to clean protected caches and uninstall some apps.</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Uninstall with MacCleaner</string>
      </dict>
      <key>NSMessage</key>
      <string>uninstallApp</string>
      <key>NSPortName</key>
      <string>OpenCleanMyMac</string>
      <key>NSRequiredContext</key>
      <dict/>
      <key>NSSendFileTypes</key>
      <array>
        <string>com.apple.application-bundle</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

# Localized Finder Services menu title
SERVICES_DIR="$APP/Contents/Resources"
declare -A SERVICES_TITLES=(
  [en]="Uninstall with MacCleaner"
  [it]="Disinstalla con MacCleaner"
  [de]="Mit MacCleaner deinstallieren"
  [fr]="Désinstaller avec MacCleaner"
  [es]="Desinstalar con MacCleaner"
  [pt-BR]="Desinstalar com MacCleaner"
  [ja]="MacCleaner でアンインストール"
  [zh-Hans]="使用 MacCleaner 卸载"
)
for loc in "${!SERVICES_TITLES[@]}"; do
  mkdir -p "$SERVICES_DIR/${loc}.lproj"
  printf '/* Services menu */\n"Uninstall with MacCleaner" = "%s";\n' "${SERVICES_TITLES[$loc]}" \
    > "$SERVICES_DIR/${loc}.lproj/ServicesMenu.strings"
done

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
VOL_NAME="MacCleaner ${VERSION}"
DMG_BG_PNG="$ROOT/packaging/dmg-background@1x.png"
DMG_BG_TIFF="$ROOT/packaging/dmg-background@1x.tiff"
DMG_SETTINGS="$ROOT/packaging/dmgbuild-settings.py"
rm -f "$DMG" "$DMG_STABLE"

# Prefer TIFF for Finder background fidelity; refresh from PNG when present
if [[ -f "$DMG_BG_PNG" ]]; then
  sips -s format tiff "$DMG_BG_PNG" --out "$DMG_BG_TIFF" >/dev/null
fi

DMGBUILD_BIN=""
if command -v dmgbuild >/dev/null 2>&1; then
  DMGBUILD_BIN="$(command -v dmgbuild)"
else
  for candidate in \
    "$HOME/Library/Python/3.9/bin/dmgbuild" \
    "$HOME/Library/Python/3.10/bin/dmgbuild" \
    "$HOME/Library/Python/3.11/bin/dmgbuild" \
    "$HOME/Library/Python/3.12/bin/dmgbuild" \
    "$HOME/Library/Python/3.13/bin/dmgbuild"
  do
    if [[ -x "$candidate" ]]; then
      DMGBUILD_BIN="$candidate"
      break
    fi
  done
fi

if [[ -n "$DMGBUILD_BIN" && -f "$DMG_SETTINGS" && -f "$DMG_BG_TIFF" ]]; then
  echo "==> Building branded DMG with dmgbuild"
  "$DMGBUILD_BIN" \
    -s "$DMG_SETTINGS" \
    -D "app=$APP" \
    -D "background=$DMG_BG_TIFF" \
    "$VOL_NAME" \
    "$DMG"
else
  echo "==> Fallback plain DMG (install dmgbuild for branded window: pip3 install --user dmgbuild)"
  STAGE="$DIST/dmg-stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  ditto "$APP" "$STAGE/$APP_NAME"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null
  rm -rf "$STAGE"
fi

cp -f "$DMG" "$DMG_STABLE"

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
