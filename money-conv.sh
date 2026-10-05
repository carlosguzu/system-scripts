#!/usr/bin/env bash

# Caché diario de la TRM para no consultar la API cada vez
cache_file="/tmp/trm_cache_$(date +%Y-%m-%d)"

if [[ -f "$cache_file" ]]; then
    trm=$(cat "$cache_file")
else
    data=$(curl -s 'https://www.datos.gov.co/resource/32sa-8pi3.json?$limit=1&$order=vigenciadesde%20DESC')
    trm=$(echo "$data" | jq -r '.[0].valor')

    if [ -z "$trm" ] || [ "$trm" == "null" ]; then
        notify-send -u normal "Error de Conversor" "No se pudo obtener la TRM." -t 3000
        exit 1
    fi

    echo "$trm" > "$cache_file"
fi

# opcion=$(printf "USD a COP\nCOP a USD" | rofi -dmenu -p "TRM hoy: $trm" -theme-str 'window {width: 200px;} mainbox {children: [inputbar, listview];} inputbar {children: [prompt];} listview {lines: 2;}' -i)
opcion=$(printf "USD a COP\nCOP a USD" | fuzzel --dmenu --prompt="TRM hoy: $trm " --placeholder="" --lines=2 --width=30)

if [ -z "$opcion" ]; then
    exit 0
fi

# cifra=$(rofi -dmenu -p "Valor ($opcion):" -theme-str 'window {width: 300px;} mainbox {children: [inputbar];} inputbar {children: [prompt, entry];} entry {placeholder: "";}' < /dev/null)
cifra=$(echo "" | fuzzel --dmenu --prompt="Valor ($opcion): " --placeholder="" --lines=0 --width=30)
if [ -z "$cifra" ]; then
    exit 0
fi

cifra_limpia=$(echo "$cifra" | sed -E 's/[^0-9.]//g')

if [[ "$opcion" == "USD a COP" ]]; then
    resultado=$(awk "BEGIN {printf \"%.2f\", $cifra_limpia * $trm}")
    mensaje=" ${cifra_limpia} USD equivalen a  ${resultado} COP"
elif [[ "$opcion" == "COP a USD" ]]; then
    resultado=$(awk "BEGIN {printf \"%.2f\", $cifra_limpia / $trm}")
    mensaje=" ${cifra_limpia} COP equivalen a  ${resultado} USD"
fi

notify-send -i "/home/carlosg/nixos-dotfiles/img/conversion.png" "Calculadora de Divisas" "$mensaje" -t 10000
