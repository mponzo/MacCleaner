#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/OpenCleanMyMac"
DIST="$ROOT/dist"
APP_NAME="MacCleaner.app"
APP="$DIST/$APP_NAME"
BIN_NAME="OpenCleanMyMac"
BUNDLE_ID="com.maccleaner.app"

echo "==> Building release binary"
cd "$PKG"
swift build -c release --product OpenCleanMyMac

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/$BIN_NAME"
test -x "$BIN"

echo "==> Assembling $APP_NAME"
rm -rf "$APP"
# Remove legacy packaged name if present
rm -rf "$DIST/Open Clean My Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$BIN_NAME"
chmod +x "$APP/Contents/MacOS/$BIN_NAME"

# SPM resource bundle (en.lproj / it.lproj Localizable.strings)
RESOURCE_BUNDLE="$BIN_DIR/${BIN_NAME}_${BIN_NAME}.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
else
  echo "warning: resource bundle not found at $RESOURCE_BUNDLE" >&2
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
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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

if command -v codesign >/dev/null 2>&1; then
  echo "==> Ad-hoc codesign"
  codesign --force --deep --sign - "$APP" || true
fi

echo "==> Done: $APP"
echo "Open it, then use Settings → Install to Applications"
echo "Or run: ./Scripts/install.sh"
