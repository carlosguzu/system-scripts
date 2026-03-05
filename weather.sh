#!/usr/bin/env bash

# Rutas de caché
CACHE_DIR="$HOME/.cache"
CACHE_BAR="$CACHE_DIR/weather_bar"
CACHE_FULL="$CACHE_DIR/weather_full"

# Crear el directorio de caché si no existe
mkdir -p "$CACHE_DIR"

# 1. Intentar descargar formato corto
# Añadimos -L por si hay redirecciones y quitamos las comillas extrañas
RAW_BAR=$(curl -sL --max-time 7 "wttr.in/Cartagena,Colombia?format=%c+%t+|+%C")

if [ -n "$RAW_BAR" ]; then
    # Limpiamos el + y el espacio inicial
    CLEAN_BAR=$(echo "$RAW_BAR" | sed 's/+//; s/^ //')
    echo "$CLEAN_BAR" > "$CACHE_BAR"
else
    # Si falla el curl y no hay caché, ponemos un placeholder
    if [ ! -f "$CACHE_BAR" ]; then
        echo "❓ 0°C | Sin conexión" > "$CACHE_BAR"
    fi
fi

# 2. Intentar descargar formato completo para el click
curl -sL --max-time 7 "wttr.in/Cartagena,Colombia" > "$CACHE_FULL.tmp"
if [ -s "$CACHE_FULL.tmp" ]; then
    mv "$CACHE_FULL.tmp" "$CACHE_FULL"
else
    if [ ! -f "$CACHE_FULL" ]; then
        echo "No se pudo cargar el pronóstico completo." > "$CACHE_FULL"
    fi
fi

# 3. Leer los archivos (ahora estamos seguros de que existen)
INFO=$(cat "$CACHE_BAR")
TEXT=$(echo "$INFO" | cut -d'|' -f1 | xargs) # xargs limpia espacios extras
TOOLTIP=$(echo "$INFO" | cut -d'|' -f2 | xargs)

# Salida JSON para Waybar
echo "{\"text\":\"$TEXT\", \"tooltip\":\"$TOOLTIP\"}"
