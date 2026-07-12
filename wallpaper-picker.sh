#!/usr/bin/env bash

THEME="fullscreen-preview"
WALLPAPER_DIR="/home/carlosg/nixos-dotfiles/img/wallpapers"
SYMLINK_FILE="$HOME/.cache/current_wallpaper"
SCREENLOCK_SYMLINK="$HOME/.cache/current_screenlock"


if [ -n "$1" ]; then
    # Menú secundario sin barra de búsqueda para elegir dónde aplicar la imagen
    opcion=$(printf "Wallpaper\nScreenlock\nBoth" | rofi -dmenu -p "Apply to:" -theme-str 'window {width: 250px;} mainbox {children: [inputbar, listview];} inputbar {children: [prompt];} listview {lines: 3;}' -i)

    # Si presionas Escape o closes el menú sin elegir, el script se cancela
    if [ -z "$opcion" ]; then
        exit 0
    fi

    # OPCIÓN 1: Solo escritorio
    if [ "$opcion" = "Wallpaper" ]; then
        swww img "$1" --transition-type grow --transition-pos top --transition-step 100 --transition-fps 60
        sleep 2.5
        wal -i "$1" -n
        ln -sf "$1" "$SYMLINK_FILE"

	pkill waybar

	waybar &
    fi

    # OPCIÓN 2: Solo pantalla de bloqueo
    if [ "$opcion" = "Screenlock" ]; then
        ln -sf "$1" "$SCREENLOCK_SYMLINK"
        
        # 1. Generar los colores de la imagen elegida para el bloqueo
        wal -i "$1" -n
        # 2. Guardarlo en tu archivo independiente de lockscreen
        cp "$HOME/.cache/wal/colors-hyprland.conf" "$HOME/.cache/wal/colors-hyprland-lock.conf"
        
        # 3. Como pywal rompió los colores del escritorio, los restauramos usando el enlace actual
        if [ -L "$SYMLINK_FILE" ]; then
            wal -i "$(readlink -f "$SYMLINK_FILE")" -n
        fi
    fi

    # OPCIÓN 3: Ambos entornos
    if [ "$opcion" = "Both" ]; then
        swww img "$1" --transition-type grow --transition-pos top --transition-step 100 --transition-fps 60
        sleep 2.5
        wal -i "$1" -n
        ln -sf "$1" "$SYMLINK_FILE"
        ln -sf "$1" "$SCREENLOCK_SYMLINK"
        
        # Duplicamos el archivo para que tanto el escritorio como el lock tengan la misma paleta nueva
        cp "$HOME/.cache/wal/colors-hyprland.conf" "$HOME/.cache/wal/colors-hyprland-lock.conf"

	pkill waybar

	waybar &

    fi

    # Notificación final
    notify-send "New look!" "Applied to: $opcion" -i /home/carlosg/nixos-dotfiles/img/photo.png -t 3000

    exit 0
fi

# El autollamado de Rofi
rofi -modes "filebrowser" \
     -theme "$THEME" \
     -show filebrowser \
     -filebrowser-command "$0" \
     -filebrowser-directory "$WALLPAPER_DIR"
