#!/usr/bin/env bash
# dependencies: pipewire (pw-dump), psmisc (fuser), jq, procps (pgrep)
set -euo pipefail

JQ_BIN="${JQ:-jq}"
PW_DUMP_CMD="${PW_DUMP:-pw-dump}"

mic=0
cam=0
scr=0

mic_app=""
cam_app=""
scr_app=""

# --- OBTENER DATOS DE PIPEWIRE ---
if command -v "$PW_DUMP_CMD" >/dev/null 2>&1 && command -v "$JQ_BIN" >/dev/null 2>&1; then
  dump="$($PW_DUMP_CMD 2>/dev/null || true)"

  # --- MICROPHONE (Detección de uso + Estado de Mute) ---
  # Si el sistema está muteado según wpctl, ignoramos el uso
  if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "\[MUTED\]"; then
      mic=0
  else
      mic="$(
        printf '%s' "$dump" \
        | $JQ_BIN -r '
          [ .[]
            | select(.type=="PipeWire:Interface:Node")
            | select((.info.props."media.class"=="Audio/Source" or .info.props."media.class"=="Audio/Source/Virtual"))
            | select((.info.state=="running") or (.state=="running"))
          ] | (if length>0 then 1 else 0 end)
        ' 2>/dev/null || echo 0
      )"

      if [[ "$mic" -eq 1 ]]; then
        mic_app="$(
          printf '%s' "$dump" \
          | $JQ_BIN -r '
            [ .[]
              | select(.type=="PipeWire:Interface:Node")
              | select((.info.props."media.class"=="Stream/Input/Audio"))
              | select((.info.state=="running") or (.state=="running"))
              | .info.props["node.name"]
            ] | unique | join(", ")
          ' 2>/dev/null || echo ""
        )"
      fi
  fi

  # --- CAMERA (Usando fuser) ---
  if command -v fuser >/dev/null 2>&1; then
      for dev in /dev/video*; do
          if [ -e "$dev" ] && fuser "$dev" >/dev/null 2>&1; then
              cam=1
              pids=$(fuser "$dev" 2>/dev/null)
              for pid in $pids; do
                  pname=$(ps -p "$pid" -o comm=)
                  if [[ -n "$pname" ]]; then
                      cam_app+="$pname, "
                  fi
              done
          fi
      done
      cam_app="${cam_app%, }"
  fi

  # --- SCREEN SHARING ---
  scr="$(
      printf '%s' "$dump" \
      | $JQ_BIN -e '
          [ .[]
            | select(.info?.props?)
            | select(
                (.info.props["media.name"]? // "")
                | test("^(xdph-streaming|gsr-default|game capture)")
            )
          ]
          | (if length > 0 then true else false end)
        ' >/dev/null && echo 1 || echo 0
    )"

  if [[ "$scr" -eq 1 ]]; then
      scr_app="$(
      printf '%s' "$dump" \
      |   $JQ_BIN -r '
          [ .[]
            | select(.type=="PipeWire:Interface:Node")
            | select((.info.props."media.class"=="Stream/Input/Video") or (.info.props."media.name"=="gsr-default_output") or (.info.props."media.name"=="game capture"))
            | select((.info.state=="running") or (.state=="running"))
            | .info.props["media.name"]
          ] | unique | join(", ")
        ' 2>/dev/null || echo ""
      )"
  fi
fi

# --- COLORES ---
green="#30D158"
red="#cf3308"
purple="#9B32FA"
blue="#3ab0f0"

# --- GENERAR PUNTOS (DOTS) ---
dot() {
  local on="$1" color="$2"
  if [[ "$on" -eq 1 ]]; then
    printf '<span foreground="%s">●</span>' "$color"
  else
    printf ''
  fi
}

dots=()
mic_dot="$(dot "$mic" "$green")"; [[ -n "$mic_dot" ]] && dots+=("$mic_dot")
cam_dot="$(dot "$cam" "$red")";   [[ -n "$cam_dot" ]] && dots+=("$cam_dot")
scr_dot="$(dot "$scr" "$purple")"; [[ -n "$scr_dot" ]] && dots+=("$scr_dot")

text="${dots[*]}"

# --- CONSTRUIR TOOLTIP DINÁMICO (Solo muestra lo activo) ---
tooltip_parts=()
[[ $mic -eq 1 ]] && tooltip_parts+=("Mic: ${mic_app:-On}")
[[ $cam -eq 1 ]] && tooltip_parts+=("Cam: ${cam_app:-On}")
[[ $scr -eq 1 ]] && tooltip_parts+=("Screen: ${scr_app:-On}")

tooltip=$(printf " | %s" "${tooltip_parts[@]}")
tooltip="${tooltip:3}" # Limpiar el primer separador

# --- CLASES PARA CSS ---
classes="privacydot"
[[ $mic -eq 1 ]] && classes="$classes mic-on" || classes="$classes mic-off"
[[ $cam -eq 1 ]] && classes="$classes cam-on" || classes="$classes cam-off"
[[ $scr -eq 1 ]] && classes="$classes scr-on" || classes="$classes scr-off"

# --- SALIDA JSON ---
jq -c -n --arg text "$text" --arg tooltip "$tooltip" --arg class "$classes" \
  '{text:$text, tooltip:$tooltip, class:$class}'
