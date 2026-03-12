#!/usr/bin/env bash

sleep 1


# 2. Obtener la hora actual (solo el número, ej: 08, 14, 21)
HOUR=$(date +%H)

# Eliminar ceros a la izquierda para evitar problemas matemáticos en bash (ej: 08 -> 8)
HOUR=${HOUR#0}

# 3. Elegir el mensaje en inglés dependiendo de la hora
if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 12 ]; then
    MESSAGE="Good morning, Carlos! Have a great day ahead."

elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then
    MESSAGE="Good afternoon, Carlos! Hope your day is going well."

elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 22 ]; then
    MESSAGE="Good evening, Carlos! Time to wind down."

else
    MESSAGE="Working late, Carlos? Make sure to get some rest!"
fi

# 4. Enviar la notificación al escritorio
notify-send "👋 Welcome back" "$MESSAGE"

# 1. Reproducir tu sonido en segundo plano

wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.1

pw-play /home/carlosg/Downloads/sounds/snorcon-high-battery-charge-421821.mp3 

wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.7

