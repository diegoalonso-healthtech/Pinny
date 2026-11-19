#!/usr/bin/env bash
# Desinstala Pinny de este Mac.
#
# Uso:  ./scripts/uninstall.sh [--purge] [--yes]
#   --purge   borra también tu historial, pines, carpetas y ajustes
#   --yes     no pide confirmación
#
# Sin --purge se conservan tus datos (~/Library/Application Support/Pinny),
# por si vuelves a instalar Pinny más adelante.
set -euo pipefail

BUNDLE_ID="app.pinny.Pinny"
PURGE=0
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help)
            sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Opción desconocida: $arg" >&2
            exit 1
            ;;
    esac
done

if [ "$ASSUME_YES" -eq 0 ]; then
    if [ "$PURGE" -eq 1 ]; then
        echo "Se desinstalará Pinny y se BORRARÁN tu historial, pines, carpetas y ajustes."
    else
        echo "Se desinstalará Pinny. Tus datos se conservarán."
    fi
    read -r -p "¿Continuar? [s/N] " answer
    case "$answer" in
        s|S|si|SI|sí|Sí) ;;
        *) echo "Cancelado."; exit 0 ;;
    esac
fi

# 1. Cerrar la app si está abierta
# (solo si está en ejecución, para que macOS no pregunte «¿Dónde está Pinny?»)
if pgrep -x Pinny >/dev/null 2>&1; then
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    sleep 1
    killall Pinny >/dev/null 2>&1 || true
fi

# 2. Borrar la app (rutas fijas, nunca variables externas)
for app in "/Applications/Pinny.app" "$HOME/Applications/Pinny.app"; do
    if [ -d "$app" ]; then
        rm -rf "$app"
        echo "Eliminada: $app"
    fi
done

# 3. Quitar los permisos de Accesibilidad y Monitorización de entrada
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true

# 4. Refrescar los Servicios para que desaparezcan los de Pinny
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true

# 5. Que la guía de bienvenida vuelva a salir si se reinstala
defaults delete "$BUNDLE_ID" welcomeGuideVersionSeen >/dev/null 2>&1 || true

# 6. Datos del usuario (solo con --purge)
if [ "$PURGE" -eq 1 ]; then
    rm -rf "$HOME/Library/Application Support/Pinny"
    rm -rf "$HOME/Library/Caches/$BUNDLE_ID"
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "Datos y ajustes borrados."
else
    echo "Tus datos se conservan en: ~/Library/Application Support/Pinny"
    echo "Para borrarlos también: ./scripts/uninstall.sh --purge"
fi

echo "Pinny desinstalado."
echo "Si activaste «Abrir al iniciar sesión», comprueba que ya no aparece en"
echo "Ajustes del Sistema → General → Elementos de inicio y extensiones."
