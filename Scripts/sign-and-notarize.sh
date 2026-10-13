#!/bin/zsh
set -euo pipefail

# Signs MacCleaner with Developer ID, notarizes app + DMG, staples, refreshes release artifacts.
# Prerequisites: docs/NOTARIZATION.md

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
RELEASES="$ROOT/releases"
APP_NAME="MacCleaner.app"
APP="$DIST/$APP_NAME"
ENTITLEMENTS="$ROOT/packaging/MacCleaner.entitlements"
CASK="$ROOT/Casks/maccleaner.rb"
RAW_BASE="https://github.com/mponzo/MacCleaner/raw/main/releases"

if [[ -f "$ROOT/.env.notarize" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env.notarize"
  set +a
fi

TEAM_ID="${APPLE_TEAM_ID:-T6EB446J72}"
IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
      | head -n 1
  )"
fi

if [[ -z "$IDENTITY" ]]; then
  cat >&2 <<EOF
error: no "Developer ID Application" certificate in the keychain.

Create it in: https://developer.apple.com/account/resources/certificates/list
  → "+" → Developer ID Application → download → double-click to install.

Then re-run: ./Scripts/sign-and-notarize.sh
EOF
  exit 1
fi

if [[ ! -d "$APP" ]]; then
  echo "==> App missing — packaging first"
  "$ROOT/Scripts/package-app.sh"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
ZIP="$RELEASES/MacCleaner-${VERSION}.zip"
DMG="$RELEASES/MacCleaner-${VERSION}.dmg"
ZIP_STABLE="$RELEASES/MacCleaner.app.zip"
DMG_STABLE="$RELEASES/MacCleaner.dmg"
VERSION_JSON="$RELEASES/version.json"

echo "==> Signing with: $IDENTITY (v${VERSION} #${BUILD})"
codesign --force --deep --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP" 2>&1 || true

submit_notary() {
  local artifact="$1"
  if [[ -n "${APPLE_API_KEY:-}" && -n "${APPLE_API_ISSUER:-}" && -n "${APPLE_API_KEY_PATH:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --key "$APPLE_API_KEY_PATH" \
      --key-id "$APPLE_API_KEY" \
      --issuer "$APPLE_API_ISSUER" \
      --wait
    return
  fi
  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
      --wait
    return
  fi
  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$TEAM_ID" \
      --wait
    return
  fi
  cat >&2 <<EOF
error: missing notarization credentials. See docs/NOTARIZATION.md
  export NOTARY_KEYCHAIN_PROFILE=maccleaner-notary
EOF
  exit 1
}

echo "==> Notarizing app"
NOTARY_ZIP="$DIST/MacCleaner-notarize.zip"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
submit_notary "$NOTARY_ZIP"
rm -f "$NOTARY_ZIP"

echo "==> Stapling app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP"

mkdir -p "$RELEASES"

echo "==> Building release zip + DMG"
rm -f "$ZIP" "$ZIP_STABLE" "$DMG" "$DMG_STABLE"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
cp -f "$ZIP" "$ZIP_STABLE"

STAGE="$DIST/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "MacCleaner ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Notarizing DMG"
submit_notary "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
cp -f "$DMG" "$DMG_STABLE"

DMG_SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

cat > "$VERSION_JSON" <<JSON
{
  "version": "${VERSION}",
  "build": ${BUILD},
  "zip_url": "${RAW_BASE}/MacCleaner-${VERSION}.zip",
  "dmg_url": "${RAW_BASE}/MacCleaner-${VERSION}.dmg",
  "notes": "Versioned DMG + zip installers; Homebrew cask support.",
  "notes_it": "Installer DMG e zip versionati; supporto Homebrew cask."
}
JSON

mkdir -p "$(dirname "$CASK")"
cat > "$CASK" <<RUBY
cask "maccleaner" do
  version "${VERSION}"
  sha256 "${DMG_SHA}"

  url "${RAW_BASE}/MacCleaner-#{version}.dmg"
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

echo "==> Done"
echo "Signed + notarized app: $APP"
echo "Zip: $ZIP"
echo "DMG: $DMG"
echo "Cask: $CASK"
codesign -dv --verbose=4 "$APP" 2>&1 | rg 'Authority|TeamIdentifier|Timestamp' || true
