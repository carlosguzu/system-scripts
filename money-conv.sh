#!/usr/bin/env bash

current_date=$(date +"%Y-%m-%dT00:00:00.000")
data=$(curl -s "https://www.datos.gov.co/resource/32sa-8pi3.json?vigenciadesde=${current_date}")
trm=$(echo "$data" | jq -r '.[0].valor')

if [ -z "$trm" ] || [ "$trm" == "null" ]; then
    notify-send -u critical "Error de Conversor" "No se pudo obtener la TRM de hoy." -t 5000
    exit 1
fi

opcion=$(printf "USD a COP\nCOP a USD" | rofi -dmenu -p "TRM hoy: $trm" -theme-str 'window {width: 200px;} mainbox {children: [inputbar, listview];} inputbar {children: [prompt];} listview {lines: 2;}' -i)

if [ -z "$opcion" ]; then
    exit 0
fi

cifra=$(rofi -dmenu -p "Valor ($opcion):" -theme-str 'window {width: 300px;} mainbox {children: [inputbar];} inputbar {children: [prompt, entry];} entry {placeholder: "";}' < /dev/null)
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

notify-send -i "/home/carlosg/nixos-dotfiles/icons/conversion.png" "Calculadora de Divisas" "$mensaje" -t 10000
