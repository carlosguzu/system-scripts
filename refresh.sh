#!/usr/bin/env bash

hyprctl reload

# 2. Extraer y aplicar cursor dinámico
THEME=$(grep 'cursor-theme=' ~/.local/share/nwg-look/gsettings | cut -d '=' -f 2)
SIZE=$(grep 'cursor-size=' ~/.local/share/nwg-look/gsettings | cut -d '=' -f 2)

hyprctl setcursor "$THEME" "$SIZE"
hyprctl setenv HYPRCURSOR_THEME "$THEME"
hyprctl setenv HYPRCURSOR_SIZE "$SIZE"
hyprctl setenv XCURSOR_THEME "$THEME"
hyprctl setenv XCURSOR_SIZE "$SIZE"

# 3. Reiniciar Waybar para que tome el nuevo CSS
pkill waybar
waybar &

pkill swayosd-server
swayosd-server &

notify-send "Configuración recargada" -t 2000
