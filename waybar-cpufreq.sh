#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_cpufreq_state"

# Si el archivo no existe, arrancamos asumiendo que está en automático
if [ ! -f "$STATE_FILE" ]; then
    echo "auto" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

toggle_mode() {
    if [ "$STATE" == "auto" ]; then
        # De Auto -> Pasamos a Rendimiento forzado
        sudo auto-cpufreq --force=performance
        echo "performance" > "$STATE_FILE"
        notify-send "⚡ Modo Rendimiento" "Potencia máxima forzada." -t 2500
    elif [ "$STATE" == "performance" ]; then
        # De Rendimiento -> Pasamos a Ahorro forzado
        sudo auto-cpufreq --force=powersave
        echo "powersave" > "$STATE_FILE"
        notify-send "🍃 Modo Ahorro" "Ahorro extremo forzado." -t 2500
    else
        # De Ahorro -> Volvemos a Automático
        sudo auto-cpufreq --force=reset
        echo "auto" > "$STATE_FILE"
        notify-send "⚖️  Modo Automático" "Gestión inteligente restaurada." -t 2500
    fi

    # Refrescar Waybar
    pkill -RTMIN+8 waybar
}

print_status() {
    if [ "$STATE" == "performance" ]; then
        echo "{\"text\": \"\", \"tooltip\": \"Modo: Rendimiento (Forzado)\", \"class\": \"performance\"}"
    elif [ "$STATE" == "powersave" ]; then
        echo "{\"text\": \"\", \"tooltip\": \"Modo: Ahorro (Forzado)\", \"class\": \"power-saver\"}"
    else
        echo "{\"text\": \"\", \"tooltip\": \"Modo: Automático inteligente\", \"class\": \"balanced\"}"
    fi
}

if [ "$1" == "--toggle" ]; then
    toggle_mode
else
    print_status
fi
