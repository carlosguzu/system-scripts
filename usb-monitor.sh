#!/usr/bin/env bash

# Ruta de tu sonido
SOUND_FILE="/home/carlosg/nixos-dotfiles/sounds/47313572-ui-navigation-sound-270299.mp3"

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
# 2. MONITOR UNIVERSAL DE USB Y ALMACENAMIENTO
# ==========================================
ICON_PATH="/home/carlosg/nixos-dotfiles/img/usb.png"

# Ahora escuchamos a DOS subsistemas: usb (hardware general) y block (discos)
udevadm monitor --udev --property --subsystem-match=usb --subsystem-match=block | while read -r line; do

    # Captura de variables
    if [[ "$line" == ACTION=* ]]; then action="${line#*=}"; fi
    if [[ "$line" == SUBSYSTEM=* ]]; then subsystem="${line#*=}"; fi
    if [[ "$line" == DEVTYPE=* ]]; then devtype="${line#*=}"; fi
    if [[ "$line" == DEVNAME=* ]]; then devname="${line#*=}"; fi
    if [[ "$line" == ID_FS_TYPE=* ]]; then fs_type="${line#*=}"; fi
    if [[ "$line" == ID_FS_LABEL=* ]]; then label="${line#*=}"; fi
    if [[ "$line" == ID_MODEL=* && -z "$model" ]]; then model="${line#*=}"; fi
    if [[ "$line" == ID_MODEL_FROM_DATABASE=* ]]; then model="${line#*=}"; fi
    if [[ "$line" == ID_VENDOR=* && -z "$vendor" ]]; then vendor="${line#*=}"; fi
    if [[ "$line" == ID_VENDOR_FROM_DATABASE=* ]]; then vendor="${line#*=}"; fi
    if [[ "$line" == ID_USB_INTERFACES=* ]]; then usb_interfaces="${line#*=}"; fi

    # Procesar cuando termina el bloque de información del evento (línea vacía)
    if [[ -z "$line" ]]; then
        
        # Limpiar el nombre genérico del hardware
        device_name="$vendor $model"
        device_name="${device_name//_/ }"
        nombre_limpio=$(echo "$device_name" | sed -E 's/^[0-9]+\s*//' | xargs)
        [[ -z "$nombre_limpio" ]] && nombre_limpio="Dispositivo USB"

        # ==========================================
        # EVENTO A: HARDWARE FÍSICO (Mouse, Mando Xbox, Pendrive)
        # ==========================================
        if [[ "$subsystem" == "usb" && "$devtype" == "usb_device" ]]; then
            
            if [[ "$action" == "add" ]]; then
		if [[ "$usb_interfaces" != *:08* ]]; then
                	notify-send -i "$ICON_PATH" -t 3000 "Hardware Conectado" "$nombre_limpio" 2>/dev/null
                	pw-play "$SOUND_FILE" &
		fi 
            elif [[ "$action" == "remove" ]]; then
                # Solución a tu observación: Si udev detecta remove, es porque ya se sacó físicamente.
                notify-send -i "$ICON_PATH" -t 3000 "Dispositivo Desconectado" "$nombre_limpio" 2>/dev/null
                pw-play "$SOUND_FILE" &
            fi
        fi

# ==========================================
        # EVENTO B: AUTOMONTAJE DE ALMACENAMIENTO
        # ==========================================
        if [[ "$subsystem" == "block" && "$action" == "add" && -n "$fs_type" ]]; then
            
            nombre_usb="${label:-$nombre_limpio}"
            
            (
                mount_output=$(udisksctl mount -b "$devname" 2>/dev/null)
                
                if [[ $? -eq 0 ]]; then
                    mount_point=$(echo "$mount_output" | grep -o '/run/media/.*' | sed 's/\.$//')
                    
                    # Lanzamos la notificación y capturamos la salida DIRECTAMENTE en el IF
                    # Usamos -e para que la notificación sea "transient" (no se guarde en el historial si no quieres)
                    # Y redirigimos errores para que no ensucien la terminal
                    
		    pw-play "$SOUND_FILE" &

                    if user_choice=$(notify-send -i "$ICON_PATH" -t 15000 -u normal \
                        "Almacenamiento Montado" \
                        "$mount_point" \
                        --action="open=📁 Abrir" 2>/dev/null) && [ "$user_choice" == "open" ]; then
                        
                        # Ejecutamos con 'disown' para que la terminal se abra 
                        # independiente de la vida del script
                        foot -e yazi "$mount_point" >/dev/null 2>&1 & disown
                    fi
                fi
            ) &
        fi

        # Limpiamos las variables para el próximo dispositivo que conectes
        action=""; subsystem=""; devtype=""; devname=""; fs_type=""; label=""; model=""; vendor=""; usb_interfaces=""
    fi
done
