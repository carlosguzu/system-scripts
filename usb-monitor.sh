#!/usr/bin/env bash

# Ruta de tu sonido
SOUND_FILE="/home/carlosg/Downloads/sounds/47313572-ui-navigation-sound-270299.mp3"

# ==========================================
# 1. FUNCIÓN PARA MONITOREAR LA BATERÍA
# ==========================================
monitor_battery() {
    local low_notified=0
    local full_notified=0

    while true; do
        # Buscamos la carpeta de la batería (suele ser BAT0 o BAT1)
        BATTERY_DIR=$(ls -d /sys/class/power_supply/BAT* | head -n 1 2>/dev/null)
        
        # Si encuentra una batería, leemos su estado
        if [[ -n "$BATTERY_DIR" ]]; then
            CAPACITY=$(cat "$BATTERY_DIR/capacity")
            STATUS=$(cat "$BATTERY_DIR/status") # Puede ser: Charging, Discharging, Full

            # Lógica para batería baja (15% o menos)
            if [[ "$STATUS" == "Discharging" && "$CAPACITY" -le 15 ]]; then
                if [[ "$low_notified" -eq 0 ]]; then
                    # -u critical hace que la notificación sea urgente (suele saltarse el "No Molestar")
                    notify-send -u critical "⚠️ Batería Baja" "Te queda $CAPACITY%. ¡Conecta el cargador!"
                    pw-play "$SOUND_FILE" &
                    low_notified=1
                fi
                full_notified=0 # Reseteamos la alerta de carga completa
                
            # Lógica para batería llena (100%)
            elif [[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]]; then
                low_notified=0 # Reseteamos la alerta de batería baja porque ya se conectó
                
                if [[ "$CAPACITY" -eq 100 && "$full_notified" -eq 0 ]]; then
                    notify-send "✅ Batería Llena" "La carga está al 100%. Puedes desconectar." -t 5000
                    pw-play "$SOUND_FILE" &
                    full_notified=1
                elif [[ "$CAPACITY" -lt 100 ]]; then
                    full_notified=0
                fi
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

            # Evaluamos si fue conexión o desconexión
            if [[ "$action" == "add" ]]; then
                notify-send "🔌 USB Conectado" "$device_name" -t 3000
                pw-play "$SOUND_FILE" &

            elif [[ "$action" == "remove" ]]; then
                notify-send "🔌 USB Desconectado" "$device_name" -t 3000
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
