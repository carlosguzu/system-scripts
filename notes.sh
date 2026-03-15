#!/usr/bin/env bash

notes_dir="${HOME}/Notes"
terminal="foot"
editor="vim"
opcion_crear="➕ Crear nueva nota"

mkdir -p "$notes_dir"

# Función para manejar la creación de una nota nueva
nueva_nota() {
    # Menú secundario limpio para el nombre
    new_name=$(echo "" | rofi -dmenu -p "Nombre" -theme-str 'window { width: 400px; } listview { lines: 0; }')
    
    # Si presionas Esc, salimos limpiamente
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Magia de Bash: Si $new_name está vacío, se le asigna la fecha automáticamente
    : "${new_name:=$(date +"%Y-%m-%d_%H-%M-%S")}"

    # Si el nombre no tiene extensión, le agregamos .md
    if [[ "$new_name" != *.* ]]; then
        new_name="${new_name}.md"
    fi

    file_path="$notes_dir/$new_name"

    # setsid desconecta foot de rofi/bash, enviando la salida al vacío
    setsid -f $terminal -a "notas-flotantes" -- $editor "$file_path" >/dev/null 2>&1
}

# Función principal que lanza el menú inicial
menu_principal() {
    choice=$({ echo "$opcion_crear"; ls -1t "$notes_dir" 2>/dev/null; } | rofi -dmenu -i -p "📝 Note" -theme-str 'window { width: 600px; } listview { lines: 5; fixed-height: true; scrollbar: true; } element-icon { size: 80px; }')

    # Evaluamos la elección con un bloque case en lugar de múltiples ifs
    case "$choice" in
        "$opcion_crear")
            nueva_nota
            ;;
        "")
            # El usuario presionó Esc en el menú principal
            exit 0
            ;;
        *)
            # Si seleccionó una nota existente o escribió un nombre directo en el primer menú
            if [[ "$choice" != *.* ]]; then
                choice="${choice}.md"
            fi
            
            file_path="$notes_dir/$choice"
            
            # Lanzamos la nota existente de forma independiente
            setsid -f $terminal -a "notas-flotantes" -- $editor "$file_path" >/dev/null 2>&1
            ;;
    esac
}

# Ejecutamos la función principal
menu_principal
