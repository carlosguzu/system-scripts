#!/usr/bin/env bash

# Rutas de caché
CACHE_DIR="$HOME/.cache"
CACHE_BAR="$CACHE_DIR/weather_bar"
CACHE_FULL="$CACHE_DIR/weather_full"

mkdir -p "$CACHE_DIR"

# 1. Función para calcular la fase lunar matemáticamente
get_moon_phase() {
    local lp=2551443 # Segundos exactos en un ciclo lunar (29.53 días)
    local now=$(date +%s)
    local newmoon=1704974220 # Timestamp de referencia: Luna nueva (11 Ene 2024)
    local phase=$(( (now - newmoon) % lp ))
    local step=$(( phase * 8 / lp ))
    
    case $step in
        0) echo "🌑" ;; # Nueva
        1) echo "🌒" ;; # Creciente cóncava
        2) echo "🌓" ;; # Cuarto creciente
        3) echo "🌔" ;; # Creciente convexa
        4) echo "🌕" ;; # Llena
        5) echo "🌖" ;; # Menguante convexa
        6) echo "🌗" ;; # Cuarto menguante
        7) echo "🌘" ;; # Menguante cóncava
        *) echo "🌑" ;;
    esac
}

# 2. Función para mapear los códigos de clima de la WMO a emojis
get_icon() {
    local code=$1
    local is_day=$2

    # Si es de noche (is_day=0) y el código de clima es menor a 50 (no hay lluvia/nieve)
    if [ "$is_day" -eq 0 ] && [ "$code" -lt 50 ]; then
        get_moon_phase
        return
    fi

    # Si es de día, o si está lloviendo/nevando de noche, usamos los normales
    case $code in
        0) echo "☀️" ;;
        1|2|3) echo "⛅" ;;
        45|48) echo "🌫️" ;;
        51|53|55|56|57) echo "🌧️" ;;
        61|63|65|66|67) echo "☔" ;;
        71|73|75|77|85|86) echo "❄️" ;;
        80|81|82) echo "🌦️" ;;
        95|96|99) echo "⛈️" ;;
        *) echo "❓" ;;
    esac
}

get_condition_text() {
    case $1 in
        0) echo "Despejado" ;;
        1|2|3) echo "Nublado" ;;
        45|48) echo "Niebla" ;;
        51|53|55|56|57) echo "Llovizna" ;;
        61|63|65|66|67) echo "Lluvia" ;;
        71|73|75|77|85|86) echo "Nieve" ;;
        80|81|82) echo "Chubascos" ;;
        95|96|99) echo "Tormenta" ;;
        *) echo "Desconocido" ;;
    esac
}

# 3. Descargar datos de Open-Meteo
API_URL="https://api.open-meteo.com/v1/forecast?latitude=10.4195&longitude=-75.5271&current_weather=true&timezone=America%2FBogota"

curl -sL --max-time 7 "$API_URL" > "$CACHE_DIR/meteo_raw.json"

# 4. Procesar el JSON
if [ -s "$CACHE_DIR/meteo_raw.json" ] && grep -q "current_weather" "$CACHE_DIR/meteo_raw.json"; then
    
    RAW_TEMP=$(jq -r '.current_weather.temperature' "$CACHE_DIR/meteo_raw.json")
    CODE=$(jq -r '.current_weather.weathercode' "$CACHE_DIR/meteo_raw.json")
    # Extraemos si es de día o de noche (1 = día, 0 = noche)
    IS_DAY=$(jq -r '.current_weather.is_day' "$CACHE_DIR/meteo_raw.json")
    
    # Prevenir errores de Bash si jq falla al leer is_day
    IS_DAY=${IS_DAY:-1}
    
    # Truncar decimales
    TEMP=${RAW_TEMP%.*}
    
    # Pasamos el código y el estado del día a la función
    ICON=$(get_icon "$CODE" "$IS_DAY")
    COND_TEXT=$(get_condition_text "$CODE")
    
    TEXT="$ICON ${TEMP}°C"
    TOOLTIP="$COND_TEXT"
    
    echo "$TEXT|$TOOLTIP" > "$CACHE_BAR"
    
    echo "Clima en Cartagena, Colombia" > "$CACHE_FULL"
    echo "---------------------------" >> "$CACHE_FULL"
    echo "Estado: $COND_TEXT $ICON" >> "$CACHE_FULL"
    echo "Temperatura: ${TEMP}°C" >> "$CACHE_FULL"
else
    if [ -f "$CACHE_BAR" ]; then
        INFO=$(cat "$CACHE_BAR")
        TEXT=$(echo "$INFO" | cut -d'|' -f1)
        TOOLTIP=$(echo "$INFO" | cut -d'|' -f2)
    else
        TEXT="❓ Sin datos"
        TOOLTIP="Error de red"
        echo "No hay datos de clima guardados." > "$CACHE_FULL"
    fi
fi

# 5. Enviar salida a Waybar
echo "{\"text\":\"$TEXT\", \"tooltip\":\"$TOOLTIP\"}"
