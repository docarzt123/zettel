#!/usr/bin/env bash
# Notarisiert das DMG bei Apple und heftet das Ticket an.
# Braucht APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID. Fehlen sie, wird
# übersprungen (DMG bleibt un-notarisiert, Build bricht nicht).
set -euo pipefail
DMG="${1:?Pfad zum DMG fehlt}"

if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_APP_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
  echo "ℹ️  Notarisierungs-Secrets fehlen → überspringe $DMG"
  exit 0
fi

echo "📤 Notarisiere $DMG …"
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" \
  --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "✅ Notarisiert: $DMG"
