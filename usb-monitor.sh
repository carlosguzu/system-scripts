#!/usr/bin/env bash

# Ruta de tu sonido
SOUND_FILE="/home/carlosg/Downloads/sounds/47313572-ui-navigation-sound-270299.mp3"

# ==========================================
# 1. FUNCIÓN PARA MONITOREAR LA BATERÍA
# ==========================================
monitor_battery() {
    # Nivel de brillo al que bajará cuando llegue al 7%
    local BRIGHTNESS_LOW="10%"
    
    # Variables de control (Sistema Anti-Spam)
    local NOTIFIED_100=false
    local NOTIFIED_7=false

    while true; do
        # Buscamos la carpeta de la batería (suele ser BAT0 o BAT1)
        BATTERY_DIR=$(ls -d /sys/class/power_supply/BAT* | head -n 1 2>/dev/null)
        
        # Si encuentra una batería, leemos su estado
        if [[ -n "$BATTERY_DIR" ]]; then
            CAPACITY=$(cat "$BATTERY_DIR/capacity")
            STATUS=$(cat "$BATTERY_DIR/status")

            # ==========================================
            # CASO 1: BATERÍA AL 100% (Y NO DESCARGANDO)
            # ==========================================
            if [ "$CAPACITY" -eq 100 ] && [ "$STATUS" != "Discharging" ]; then
                if [ "$NOTIFIED_100" = false ]; then
                    notify-send -u normal -t 5000 "🔋 Batería al 100%" "<i>Por favor, desconecta el cargador.</i>"
                    pw-play "$SOUND_FILE" &
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
                    pw-play "$SOUND_FILE" &
                    NOTIFIED_7=true
                fi
            elif [ "$CAPACITY" -gt 7 ] && [ "$STATUS" == "Charging" ]; then
                NOTIFIED_7=false
            fi
        fi

        # Esperamos 60 segundos antes de volver a chequear el porcentaje
        sleep 60
    done
}

# Iniciamos el monitor de batería en segundo plano
monitor_battery &

# ==========================================
# 2. MONITOR DE DISPOSITIVOS USB
# ==========================================
udevadm monitor --udev --property --subsystem-match=usb | while read -r line; do

    # Capturamos la acción (add o remove)
    if [[ "$line" == ACTION=* ]]; then
        action="${line#*=}"
    elif [[ "$line" == DEVTYPE=* ]]; then
        devtype="${line#*=}"

    # Capturamos el fabricante (con fallback por si se desconecta)
    elif [[ "$line" == ID_VENDOR_FROM_DATABASE=* ]]; then
        vendor="${line#*=}"
    elif [[ "$line" == ID_VENDOR=* && -z "$vendor" ]]; then
        vendor="${line#*=}"

    # Capturamos el modelo (con fallback por si se desconecta)
    elif [[ "$line" == ID_MODEL_FROM_DATABASE=* ]]; then
        model="${line#*=}"
    elif [[ "$line" == ID_MODEL=* && -z "$model" ]]; then
        model="${line#*=}"

    # Cuando la línea está vacía, procesamos el evento
    elif [[ -z "$line" ]]; then

        # Solo reaccionamos si es el dispositivo principal
        if [[ "$devtype" == "usb_device" ]]; then

            # Limpiamos el nombre
            device_name="$vendor $model"
            device_name="${device_name//_/ }"

            if [[ -z "${device_name// /}" ]]; then
                device_name="Dispositivo USB"
            fi

	    nombre_limpio=$(echo "$device_name" | sed -E 's/^[0-9]+\s*//') 

            # Evaluamos si fue conexión o desconexión
            if [[ "$action" == "add" ]]; then
                notify-send "🔌 USB Conectado" "$nombre_limpio" -t 3000
                pw-play "$SOUND_FILE" &

            elif [[ "$action" == "remove" ]]; then
                notify-send "🔌 USB Desconectado" "$nombre_limpio" -t 3000
                pw-play "$SOUND_FILE" &
            fi
        fi

        # Reseteamos las variables
        action=""
        devtype=""
        vendor=""
        model=""
    fi
done
