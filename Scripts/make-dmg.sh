#!/usr/bin/env bash
#
# Packages dist/MenuVibe.app into a distributable dist/MenuVibe.dmg with a drag-to-
# Applications layout. Run Scripts/build-app.sh first.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/MenuVibe.app"
DMG="$ROOT/dist/MenuVibe.dmg"
STAGE="$(mktemp -d)"

[[ -d "$APP" ]] || { echo "✗ $APP not found — run Scripts/build-app.sh first." >&2; exit 1; }

echo "▸ Staging DMG contents…"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "▸ Creating DMG…"
rm -f "$DMG"
hdiutil create -volname "MenuVibe" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ Built $DMG"
