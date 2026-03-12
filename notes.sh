#!/usr/bin/env bash

notes_dir="${HOME}/Notes"
terminal="foot"
editor="vim"
opcion_crear="➕ Crear nueva nota"

mkdir -p "$notes_dir"

selected=$({ echo "$opcion_crear"; ls -1t "$notes_dir" 2>/dev/null; } | rofi -dmenu -i -p "📝 Note" -theme-str 'window { width: 600px; } listview { lines: 5; fixed-height: true; scrollbar: true; } element-icon { size: 80px; }')

if [ $? -ne 0 ]; then
        exit 0
fi

if [ "$selected" = "$opcion_crear" ] || [ -z "$selected" ]; then 
        filename="$(date +"%Y-%m-%d_%H-%M-%S").md"
else 
        # Si escribiste un nombre con extensión (ej. apunte.txt)
        if [[ "$selected" == *.* ]]; then 
                filename="$selected"
        # Si escribiste un nombre sin extensión (ej. mi_apunte)
        else 
                filename="${selected}.md"
        fi
fi

file_path="$notes_dir/$filename"

$terminal -a "notas-flotantes" -- $editor "$file_path"
