#!/usr/bin/env bash

# 1. DBus: Necesario para que Hyprlock pueda hablar con las apps
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(/run/current-system/sw/bin/id -u)/bus"

PLAYERCTL="/run/current-system/sw/bin/playerctl"

# 2. Obtenemos la lista de todos los reproductores
PLAYERS=$($PLAYERCTL -l 2>/dev/null)

# Variable para guardar al que esté sonando
ACTIVE_PLAYER=""

# 3. El Bucle: Preguntamos uno por uno quién está sonando
for p in $PLAYERS; do
    if [ "$($PLAYERCTL -p "$p" status 2>/dev/null)" = "Playing" ]; then
        ACTIVE_PLAYER="$p"
        break # ¡Lo encontramos! Dejamos de buscar.
    fi
done

# 4. Decisión Final
if [ -n "$ACTIVE_PLAYER" ]; then
    # Si encontramos a alguien, pedimos la metadata A ESE reproductor específico (-p)
    $PLAYERCTL -p "$ACTIVE_PLAYER" metadata --format '{{title}}     {{artist}}' 2>/dev/null
else
    # Si nadie estaba sonando
    echo "󰝛  Nenio ludanta"
fi
