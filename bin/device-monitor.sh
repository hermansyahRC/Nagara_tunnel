#!/bin/bash

BASE="/opt/nagara-tunnel"
DB="$BASE/users/users.db"
LOG="$BASE/logs/xray-access.log"
SESSION_DIR="$BASE/runtime/sessions"
SESSION_DB="$SESSION_DIR/device-sessions.db"

mkdir -p "$SESSION_DIR"
touch "$SESSION_DB"

echo "=============================================="
echo "        NAGARA DEVICE MONITOR v3"
echo "=============================================="
printf "%-10s %-10s %-8s %-8s %-12s %s\n" \
"USER" "ACTIVITY" "CONN" "LIMIT" "RISK" "LAST ACTIVITY"
echo "----------------------------------------------"

NOW=$(date +%s)
WINDOW=60

while IFS='|' read -r username protocol credential created expired max_device status
do
    [ -z "$username" ] && continue

    email="nagara-${username}"

    [[ "$max_device" =~ ^[0-9]+$ ]] || max_device=0

    if [ "$status" != "ACTIVE" ]; then
        printf "%-10s %-10s %-8s %-8s %-12s %s\n" \
            "$username" "BLOCKED" "-" "$max_device" "$status" "-"
        continue
    fi

    if [ ! -f "$LOG" ]; then
        printf "%-10s %-10s %-8s %-8s %-12s %s\n" \
            "$username" "OFFLINE" "0" "$max_device" "NORMAL" "-"
        continue
    fi

    recent_lines=$(tail -500 "$LOG" | grep "email: $email" || true)

    connection_count=$(printf '%s\n' "$recent_lines" | \
        awk -v now="$NOW" -v window="$WINDOW" '
        {
            match($0,/^[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/,m)
            if (m[0] != "") {
                cmd="date -d \"" m[0] "\" +%s 2>/dev/null"
                cmd | getline ts
                close(cmd)
                if (now-ts <= window && now-ts >= 0)
                    count++
            }
        }
        END { print count+0 }
        ')

    last_activity=$(printf '%s\n' "$recent_lines" | tail -1)

    if [ -z "$last_activity" ]; then
        printf "%-10s %-10s %-8s %-8s %-12s %s\n" \
            "$username" "OFFLINE" "0" "$max_device" "NORMAL" "-"
        continue
    fi

    last_time=$(printf '%s\n' "$last_activity" | \
        grep -oE '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -1)

    if [ -n "$last_time" ]; then
        last_epoch=$(date -d "$last_time" +%s 2>/dev/null || echo 0)
        age=$((NOW-last_epoch))
    else
        age=999999
    fi

    if [ "$age" -le "$WINDOW" ]; then
        activity="ONLINE"
    else
        activity="OFFLINE"
        connection_count=0
    fi

    risk="NORMAL"

    if [ "$activity" = "ONLINE" ]; then
        if [ "$connection_count" -ge 20 ]; then
            risk="SUSPECT"
        fi
    fi

    printf "%-10s %-10s %-8s %-8s %-12s %s\n" \
        "$username" \
        "$activity" \
        "$connection_count" \
        "$max_device" \
        "$risk" \
        "${last_time:-"-"}"

    if [ "$activity" = "ONLINE" ]; then
        printf '%s|%s|%s|%s|%s\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" \
            "$username" \
            "$connection_count" \
            "$max_device" \
            "$risk" >> "$SESSION_DB"
    fi

done < "$DB"

echo "=============================================="
echo "Activity window : ${WINDOW}s"
echo "SUSPECT         : >=20 connections/window"
echo "AUTO-FREEZE     : DISABLED"
echo "=============================================="
