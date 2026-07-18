#!/usr/bin/env bash
#
# Assembles MenuVibe.app from the SwiftPM build product.
#
# Usage:
#   Scripts/build-app.sh [debug|release]      # build + bundle
#   CODESIGN_IDENTITY="Developer ID Application: You (TEAMID)" Scripts/build-app.sh release
#
# With no signing identity set, the app is left ad-hoc signed — fine for running
# locally, but you must sign + notarize with a Developer ID for distribution (see README).

set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP="$ROOT/dist/MenuVibe.app"

echo "▸ Building MenuVibe ($CONFIG)…"
swift build -c "$CONFIG" --package-path "$ROOT"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/MenuVibe" "$APP/Contents/MacOS/MenuVibe"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Bundle the app icon (CFBundleIconFile is already declared in Info.plist).
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "  (note: Resources/AppIcon.icns missing — run: swift Scripts/generate-appicon.swift && iconutil -c icns Design/AppIcon.iconset -o Resources/AppIcon.icns)"
fi

echo "▸ Signing…"
ENTITLEMENTS="$ROOT/Resources/MenuVibe.entitlements"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$CODESIGN_IDENTITY" "$APP"
  echo "  signed with: $CODESIGN_IDENTITY"
else
  # Ad-hoc signature so Accessibility permission persists across launches locally.
  codesign --force --deep --entitlements "$ENTITLEMENTS" --sign - "$APP"
  echo "  ad-hoc signed (set CODESIGN_IDENTITY to sign for distribution)"
fi

echo "✓ Built $APP"
