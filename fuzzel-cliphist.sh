#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

read -r -d '' prog <<'EOF'
/^[0-9]+\s<meta http-equiv=/ { next }
match($0, /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/, grp) {
    system("printf '" grp[1] "\\t' | cliphist decode >" tmp_dir "/" grp[1] "." grp[3])
    printf "%s\t[img]\0icon\x1f%s/%s.%s\n", grp[1], tmp_dir, grp[1], grp[3]
    next
}
1
EOF

# Select an entry from cliphist using Fuzzel with image thumbnails
# Override lines and line-height only for clipboard (keeps global fuzzel.ini untouched)
selection=$(cliphist list | gawk -v tmp_dir="$tmp_dir" "$prog" | fuzzel --dmenu --prompt="📋  " --lines=5 --line-height=36)

# Exit if user cancelled (pressed Escape)
if [[ -z "$selection" ]]; then
    exit 0
fi

# Extract the numeric ID from the selected line
id=$(echo "$selection" | grep -Eo '^[0-9]+' | head -n 1)

# Check if the entry is an image
if [[ "$selection" == *"[img]"* ]]; then
    temp_img="/tmp/satty_clip_edit.png"
    printf "%s\t" "$id" | cliphist decode > "$temp_img"
    satty --filename "$temp_img" --early-exit &
    disown
else
    # Text entry: decode and copy to Wayland clipboard
    printf "%s\t" "$id" | cliphist decode | wl-copy
fi
