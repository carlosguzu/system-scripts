#!/usr/bin/env bash

TARGETS_FILE="/home/carlosg/Projects/instagram-cleaner/to_unfollow.txt"
UNFOLLOWED_FILE="/home/carlosg/Projects/instagram-cleaner/unfollowed.txt"
ICON=""

if [ ! -f "$TARGETS_FILE" ]; then
    echo "{\"text\": \"\", \"tooltip\": \"\", \"class\": \"hidden\"}"
    exit 0
fi

TOTAL=$(wc -l < "$TARGETS_FILE" 2>/dev/null || echo 0)
DONE=0
if [ -f "$UNFOLLOWED_FILE" ]; then
    DONE=$(wc -l < "$UNFOLLOWED_FILE" 2>/dev/null || echo 0)
fi

PENDING=$((TOTAL - DONE))
if [ "$PENDING" -lt 0 ]; then
    PENDING=0
fi

# Comprobar si el servicio está corriendo activamente ahora mismo
IS_RUNNING=false
if systemctl --user is-active --quiet instagram-cleaner.service 2>/dev/null; then
    IS_RUNNING=true
fi

if [ "$PENDING" -eq 0 ]; then
    TEXT="$ICON 100% ✓"
    TOOLTIP="Instagram Cleaner: ¡Completado al 100%!\nTodas las $TOTAL cuentas fueron procesadas."
    CLASS="completed"
elif [ "$IS_RUNNING" = true ]; then
    TEXT="$ICON $PENDING ⚙"
    TOOLTIP="Instagram Cleaner: En ejecución activa ahora mismo...\nPendientes: $PENDING de $TOTAL\nDadas de baja: $DONE"
    CLASS="running"
else
    TEXT="$ICON $PENDING"
    TOOLTIP="Instagram Cleaner\nPendientes por dejar de seguir: $PENDING\nDadas de baja hasta ahora: $DONE\nTotal inicial: $TOTAL"
    CLASS="idle"
fi

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
