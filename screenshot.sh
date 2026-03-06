#!/usr/bin/env bash

MODE=${1:-region}

ID=$(date +%s%N)
TMP_FILE="/tmp/screenshot_${ID}.png"

# --- MAGIA DEL FREEZE ---
# Iniciamos hyprpicker en modo silencioso (-r) y congelado (-z) en segundo plano (&)
hyprpicker -r -z &
PICKER_PID=$!
sleep 0.2 # Le damos una fracción de segundo para que la pantalla se congele
# ------------------------

case "$MODE" in
    "region")
        grim -g "$(slurp)" "$TMP_FILE"
        TITLE="📸 Región Capturada"
        ;;
    "output")
        grim -g "$(slurp -o)" "$TMP_FILE"
        TITLE="📸 Pantalla Capturada"
        ;;
    "window")
        # Le pasamos las coordenadas de todas las ventanas a slurp para que haga "imán"
        GEOMETRY=$(hyprctl clients -j | jq -r '.[] | select(.hidden==false) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp)
        grim -g "$GEOMETRY" "$TMP_FILE"
        TITLE="📸 Ventana Capturada"
        ;;
    *)
        grim -g "$(slurp)" "$TMP_FILE"
        TITLE="📸 Región Capturada"
        ;;
esac

# --- FIN DEL FREEZE ---
# Matamos el proceso de hyprpicker para descongelar la pantalla
if [ -n "$PICKER_PID" ]; then
    kill $PICKER_PID 2>/dev/null
fi
# ----------------------

# Si cancelaste con ESC, slurp falla y no se crea el temporal. Salimos limpiamente.
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
    --action="save= 💾" -t 10000)

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
