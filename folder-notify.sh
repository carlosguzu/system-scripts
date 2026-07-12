#!/usr/bin/env bash

# --- PARCHE DE ENTORNO NIXOS ---
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
       [[ "$FILENAME" == *.tmp.* ]] || \
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
    
    # 2. Obtener MIME LIMPIO (quitando charsets como "; charset=binary")
    MIME=$(file -b --mime-type "$FILEPATH" 2>/dev/null | cut -d';' -f1 | tr -d ' ')
    if [ -z "$MIME" ] || [[ "$MIME" == *"cannot"* ]]; then
        MIME=$(xdg-mime query filetype "$FILEPATH" 2>/dev/null | cut -d';' -f1 | tr -d ' ')
    fi
    
    # 3. Determinar si es imagen
    IS_IMAGE=false
    if [[ "$MIME" == image/* ]] || [[ "$FILENAME" =~ \.(jpg|jpeg|png|gif|webp|svg)$ ]]; then
        ICON="$FILEPATH"
        IS_IMAGE=true
    else
        ICON="/home/carlosg/nixos-dotfiles/img/package.png"
    fi

    (
        NOTIFY_ARGS=(
            -a "KDE Connect"
            "Nuevo archivo recibido"
            "$FILENAME"
            -i "$ICON"
            --action="open=Abrir"
            --action="locate=Localizar"
        )
        
        if [ "$IS_IMAGE" = true ]; then
            NOTIFY_ARGS+=(--action="copy=Copiar")
        fi

        ACTION=$(notify-send "${NOTIFY_ARGS[@]}")
        
        case "$ACTION" in
            "open")
                EXT="${FILENAME##*.}"
                EXT_LOWER="${EXT,,}"
                
                # A. Buscar en Yazi por MIME
                BASE_MIME_ESCAPED="${MIME%/*}/\\*"
                RULE_LINE=$(grep -E "mime *= *\"($MIME|$BASE_MIME_ESCAPED)\"" "$YAZI_CONF" | head -n 1)
                
                # B. Si falla, buscar en Yazi por Extensión (ej: name = "*.pdf")
                if [ -z "$RULE_LINE" ]; then
                    RULE_LINE=$(grep -i -E "name *= *\"(\*\.$EXT_LOWER|\*\.$EXT)\"" "$YAZI_CONF" | head -n 1)
                fi
                
                # C. Ejecutar regla de Yazi si existe
                if [ -n "$RULE_LINE" ]; then
                    OPENER=$(echo "$RULE_LINE" | sed -E -n 's/.*use *= *(\[[^]]*\]|"[^"]*").*/\1/p' | grep -o '"[^"]*"' | head -n 1 | tr -d '"')
                    if [ -n "$OPENER" ]; then
                        CMD_TEMPLATE=$(awk -v op="$OPENER" '$0 ~ "^"op" *=" {flag=1} flag && /run *=/ {print; exit}' "$YAZI_CONF" | grep -o "'[^']*'" | head -n 1 | tr -d "'")
                        if [ -n "$CMD_TEMPLATE" ]; then
                            CMD="${CMD_TEMPLATE//\"\$@\"/\"$FILEPATH\"}"
                            CMD="${CMD//\"\$1\"/\"$FILEPATH\"}"
                            hyprctl dispatch exec "$CMD"
                            exit 0
                        fi
                    fi
                fi
                
                # D. FALLBACK INTELIGENTE (Adiós xdg-open a ciegas)
                # Si el archivo no está en tu Yazi, el script decide por sí mismo:
                case "$MIME" in
                    application/pdf)
                        hyprctl dispatch exec "okular \"$FILEPATH\"" ;;
                    video/*)
                        hyprctl dispatch exec "mpv \"$FILEPATH\"" ;;
                    text/*|application/json)
                        # Abre los textos y códigos en tu terminal con Vim
                        foot -e vim "$FILEPATH" & disown ;;
                    *)
                        xdg-open "$FILEPATH" & ;;
                esac
                ;;
                
            "locate")
                foot -e yazi "$WATCH_DIR" >/dev/null 2>&1 & disown
                ;;
                
            "copy")
                # Copia infalible inyectando los bytes con cat y el MIME exacto
                cat "$FILEPATH" | wl-copy -t "$MIME"
                notify-send -u low -a "KDE Connect" -i "$ICON" -t 2000 "📋 Copiado" "Imagen lista en el portapapeles"
                ;;
        esac
    ) &
done
