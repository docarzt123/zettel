#!/usr/bin/env bash
# Signiert Zettel.app.
#   $MACOS_SIGN_IDENTITY gesetzt          → damit (CI)
#   sonst Developer ID im Schlüsselbund   → damit (lokal auf Marcs Mac)
#   sonst                                 → Ad-hoc
# Developer-ID-Signaturen bekommen Hardened Runtime + Zeitstempel, damit
# die App notarisierbar ist.
set -euo pipefail
APP="${1:?Pfad zur .app fehlt}"

IDENT="${MACOS_SIGN_IDENTITY:-}"
if [ -z "$IDENT" ]; then
  IDENT="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"
fi

if [ -z "$IDENT" ]; then
  echo "ℹ️  Keine Developer-ID gefunden → Ad-hoc-Signatur"
  codesign --force --deep --sign - "$APP"
  exit 0
fi

echo "🔏 Signiere mit: $IDENT"
codesign --force --deep --timestamp --options runtime --sign "$IDENT" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "✅ Signatur ok"
