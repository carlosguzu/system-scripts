#!/usr/bin/env bash



# 1. Capturar palabra y Capitalizar la primera letra
raw_word=$(wl-paste --primary || xclip -o -selection primary | tr -d '[:space:]')
[ -z "$raw_word" ] && exit 1
historial="$HOME/Documents/define-history.md"
# Poner en mayúscula: serendipity -> Serendipity
word="$(echo "${raw_word:0:1}" | tr '[:lower:]' '[:upper:]')${raw_word:1}"

# 2. Query
query=$(curl -s "https://api.dictionaryapi.dev/api/v2/entries/en_US/$raw_word")

# 3. Extraer solo la primera definición (limpia de caracteres raros)
# Usamos un filtro para asegurar que no haya saltos de línea extras que corten notify-send
def=$(echo "$query" | jq -r '
  .[0].meanings[0] as $m | 
  "(\($m.partOfSpeech)) \($m.definitions[0].definition) " + 
  (if $m.definitions[0].example then "\n\nExample: \"\($m.definitions[0].example)\"" else "" end)
' | xargs -0) # xargs -0 ayuda a limpiar el string para la notificación

# 4. Audio (con caché y buffer para evitar cortes)
audio_url=$(echo "$query" | jq -r '.[0].phonetics[] | select(.audio != "") | .audio' | head -n 1)




# 5. Ejecución
# Agregamos un icono de diccionario estándar si existe en tu sistema
notify-send -t 10000 -i /home/carlosg/nixos-dotfiles/icons/define.png  "$word" "$def"


FECHA=$(date +"%Y-%m-%d %H:%M")
echo "[$FECHA] **$raw_text**: $translation" >> "$historial"

if [ -n "$audio_url" ]; then
    # --cache=yes y --demuxer-readahead-secs ayudan a que no se corte a mitad
    mpv --no-video --volume=100 --cache=yes --demuxer-readahead-secs=5 "$audio_url" > /dev/null 2>&1 &
fi
