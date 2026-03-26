#!/usr/bin/env bash

# Rutas de caché
CACHE_DIR="$HOME/.cache"
CACHE_BAR="$CACHE_DIR/weather_bar"
CACHE_FULL="$CACHE_DIR/weather_full"

# Crear el directorio de caché si no existe
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

# 2. Intentar descargar formato corto
RAW_BAR=$(curl -sL --max-time 7 "wttr.in/Cartagena,Colombia?format=%c+%t+|+%C")

# Validamos que el servidor haya respondido con un clima real y no un texto de error
if [[ "$RAW_BAR" == *"°"* ]] || [[ "$RAW_BAR" == *"|"* ]]; then
    # Limpiamos el + y el espacio inicial
    CLEAN_BAR=$(echo "$RAW_BAR" | sed 's/+//; s/^ //')
    
    # Separamos el ícono, la temperatura y la descripción
    TEXT_PART=$(echo "$CLEAN_BAR" | cut -d'|' -f1 | xargs)
    TOOLTIP_PART=$(echo "$CLEAN_BAR" | cut -d'|' -f2 | xargs)
    
    ICON=$(echo "$TEXT_PART" | awk '{print $1}')
    TEMP=$(echo "$TEXT_PART" | awk '{print $2}')
    
    # Lógica Lunar: Verificamos si la hora local es entre las 18:00 y las 05:59
    HOUR=$(date +%H)
    if [ "$HOUR" -ge 18 ] || [ "$HOUR" -lt 6 ]; then
        # Si es de noche y el ícono original NO es de lluvia, tormenta o nieve, ponemos la luna
        if [[ ! "$ICON" == *"🌧"* ]] && [[ ! "$ICON" == *"☔"* ]] && [[ ! "$ICON" == *"⛈"* ]] && [[ ! "$ICON" == *"🌦"* ]] && [[ ! "$ICON" == *"❄"* ]]; then
            ICON=$(get_moon_phase)
        fi
    fi
    
    # Ensamblamos todo y lo guardamos
    echo "$ICON $TEMP | $TOOLTIP_PART" > "$CACHE_BAR"
else
    # Si falla el curl o hay error de renderizado de wttr.in, ponemos placeholder si no hay caché
    if [ ! -f "$CACHE_BAR" ]; then
        echo "❓ 0°C | Sin conexión" > "$CACHE_BAR"
    fi
fi

# 3. Intentar descargar formato completo para el click
curl -sL --max-time 7 "wttr.in/Cartagena,Colombia" > "$CACHE_FULL.tmp"

# Validar que el reporte completo no sea un error antes de sobreescribir
if [ -s "$CACHE_FULL.tmp" ] && grep -q "°" "$CACHE_FULL.tmp"; then
    mv "$CACHE_FULL.tmp" "$CACHE_FULL"
else
    if [ ! -f "$CACHE_FULL" ]; then
        echo "No se pudo cargar el pronóstico completo." > "$CACHE_FULL"
    fi
fi

# 4. Leer los archivos
INFO=$(cat "$CACHE_BAR")
TEXT=$(echo "$INFO" | cut -d'|' -f1 | xargs)
TOOLTIP=$(echo "$INFO" | cut -d'|' -f2 | xargs)

# Salida JSON para Waybar
echo "{\"text\":\"$TEXT\", \"tooltip\":\"$TOOLTIP\"}"
