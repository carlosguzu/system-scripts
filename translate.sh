#!/usr/bin/env bash

# 1. Capturar y limpiar
raw_text=$(wl-paste --primary || xclip -o -selection primary | tr -d '\n' | sed 's/^ *//;s/ *$//;s/  */ /g')
[ -z "$raw_text" ] && exit 1

encoded_text=$(echo "$raw_text" | jq -sRr @uri)
instancia="https://lingva.ml"
icono="/home/carlosg/nixos-dotfiles/img/translate.png"
historial="$HOME/Documents/translate-history.md"

# 2. Traducir
response=$(curl -s "$instancia/api/v1/auto/es/$encoded_text")
translation=$(echo "$response" | jq -r '.translation // empty')

[ -z "$translation" ] || [ "$translation" == "null" ] && exit 1

# 3. Guardar en el historial (Markdown)
FECHA=$(date +"%Y-%m-%d %H:%M")
echo "[$FECHA] **$raw_text**: $translation" >> "$historial"

# 4. Notificación (Instantánea)
word_en="$(echo "${raw_text:0:1}" | tr '[:lower:]' '[:upper:]')${raw_text:1}"
word_es="$(echo "${translation:0:1}" | tr '[:lower:]' '[:upper:]')${translation:1}"
word_es_wrapped=$(echo "$word_es" | fold -s -w 35)

notify-send -t 10000 -a "LingvaDict" -i "$icono" "$word_en" "$word_es_wrapped"

# 5. Audio (Método Perl que SÍ funciona)
(
  play_lingva_audio() {
    local lang=$1
    local text=$2
    curl -s -L -A "Mozilla/5.0" "$instancia/api/v1/audio/$lang/$(echo "$text" | jq -sRr @uri)" | \
    jq -r '.audio[]' | perl -ne 'print pack("C", $_)' | mpv - --no-terminal --volume=100
  }

  play_lingva_audio "es" "$translation"
  sleep 0.3
  play_lingva_audio "en" "$raw_text"
) &
