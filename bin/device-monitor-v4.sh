#!/bin/bash

BASE="/opt/nagara-tunnel"
DB="$BASE/users/users.db"
LOG="$BASE/logs/xray-access.log"
SESSION_DIR="$BASE/runtime/sessions"
SESSION_DB="$SESSION_DIR/device-sessions-v4.db"

WINDOW=60
SUSPECT_CONN=20

mkdir -p "$SESSION_DIR"
touch "$SESSION_DB"

echo "=============================================="
echo "        NAGARA DEVICE MONITOR v4"
echo "=============================================="
printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
"USER" "ACTIVITY" "SESSIONS" "LIMIT" "RISK" "LAST ACTIVITY"
echo "----------------------------------------------"

NOW=$(date +%s)

while IFS='|' read -r username protocol credential created expired max_device status
do
    [ -z "$username" ] && continue

    [[ "$max_device" =~ ^[0-9]+$ ]] || max_device=0

    email="nagara-${username}"

    if [ "$status" != "ACTIVE" ]; then
        printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
            "$username" "BLOCKED" "-" "$max_device" "$status" "-"
        continue
    fi

    if [ ! -f "$LOG" ]; then
        printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
            "$username" "OFFLINE" "0" "$max_device" "NORMAL" "-"
        continue
    fi

    recent=$(tail -1000 "$LOG" | grep "email: $email" || true)

    last_line=$(printf '%s\n' "$recent" | tail -1)

    if [ -z "$last_line" ]; then
        printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
            "$username" "OFFLINE" "0" "$max_device" "NORMAL" "-"
        continue
    fi

    last_time=$(printf '%s\n' "$last_line" | \
        grep -oE '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | \
        tail -1)

    if [ -z "$last_time" ]; then
        printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
            "$username" "UNKNOWN" "-" "$max_device" "CHECK" "-"
        continue
    fi

    last_epoch=$(date -d "$last_time" +%s 2>/dev/null || echo 0)
    age=$((NOW-last_epoch))

    recent_count=0

    while IFS= read -r line
    do
        [ -z "$line" ] && continue

        t=$(printf '%s\n' "$line" | \
            grep -oE '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | \
            tail -1)

        [ -z "$t" ] && continue

        ts=$(date -d "$t" +%s 2>/dev/null || echo 0)

        if [ "$ts" -gt 0 ] && [ $((NOW-ts)) -ge 0 ] && [ $((NOW-ts)) -le "$WINDOW" ]; then
            recent_count=$((recent_count+1))
        fi
    done <<< "$recent"

    if [ "$age" -le "$WINDOW" ]; then
        activity="ONLINE"
    else
        activity="OFFLINE"
        recent_count=0
    fi

    risk="NORMAL"

    if [ "$activity" = "ONLINE" ]; then
        if [ "$recent_count" -ge "$SUSPECT_CONN" ]; then
            risk="SUSPECT"
        else
            risk="NORMAL"
        fi
    fi

    printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
        "$username" \
        "$activity" \
        "$recent_count" \
        "$max_device" \
        "$risk" \
        "$last_time"

    if [ "$activity" = "ONLINE" ]; then
        printf '%s|%s|%s|%s|%s|%s\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" \
            "$username" \
            "$protocol" \
            "$recent_count" \
            "$max_device" \
            "$risk" >> "$SESSION_DB"
    fi

done < "$DB"

echo "=============================================="
echo "Window aktivitas : ${WINDOW} detik"
echo "SUSPECT          : >= ${SUSPECT_CONN} aktivitas"
echo "MAX DEVICE       : hanya policy, belum enforcement"
echo "AUTO-FREEZE      : DISABLED"
echo "=============================================="

echo "=============================================="
echo "Window aktivitas : ${WINDOW} detik"
echo "SUSPECT          : >= ${SUSPECT_CONN} aktivitas"
echo "MAX DEVICE       : hanya policy, belum enforcement"
echo "AUTO-FREEZE      : DISABLED"
echo "=============================================="
