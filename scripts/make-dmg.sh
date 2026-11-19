#!/usr/bin/env bash
# Crea build/Pinny-<versión>.dmg con la típica ventana «Arrastra a Aplicaciones».
#
# Requisitos:
#   - Haber compilado antes: ./scripts/build-app.sh
#   - create-dmg (código abierto): brew install create-dmg
#     Sin create-dmg se crea un DMG sencillo, con el enlace a Aplicaciones pero sin fondo.
#
# La primera vez, macOS puede pedir permiso para que Terminal controle el Finder:
# create-dmg lo usa para colocar los iconos sobre el fondo.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Pinny.app"
if [ ! -d "$APP" ]; then
    echo "No existe $APP. Compila primero con ./scripts/build-app.sh" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Pinny-$VERSION.dmg"
rm -f "$DMG"

# Carpeta temporal solo con la app (create-dmg empaqueta una carpeta entera).
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"

if command -v create-dmg >/dev/null 2>&1; then
    # Fondo para pantallas normales y Retina en un solo TIFF.
    BG="build/dmg-background.tiff"
    tiffutil -cathidpicheck Resources/dmg-background.png Resources/dmg-background@2x.png -out "$BG"

    create-dmg \
        --volname "Pinny" \
        --background "$BG" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 128 \
        --text-size 13 \
        --icon "Pinny.app" 160 190 \
        --hide-extension "Pinny.app" \
        --app-drop-link 440 190 \
        "$DMG" \
        "$STAGE"
    rm -f "$BG"
else
    echo "create-dmg no está instalado: se crea un DMG sencillo sin fondo."
    echo "Para el DMG con fondo: brew install create-dmg"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "Pinny" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
fi

echo "Listo: $DMG"
