#!/usr/bin/env bash

# 1. Capturar palabra y limpiar
raw_word=$(wl-paste --primary || xclip -o -selection primary | tr -d '[:space:]')
[ -z "$raw_word" ] && exit 1

historial="$HOME/Documents/define-history.md"
icono="/home/carlosg/nixos-dotfiles/img/define.png"
word="$(echo "${raw_word:0:1}" | tr '[:lower:]' '[:upper:]')${raw_word:1}"

# 2. Query (Rápida)
query=$(curl -s "https://api.dictionaryapi.dev/api/v2/entries/en_US/$raw_word")

# 3. Extraer definición y Sinónimos (sin fonética)
def=$(echo "$query" | jq -r '
  .[0].meanings[0] as $m | 
  "(\($m.partOfSpeech)) \($m.definitions[0].definition)" + 
  (if $m.definitions[0].example then "\n\nExample: \"\($m.definitions[0].example)\"" else "" end) +
  (if ($m.synonyms | length > 0) then "\n\nSynonyms: " + ([$m.synonyms[0:3][]] | join(", ")) else "" end)
')

# 4. Audio Directo
audio_url=$(echo "$query" | jq -r '.[0].phonetics[] | select(.audio != "") | .audio' | head -n 1)

# 5. Notificación e Historial
if [ -z "$def" ] || [ "$def" == "null" ]; then
    notify-send -t 5000 -i "$icono" "$word" "Definition not found."
else
    # Notificar
    notify-send -t 10000 -i "$icono" "$word" "$def"

    # Guardar en Historial (Una sola línea por entrada)
    FECHA=$(date +"%Y-%m-%d %H:%M")
    echo "[$FECHA] **$word**: $def" | tr '\n' ' ' >> "$historial"
    echo "" >> "$historial"

    # Reproducir Audio
    if [ -n "$audio_url" ]; then
        [[ "$audio_url" == //* ]] && audio_url="https:$audio_url"
        mpv --no-video --volume=100 "$audio_url" > /dev/null 2>&1 &
    fi
fi
