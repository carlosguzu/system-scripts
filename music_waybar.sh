#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_music_state"
COVER_FILE="/tmp/cover.png"
LAST_ART_URL=""

find_active_player() {
    PLAYERS=$(playerctl -l 2>/dev/null)
    if echo "$PLAYERS" | grep -q "spotify"; then
        if [ "$(playerctl -p spotify status 2>/dev/null)" = "Playing" ]; then
            echo "spotify"
            return
        fi
    fi
    for player in $PLAYERS; do
        [ "$player" = "spotify" ] && continue
        if [ "$(playerctl -p "$player" status 2>/dev/null)" = "Playing" ]; then
            echo "$player"
            return
        fi
    done
}

update_album_art() {
    PLAYER=$1
    ART_URL=$(playerctl -p "$PLAYER" metadata mpris:artUrl 2>/dev/null)

    if [ "$ART_URL" != "$LAST_ART_URL" ]; then
        LAST_ART_URL="$ART_URL"
        if [[ -z "$ART_URL" ]]; then
            rm -f "$COVER_FILE"
        elif [[ "$ART_URL" == file://* ]]; then
            cp "${ART_URL#file://}" "$COVER_FILE"
        elif [[ "$ART_URL" == http* ]]; then
            curl -s -o "$COVER_FILE" "$ART_URL" & 
        fi
    fi
}

while true; do
    ACTIVE_PLAYER=$(find_active_player)

    if [ -n "$ACTIVE_PLAYER" ]; then
        update_album_art "$ACTIVE_PLAYER"
        echo "playing" > "$STATE_FILE"
        
        FULL_INFO=$(playerctl -p "$ACTIVE_PLAYER" metadata --format "{{title}} - {{artist}}" 2>/dev/null)
        
        if [ ${#FULL_INFO} -gt 20 ]; then
            SHORT_INFO="$(echo "$FULL_INFO" | cut -c1-17)..."
        else
            SHORT_INFO="$FULL_INFO"
        fi

        TOOLTIP=$(echo "$FULL_INFO" | sed 's/"/\\"/g')
        echo "{\"text\": \"$SHORT_INFO\", \"class\": \"playing\", \"tooltip\": \"$TOOLTIP\"}"
        
        # Forzamos actualización de los módulos de la barra
        pkill -RTMIN+2 waybar 
        sleep 1
    else
        echo "hidden" > "$STATE_FILE"
        rm -f "$COVER_FILE"
        LAST_ART_URL=""
        
        echo "{\"text\": \"\", \"class\": \"hidden\"}"
        
        pkill -RTMIN+2 waybar 
        
        sleep 0.5
    fi
done
