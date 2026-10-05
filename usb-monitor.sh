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
#	    if { [ "$STATUS" = "Full" ] || [ "$CAPACITY" -ge 99 ]; } && [ "$STATUS" != "Discharging" ]; then
                if [ "$NOTIFIED_100" = false ]; then
                    notify-send -u normal -t 5000 "🔋 Batería llena" "<i>Por favor, desconecta el cargador.</i>"
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
                # Excluir pendrives (:08*) y dispositivos ADB (*ff4201*) para evitar notificaciones duplicadas
                if [[ "$usb_interfaces" != *:08* && "$usb_interfaces" != *ff4201* ]]; then
                    notify-send -i "$ICON_PATH" -t 3000 "Hardware Conectado" "$nombre_limpio" 2>/dev/null
                    pw-play "$SOUND_FILE" &
                fi 
            elif [[ "$action" == "remove" ]]; then
                # Si había un montaje adbfs y el dispositivo fue desconectado, desmontar limpiamente
                if grep -qs "fuse.adbfs" /proc/mounts; then
                    if ! adb devices 2>/dev/null | grep -qE "^\S+\s+device\b"; then
                        grep "fuse.adbfs" /proc/mounts | awk '{print $2}' | while read -r mnt; do
                            fusermount -u -z "$mnt" 2>/dev/null
                            rmdir "$mnt" 2>/dev/null
                        done
                    fi
                fi

                # Solución a tu observación: Si udev detecta remove, es porque ya se sacó físicamente.
                notify-send -i "$ICON_PATH" -t 3000 "Dispositivo Desconectado" "$nombre_limpio" 2>/dev/null
                pw-play "$SOUND_FILE" &
            fi
        fi

        # ==========================================
        # EVENTO B: AUTOMONTAJE DE ALMACENAMIENTO (USB / Discos)
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

        # ==========================================
        # EVENTO C: AUTOMONTAJE DE ANDROID (ADB / adbfs)
        # ==========================================
        if [[ "$subsystem" == "usb" && "$devtype" == "usb_device" && "$action" == "add" && "$usb_interfaces" == *ff4201* ]]; then
            (
                # Esperar hasta 4 segundos a que el daemon de adb detecte el dispositivo autorizado
                adb_device=""
                for i in {1..8}; do
                    adb_device=$(adb devices -l 2>/dev/null | grep -E "^\S+\s+device\b" | head -n 1)
                    [[ -n "$adb_device" ]] && break
                    sleep 0.5
                done

                if [[ -n "$adb_device" ]]; then
                    dev_id=$(echo "$adb_device" | awk '{print $1}')
                    raw_model=$(echo "$adb_device" | grep -o 'model:[^ ]*' | cut -d: -f2)
                    brand_name=$(echo "$raw_model" | cut -d_ -f1)
                    [[ -z "$brand_name" ]] && brand_name="Android"
                    
                    mount_point="$HOME/$brand_name"
                    mkdir -p "$mount_point"

                    # Montar almacenamiento interno (/sdcard) si no está montado
                    if ! grep -qs " $mount_point " /proc/mounts; then
                        if command -v adbfs >/dev/null 2>&1; then
                            adbfs -o nonempty,modules=subdir,subdir=/sdcard "$mount_point" 2>/dev/null
                        else
                            nix-shell -p adbfs-rootless --run "adbfs -o nonempty,modules=subdir,subdir=/sdcard '$mount_point'" 2>/dev/null
                        fi
                    fi

                    # Montar tarjeta MicroSD externa si existe
                    ext_sd=$(adb -s "$dev_id" shell ls /storage 2>/dev/null | tr -d '\r' | grep -vE '^(emulated|self|sdcard0|$)' | head -n 1)
                    if [[ -n "$ext_sd" ]]; then
                        sd_mount_point="$HOME/${brand_name}-SD"
                        mkdir -p "$sd_mount_point"
                        if ! grep -qs " $sd_mount_point " /proc/mounts; then
                            if command -v adbfs >/dev/null 2>&1; then
                                adbfs -o nonempty,modules=subdir,subdir="/storage/$ext_sd" "$sd_mount_point" 2>/dev/null
                            else
                                nix-shell -p adbfs-rootless --run "adbfs -o nonempty,modules=subdir,subdir='/storage/$ext_sd' '$sd_mount_point'" 2>/dev/null
                            fi
                        fi
                    fi

                    # Si el almacenamiento interno se montó con éxito, notificar con botón Abrir
                    if grep -qs " $mount_point " /proc/mounts; then
                        pw-play "$SOUND_FILE" &

                        if user_choice=$(notify-send -i "$ICON_PATH" -t 15000 -u normal \
                            "Almacenamiento Montado" \
                            "$mount_point" \
                            --action="open=📁 Abrir" 2>/dev/null) && [ "$user_choice" == "open" ]; then
                            foot -e yazi "$mount_point" >/dev/null 2>&1 & disown
                        fi
                    else
                        notify-send -i "$ICON_PATH" -t 3000 "Hardware Conectado" "$nombre_limpio" 2>/dev/null
                        pw-play "$SOUND_FILE" &
                    fi
                else
                    notify-send -i "$ICON_PATH" -t 3000 "Hardware Conectado" "$nombre_limpio" 2>/dev/null
                    pw-play "$SOUND_FILE" &
                fi
            ) &
        fi

        # Limpiamos las variables para el próximo dispositivo que conectes
        action=""; subsystem=""; devtype=""; devname=""; fs_type=""; label=""; model=""; vendor=""; usb_interfaces=""
    fi
done
