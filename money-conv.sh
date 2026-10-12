#!/usr/bin/env bash

# Caché diario de tasas de cambio para no consultar las APIs en cada ejecución
cache_file="/tmp/divisas_cache_$(date +%Y-%m-%d).json"

if [[ -f "$cache_file" && -s "$cache_file" ]]; then
    trm_usd=$(jq -r '.USD // empty' "$cache_file" 2>/dev/null)
    trm_eur=$(jq -r '.EUR // empty' "$cache_file" 2>/dev/null)
    trm_gbp=$(jq -r '.GBP // empty' "$cache_file" 2>/dev/null)
    trm_mxn=$(jq -r '.MXN // empty' "$cache_file" 2>/dev/null)
fi

if [[ -z "$trm_usd" || -z "$trm_eur" || -z "$trm_gbp" || -z "$trm_mxn" ]]; then
    # Obtener TRM oficial de USD desde datos.gov.co
    data_trm=$(curl -s --max-time 5 'https://www.datos.gov.co/resource/32sa-8pi3.json?$limit=1&$order=vigenciadesde%20DESC')
    trm_usd=$(echo "$data_trm" | jq -r '.[0].valor // empty' 2>/dev/null)

    # Obtener tasas de cambio desde open.er-api.com
    data_rates=$(curl -s --max-time 5 'https://open.er-api.com/v6/latest/USD')
    eur_rate=$(echo "$data_rates" | jq -r '.rates.EUR // empty' 2>/dev/null)
    gbp_rate=$(echo "$data_rates" | jq -r '.rates.GBP // empty' 2>/dev/null)
    mxn_rate=$(echo "$data_rates" | jq -r '.rates.MXN // empty' 2>/dev/null)
    cop_rate=$(echo "$data_rates" | jq -r '.rates.COP // empty' 2>/dev/null)

    # Si la API de datos.gov.co falla, usar la tasa COP de open.er-api.com como respaldo
    if [[ -z "$trm_usd" || "$trm_usd" == "null" ]]; then
        trm_usd="$cop_rate"
    fi

    if [[ -z "$trm_usd" || -z "$eur_rate" || -z "$gbp_rate" || -z "$mxn_rate" ]]; then
        notify-send -u normal "Error de Conversor" "No se pudieron obtener las tasas de cambio." -t 3000
        exit 1
    fi

    trm_usd=$(awk "BEGIN {printf \"%.2f\", $trm_usd}")
    trm_eur=$(awk "BEGIN {printf \"%.2f\", $trm_usd / $eur_rate}")
    trm_gbp=$(awk "BEGIN {printf \"%.2f\", $trm_usd / $gbp_rate}")
    trm_mxn=$(awk "BEGIN {printf \"%.2f\", $trm_usd / $mxn_rate}")

    # Guardar en caché JSON
    jq -n \
        --arg usd "$trm_usd" \
        --arg eur "$trm_eur" \
        --arg gbp "$trm_gbp" \
        --arg mxn "$trm_mxn" \
        '{USD: $usd, EUR: $eur, GBP: $gbp, MXN: $mxn}' > "$cache_file"
fi

# Opciones a mostrar en fuzzel
menu_opciones=$(cat <<EOF
USD a COP  [$trm_usd COP]
COP a USD  [$trm_usd COP]
EUR a COP  [$trm_eur COP]
COP a EUR  [$trm_eur COP]
GBP a COP  [$trm_gbp COP]
COP a GBP  [$trm_gbp COP]
MXN a COP  [$trm_mxn COP]
COP a MXN  [$trm_mxn COP]
EOF
)

opcion=$(echo "$menu_opciones" | fuzzel --dmenu --prompt="Divisas: " --placeholder="" --lines=8 --width=32)

if [ -z "$opcion" ]; then
    exit 0
fi

# Extraer divisas de la opción seleccionada
read -r divisa_origen _ divisa_destino _ <<< "$opcion"

# Determinar tasa respecto a COP
if [[ "$divisa_origen" == "COP" ]]; then
    divisa_extranjera="$divisa_destino"
else
    divisa_extranjera="$divisa_origen"
fi

case "$divisa_extranjera" in
    USD) tasa="$trm_usd" ;;
    EUR) tasa="$trm_eur" ;;
    GBP) tasa="$trm_gbp" ;;
    MXN) tasa="$trm_mxn" ;;
    *)
        notify-send -u normal "Error de Conversor" "Divisa desconocida: $divisa_extranjera" -t 3000
        exit 1
        ;;
esac

cifra=$(echo "" | fuzzel --dmenu --prompt="Valor ($divisa_origen a $divisa_destino): " --placeholder="" --lines=0 --width=35)
if [ -z "$cifra" ]; then
    exit 0
fi

# Limpiar entrada (soporta comas o puntos decimales)
cifra_limpia=$(echo "$cifra" | tr ',' '.' | sed -E 's/[^0-9.]//g')

if [ -z "$cifra_limpia" ]; then
    exit 0
fi

if [[ "$divisa_origen" == "COP" ]]; then
    resultado=$(awk "BEGIN {printf \"%.2f\", $cifra_limpia / $tasa}")
    mensaje=" ${cifra_limpia} COP equivalen a  ${resultado} ${divisa_destino}"
else
    resultado=$(awk "BEGIN {printf \"%.2f\", $cifra_limpia * $tasa}")
    mensaje=" ${cifra_limpia} ${divisa_origen} equivalen a  ${resultado} COP"
fi

notify-send -i "/home/carlosg/nixos-dotfiles/img/conversion.png" "Calculadora de Divisas" "$mensaje" -t 10000
