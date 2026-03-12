#!/usr/bin/env bash

# Nivel de brillo al que bajará cuando llegue al 7%
BRIGHTNESS_LOW="10%"

# --- VARIABLES DE CONTROL (El sistema Anti-Spam) ---
NOTIFIED_100=false
NOTIFIED_7=false

# Buscar automáticamente la carpeta de la batería
BATTERY_DIR=$(ls -d /sys/class/power_supply/BAT* | head -n 1)

echo "🔋 Iniciando monitor de batería en: $BATTERY_DIR (Modo Silencioso)"

while true; do
    if [ -z "$BATTERY_DIR" ]; then
        sleep 60
        continue
    fi

    CAPACITY=$(cat "$BATTERY_DIR/capacity")
    STATUS=$(cat "$BATTERY_DIR/status")

    # ==========================================
    # CASO 1: BATERÍA AL 100% (Y NO DESCARGANDO)
    # ==========================================
    if [ "$CAPACITY" -eq 100 ] && [ "$STATUS" != "Discharging" ]; then
        if [ "$NOTIFIED_100" = false ]; then
            notify-send -u normal -t 5000 "🔋 Batería al 100%" "<i>Por favor, desconecta el cargador.</i>"
            NOTIFIED_100=true
        fi
    elif [ "$CAPACITY" -lt 100 ]; then
        NOTIFIED_100=false
    fi

    # ==========================================
    # CASO 2: BATERÍA AL 7% (Y DESCARGANDO)
    # ==========================================
    if [ "$CAPACITY" -le 7 ] && [ "$STATUS" == "Discharging" ]; then
        if [ "$NOTIFIED_7" = false ]; then
            notify-send -u critical -t 10000 "🪫 Batería Crítica ($CAPACITY%)" "<i>¡Conecta el cargador ahora! Bajando brillo...</i>"
            brightnessctl set "$BRIGHTNESS_LOW"
            NOTIFIED_7=true
        fi
    elif [ "$CAPACITY" -gt 7 ] && [ "$STATUS" == "Charging" ]; then
        NOTIFIED_7=false
    fi

    sleep 60
done
