#!/bin/zsh
set -euo pipefail

# Signs MacCleaner with Developer ID, notarizes, staples, and refreshes the release zip.
# Prerequisites: docs/NOTARIZATION.md

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
RELEASES="$ROOT/releases"
APP_NAME="MacCleaner.app"
APP="$DIST/$APP_NAME"
ZIP="$RELEASES/MacCleaner.app.zip"
ENTITLEMENTS="$ROOT/packaging/MacCleaner.entitlements"
BUNDLE_ID="com.maccleaner.app"

# Optional local secrets file (never commit)
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

You currently have Development / Distribution (App Store) certs, but Gatekeeper
for downloadable .zip builds needs:

  Developer ID Application: <Your Name> (<Team ID>)

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

echo "==> Signing with: $IDENTITY"
codesign --force --deep --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP" 2>&1 || true

echo "==> Creating notarization zip"
mkdir -p "$RELEASES"
NOTARY_ZIP="$DIST/MacCleaner-notarize.zip"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"

submit_notary() {
  if [[ -n "${APPLE_API_KEY:-}" && -n "${APPLE_API_ISSUER:-}" && -n "${APPLE_API_KEY_PATH:-}" ]]; then
    echo "==> Notarytool (API key)"
    xcrun notarytool submit "$NOTARY_ZIP" \
      --key "$APPLE_API_KEY_PATH" \
      --key-id "$APPLE_API_KEY" \
      --issuer "$APPLE_API_ISSUER" \
      --wait
    return
  fi

  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    echo "==> Notarytool (keychain profile: $NOTARY_KEYCHAIN_PROFILE)"
    xcrun notarytool submit "$NOTARY_ZIP" \
      --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
      --wait
    return
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "==> Notarytool (Apple ID)"
    xcrun notarytool submit "$NOTARY_ZIP" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$TEAM_ID" \
      --wait
    return
  fi

  cat >&2 <<EOF
error: missing notarization credentials.

Option A — one-time keychain profile (recommended):
  xcrun notarytool store-credentials "maccleaner-notary" \\
    --apple-id "YOU@EMAIL" \\
    --team-id "$TEAM_ID" \\
    --password "app-specific-password"
  export NOTARY_KEYCHAIN_PROFILE=maccleaner-notary

Option B — env file .env.notarize (see .env.notarize.example)

Option C — App Store Connect API key:
  APPLE_API_KEY / APPLE_API_ISSUER / APPLE_API_KEY_PATH
EOF
  exit 1
}

submit_notary

echo "==> Stapling ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Gatekeeper check"
spctl --assess --type execute --verbose=4 "$APP"

echo "==> Refreshing release zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
rm -f "$NOTARY_ZIP"

echo "==> Done"
echo "Signed + notarized: $APP"
echo "Release zip:        $ZIP"
codesign -dv --verbose=4 "$APP" 2>&1 | rg 'Authority|TeamIdentifier|Timestamp' || true
