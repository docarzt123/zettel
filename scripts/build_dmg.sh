#!/usr/bin/env bash
# Packt dist/Zettel.app in dist/Zettel.dmg (Drag-nach-Applications).
# Nutzt create-dmg, wenn vorhanden, sonst hdiutil.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/Zettel.app"
DMG="dist/Zettel.dmg"
[ -d "$APP" ] || { echo "❌ $APP fehlt — erst ./build.sh"; exit 1; }
rm -f "$DMG"

if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "Zettel" \
    --window-pos 200 120 --window-size 560 360 --icon-size 110 \
    --icon "Zettel.app" 150 160 --app-drop-link 410 160 \
    --hide-extension "Zettel.app" --no-internet-enable \
    "$DMG" "$APP"
else
  STAGE="dist/dmgstage"
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "Zettel" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
fi

# DMG selbst mitsignieren, wenn eine Identität da ist (sonst Ad-hoc).
IDENT="${MACOS_SIGN_IDENTITY:-}"
[ -z "$IDENT" ] && IDENT="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"
codesign --force --sign "${IDENT:--}" "$DMG"

echo "✅ $DMG ($(du -sh "$DMG" | cut -f1))"
