#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"

# Si Rofi nos envía una selección (el usuario eligió algo)
if [[ -n "$1" ]]; then
    id=$(echo "$1" | grep -Eo '^[0-9]+')
    
    if [[ "$1" == *"[img]"* ]]; then
        # 1. Decodificar la imagen en un archivo temporal seguro
        temp_img="/tmp/satty_clip_edit.png"
        echo -e "$id\t" | cliphist decode > "$temp_img"
        
        # 2. Abrir satty leyendo ese archivo en segundo plano (&) y desvincularlo
        satty --filename "$temp_img" &
        disown
    else
        # Es texto: se copia normal
        echo -e "$id\t" | cliphist decode | wl-copy
    fi
    exit
fi

# Si no hay selección, preparamos el menú listando el historial
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

read -r -d '' prog <<EOF
/^[0-9]+\s<meta http-equiv=/ { next }
match(\$0, /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/, grp) {
    system("echo " grp[1] "\\\\\t | cliphist decode >$tmp_dir/"grp[1]"."grp[3])
    
    print grp[1] "\t[img]\0icon\x1f$tmp_dir/"grp[1]"."grp[3]
    next
}
1
EOF
cliphist list | gawk "$prog"
