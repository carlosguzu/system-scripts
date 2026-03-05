#!/usr/bin/env bash

MODE=${1:-region}

if ! hyprshot -m "$MODE" --raw | wl-copy; then
    exit 0
fi

if ! wl-paste -t image/png > /dev/null 2>&1; then
    exit 0
fi

ID=$(date +%s%N)
TMP_FILE="/tmp/screenshot_${ID}.png"
wl-paste -t image/png > "$TMP_FILE"

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FINAL_FILE="$DIR/satty-$(date '+%Y%m%d-%H%M%S').png"

if [ "$MODE" == "window" ]; then
    TITLE="📸 Ventana Capturada"
elif [ "$MODE" == "output" ]; then
    TITLE="📸 Pantalla Capturada"
else
    TITLE="📸 Región Capturada"
fi

ACTION=$(notify-send -u low -i "$TMP_FILE" \
    "$TITLE" \
    "<i>Copiada al portapapeles.</i>" \
    --action="edit=✏️ Editar en Satty")

if [ "$ACTION" == "edit" ]; then
    
    satty --filename "$TMP_FILE" \
          --output-filename "$FINAL_FILE" \
          --early-exit
          
    if [ -f "$FINAL_FILE" ]; then
        wl-copy -t image/png < "$FINAL_FILE"
        notify-send -u low -i "$FINAL_FILE" "📸 Edición Guardada" "<i>En ~/Pictures/Screenshots y portapapeles</i>"
    fi
fi

rm -f "$TMP_FILE"
