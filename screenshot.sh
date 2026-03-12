#!/usr/bin/env bash

# --- CONTROL DE INSTANCIAS (EL CANDADO) ---
# Abrimos el canal 9 y le ponemos un candado. Si ya está bloqueado, el script sale.
exec 9> /tmp/screenshot_lock
if ! flock -n 9; then
    exit 0
fi
# ------------------------------------------

# ¡EL SALVAVIDAS! Esto garantiza que el congelamiento se destruya siempre al salir.
trap 'pkill -9 hyprpicker 2>/dev/null' EXIT

MODE=${1:-region}

ID=$(date +%s%N)
TMP_FILE="/tmp/screenshot_${ID}.png"

# --- MAGIA DEL FREEZE ---
pkill -9 hyprpicker 2>/dev/null
hyprpicker -r -z &
sleep 0.2
# ------------------------

case "$MODE" in
    "region")
        GEOMETRY=$(slurp)
        TITLE="📸 Región Capturada"
        ;;
    "output")
        GEOMETRY=$(slurp -o)
        TITLE="📸 Pantalla Capturada"
        ;;
    "window")
        GEOMETRY=$(hyprctl clients -j | jq -r '.[] | select(.hidden==false) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp)
        TITLE="📸 Ventana Capturada"
        ;;
    *)
        GEOMETRY=$(slurp)
        TITLE="📸 Región Capturada"
        ;;
esac

# Si cancelaste con ESC, slurp devuelve vacío. El script sale y el 'trap' descongela.
if [ -z "$GEOMETRY" ]; then
    exit 0
fi

# Tomamos la captura usando las coordenadas exactas
grim -g "$GEOMETRY" "$TMP_FILE"

# Descongelamos inmediatamente apenas se toma la foto
pkill -9 hyprpicker 2>/dev/null

# ABRIMOS EL CANDADO: Cerramos el canal 9 para que puedas tomar otra captura
# incluso si la notificación actual todavía está en pantalla.
exec 9>&-

if [ ! -s "$TMP_FILE" ]; then
    exit 0
fi

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FINAL_FILE="$DIR/satty-$(date '+%Y%m%d-%H%M%S').png"

ACTION=$(notify-send -u low -i "$TMP_FILE" \
    "$TITLE" \
    "<i> ¿Qué quieres hacer?</i>" \
    --action="edit=  ✏️"\
    --action="copy= 📋"\
    --action="save= 💾" -t 60000)

case "$ACTION" in
    "edit")
        satty --filename "$TMP_FILE" \
              --output-filename "$FINAL_FILE" \
              --early-exit
              
        if [ -f "$FINAL_FILE" ]; then
            wl-copy -t image/png < "$FINAL_FILE"
            notify-send -u low -i "$FINAL_FILE" "📸 Edición Guardada" "<i>En ~/Pictures/Screenshots y portapapeles</i>" -t 2000 
        fi
        ;;
        
    "copy")
        wl-copy -t image/png < "$TMP_FILE"
        notify-send -u low -i "$TMP_FILE" "📋 Copiada" "<i>Imagen copiada al portapapeles</i>" -t 2000
        ;;
        
    "save")
        cp "$TMP_FILE" "$FINAL_FILE"
        notify-send -u low -i "$FINAL_FILE" "💾 Guardada" "<i>Imagen guardada en ~/Pictures/Screenshots</i>" -t 2000
        ;;
esac

rm -f "$TMP_FILE"
