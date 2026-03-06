#!/usr/bin/env bash

ICON_ON="󰛨"   
ICON_OFF="󰹏"  

case "$1" in
    toggle)
        
        if pgrep -x "hypridle" > /dev/null; then
            killall hypridle
            notify-send -t 6000 "󰛨 Modo Always-On: Activado" "No se bloqueará la pantalla"
        
        else
            hypridle &
            notify-send -t 6000 "󰹏 Modo Always-On: Desactivado" "Se bloqueará la pantalla si no hay actividad"
        fi
        ;;
    *)
        
        if pgrep -x "hypridle" > /dev/null; then
            
            echo "{\"text\": \"$ICON_OFF\", \"tooltip\": \"Always-On: Desactivado\nHypridle está controlando la pantalla\", \"class\": \"off\"}"
        else
            
            echo "{\"text\": \"$ICON_ON\", \"tooltip\": \"Always-On: Activado\nLa pantalla no se apagará\", \"class\": \"on\"}"
        fi
        ;;
esac
