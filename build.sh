#!/usr/bin/env bash
# Baut Zettel.app (universal: Apple Silicon + Intel), signiert sie und
# legt sie standardmäßig nach /Applications.
#
#   ./build.sh                 bauen + signieren + nach /Applications kopieren + starten
#   ./build.sh --no-install    nur bauen + signieren (CI)
#
# Signatur: nimmt $MACOS_SIGN_IDENTITY, sonst die erste „Developer ID
# Application"-Identität im Schlüsselbund, sonst Ad-hoc.
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=1
[ "${1:-}" = "--no-install" ] && INSTALL=0

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NO="$(date +%Y%m%d%H%M)"
APP="dist/Zettel.app"
MIN_OS="13.0"

echo "🔨 Zettel $VERSION"
rm -rf build "$APP"
mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1) Kompilieren, ein Slice pro Architektur, dann zusammenkleben.
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 \
    -target "${ARCH}-apple-macos${MIN_OS}" \
    -framework AppKit -framework Carbon -framework ServiceManagement \
    -framework UniformTypeIdentifiers \
    -o "build/Zettel-$ARCH" Sources/*.swift
done
lipo -create build/Zettel-arm64 build/Zettel-x86_64 -output "$APP/Contents/MacOS/Zettel"

# 2) Bundle-Dateien.
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NO/" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/de.lproj Resources/en.lproj "$APP/Contents/Resources/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# 3) Symbol rendern → .icns
ICONSET="build/Zettel.iconset"
mkdir -p "$ICONSET"
swift scripts/make_icon.swift build/icon-1024.png
for S in 16 32 128 256 512; do
  sips -z $S $S build/icon-1024.png --out "$ICONSET/icon_${S}x${S}.png" >/dev/null
  D=$((S * 2))
  sips -z $D $D build/icon-1024.png --out "$ICONSET/icon_${S}x${S}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Zettel.icns"

# 4) Signieren.
bash scripts/macos_sign.sh "$APP"

echo "✅ Gebaut: $APP"

# 5) Installieren + neu starten.
if [ "$INSTALL" = 1 ]; then
  pkill -x Zettel 2>/dev/null || true
  rm -rf "/Applications/Zettel.app"
  cp -R "$APP" /Applications/
  open -a "/Applications/Zettel.app"
  echo "🚀 /Applications/Zettel.app aktualisiert und gestartet"
fi
