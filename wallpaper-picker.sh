#!/usr/bin/env bash

THEME="fullscreen-preview"
WALLPAPER_DIR="/home/carlosg/nixos-dotfiles/img/wallpapers"
SYMLINK_FILE="$HOME/.cache/current_wallpaper"
SCREENLOCK_SYMLINK="$HOME/.cache/current_screenlock"


if [ -n "$1" ]; then
    # Menú secundario sin barra de búsqueda para elegir dónde aplicar la imagen
    opcion=$(printf "wallpaper\nscreenlock\nboth" | rofi -dmenu -p "Apply to:" -theme-str 'window {width: 250px;} mainbox {children: [inputbar, listview];} inputbar {children: [prompt];} listview {lines: 3;}' -i)

    # Si presionas Escape o cierras el menú sin elegir, el script se cancela
    if [ -z "$opcion" ]; then
        exit 0
    fi

    # Lógica para wallpaper o ambos
    if [ "$opcion" = "wallpaper" ] || [ "$opcion" = "both" ]; then
        # 1. Cambiar el fondo con swww (con tu transición fluida)
        swww img "$1" --transition-type grow --transition-pos top --transition-step 100 --transition-fps 60

        sleep 2.5

        # 2. Generar el esquema de colores con pywal16
        wal -i "$1" -n

        # 3. Crear (o sobrescribir) el enlace simbólico para Hyprland
        ln -sf "$1" "$SYMLINK_FILE"
    fi

    # Lógica para screenlock o ambos
    if [ "$opcion" = "screenlock" ] || [ "$opcion" = "both" ]; then
        # Crear (o sobrescribir) el enlace simbólico para Hyprlock
        ln -sf "$1" "$SCREENLOCK_SYMLINK"
    fi

    # Notificación final (adaptada para mostrar qué se actualizó)
    notify-send "New look!" "Applied to: $opcion" -i /home/carlosg/nixos-dotfiles/img/photo.png -t 3000

    exit 0
fi

# El autollamado de Rofi
rofi -modes "filebrowser" \
     -theme "$THEME" \
     -show filebrowser \
     -filebrowser-command "$0" \
     -filebrowser-directory "$WALLPAPER_DIR"
