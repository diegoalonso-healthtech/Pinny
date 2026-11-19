#!/usr/bin/env bash
# Compila Pinny y lo empaqueta como Pinny.app en ./build
#
# Firma: por defecto ad-hoc ("-"). Con ad-hoc, macOS pide de nuevo el permiso de
# Accesibilidad tras cada recompilación. Para evitarlo, crea un certificado de firma
# de código autofirmado en el Llavero y úsalo así:
#   SIGN_IDENTITY="Nombre de tu certificado" ./scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pinny"

APP="build/Pinny.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pinny"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Traducciones (inglés por defecto, español si el Mac está en español)
cp -R Resources/Localization/*.lproj "$APP/Contents/Resources/"

# Icono: en macOS se genera con iconutil desde el iconset (todos los tamaños);
# si no está disponible, se usa el .icns incluido en el repositorio.
if command -v iconutil >/dev/null 2>&1 && [ -d assets/AppIcon.iconset ]; then
    iconutil -c icns assets/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
else
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Listo: $APP (firma: $SIGN_IDENTITY)"
