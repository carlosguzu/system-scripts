#!/usr/bin/env bash

# --- PARCHE DE ENTORNO NIXOS ---
# Obliga a cargar las herramientas del sistema al arrancar desde Hyprland
export PATH="/run/current-system/sw/bin:/home/carlosg/.nix-profile/bin:/etc/profiles/per-user/carlosg/bin:$PATH"
# -------------------------------

WATCH_DIR="/home/carlosg/Downloads/KDEConnect"
YAZI_CONF="/home/carlosg/.config/yazi/yazi.toml"

mkdir -p "$WATCH_DIR"
declare -A NOTIFIED_FILES
LAST_FILE=""
LAST_TIME=0

inotifywait -m -e close_write --format "%f" "$WATCH_DIR" | while read -r FILENAME
do
    # 1. Ignorar temporales y archivos de bloqueo
    if [[ "$FILENAME" == *.part ]] || \
       [[ "$FILENAME" == *.tmp ]] || \
       [[ "$FILENAME" == .~* ]] || \
       [[ "$FILENAME" == ~$* ]] || \
       [[ "$FILENAME" == *.swx ]] || \
       [[ "$FILENAME" == *.swp ]]; then
        continue
    fi

    CURRENT_TIME=$(date +%s)
    if [[ "$FILENAME" == "$LAST_FILE" ]] && (( CURRENT_TIME - LAST_TIME < 2 )); then
        continue
    fi

    if [[ "${NOTIFIED_FILES["$FILENAME"]}" == "1" ]]; then
        continue
    fi

    LAST_FILE="$FILENAME"
    LAST_TIME=$CURRENT_TIME
    NOTIFIED_FILES["$FILENAME"]="1"
    
    FILEPATH="$WATCH_DIR/$FILENAME"
    
    # 2. Obtener MIME (con xdg-mime como respaldo por si falla file)
    MIME=$(file -b --mime-type "$FILEPATH" 2>/dev/null)
    if [ -z "$MIME" ] || [[ "$MIME" == *"cannot"* ]]; then
        MIME=$(xdg-mime query filetype "$FILEPATH" 2>/dev/null)
    fi
    
    if [[ "$MIME" == image/* ]] || [[ "$FILENAME" =~ \.(jpg|jpeg|png|gif|webp|svg)$ ]]; then
        ICON="$FILEPATH"
    else
        ICON="/home/carlosg/nixos-dotfiles/img/package.png"
    fi

    (
        ACTION=$(notify-send -a "KDE Connect" "Nuevo archivo recibido" "$FILENAME" \
            -i "$ICON" \
            --action="open=Abrir")
        
        if [ "$ACTION" == "open" ]; then
            BASE_MIME_ESCAPED="${MIME%/*}/\\*"
            
            # Buscamos en yazi.toml
            RULE_LINE=$(grep -E "mime *= *\"($MIME|$BASE_MIME_ESCAPED)\"" "$YAZI_CONF" | head -n 1)
            
            if [ -n "$RULE_LINE" ]; then
                # Usamos sed -E para máxima compatibilidad con las utilidades base
                OPENER=$(echo "$RULE_LINE" | sed -E -n 's/.*use *= *(\[[^]]*\]|"[^"]*").*/\1/p' | grep -o '"[^"]*"' | head -n 1 | tr -d '"')
                
                if [ -n "$OPENER" ]; then
                    CMD_TEMPLATE=$(awk -v op="$OPENER" '$0 ~ "^"op" *=" {flag=1} flag && /run *=/ {print; exit}' "$YAZI_CONF" | grep -o "'[^']*'" | head -n 1 | tr -d "'")
                    
                    if [ -n "$CMD_TEMPLATE" ]; then
                        CMD="${CMD_TEMPLATE//\"\$@\"/\"$FILEPATH\"}"
                        CMD="${CMD//\"\$1\"/\"$FILEPATH\"}"
                        
                        # Delegamos la ejecución a Hyprland para que el programa (como loupe) herede el entorno gráfico completo
                        hyprctl dispatch exec "$CMD"
                        exit 0
                    else
                        notify-send -u critical "Debug Yazi" "No encontró el comando 'run' de $OPENER"
                    fi
                else
                    notify-send -u critical "Debug Yazi" "No extrajo el programa de: $RULE_LINE"
                fi
            else
                notify-send -u critical "Debug Yazi" "El MIME '$MIME' no está configurado en tu yazi.toml"
            fi
            
            # Fallback seguro si todo lo de arriba falló
            xdg-open "$FILEPATH" &
        fi
    ) &
done
