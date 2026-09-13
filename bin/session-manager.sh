#!/bin/bash

BASE="/opt/nagara-tunnel"
DB="$BASE/users/users.db"

ACCESS_LOG="$BASE/logs/xray-access.log"
SESSION_DB="$BASE/runtime/sessions/sessions-v2.db"
WINDOW=60

DRY_RUN=true

get_user_latest_ip() {
    local username="$1"
    local cutoff
    cutoff=$(date -d "$WINDOW seconds ago" '+%Y/%m/%d %H:%M:%S')

    awk -v user="nagara-$username" -v cutoff="$cutoff" '
    {
        ts=$1 " " $2

        if ($0 !~ ("email: " user)) next
        if (ts < cutoff) next

        match($0, /from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)

        if (RSTART > 0) {
            last_ip=substr($0, RSTART+5, RLENGTH-5)
            last_ts=ts
        }
    }

    END {
        if (last_ip != "")
            print last_ip
    }
    ' "$ACCESS_LOG"
}
mkdir -p "$BASE/runtime/sessions"

echo "=============================================="
echo "        NAGARA SESSION MANAGER v2"
echo "=============================================="
echo

get_user_info() {
    local username="$1"

    awk -F'|' -v user="$username" '
    $1 == user {
        print $2 "|" $6 "|" $7
        exit
    }' "$DB"
}

get_user_ips() {
    local username="$1"
    local cutoff

    cutoff=$(date -d "$WINDOW seconds ago" '+%Y/%m/%d %H:%M:%S')

    [ ! -f "$ACCESS_LOG" ] && return

    awk -v user="$username" -v cutoff="$cutoff" '
    {
        if ($0 !~ ("email: nagara-" user))
            next

        if ($0 < cutoff)
            next

        match($0, /from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)

        if (RSTART > 0) {
            ip=substr($0, RSTART+5, RLENGTH-5)
            ips[ip]=1
        }
    }

    END {
        for (ip in ips)
            print ip
    }' "$ACCESS_LOG" | sort
}

dry_run_enforcement() {
    local username="$1"
    local protocol="$2"
    local limit="$3"
    local ips="$4"
    local ip_count="$5"

    if [ "$DRY_RUN" = "true" ]; then
        local latest_ip
        latest_ip=$(get_user_latest_ip "$username")

        echo "[DRY-RUN] $username ($protocol) OVERLIMIT: $ip_count/$limit"
        echo "[DRY-RUN] IP aktif: $(printf "%s" "$ips" | paste -sd "," -)"

        if [ -n "$latest_ip" ]; then
            echo "[DRY-RUN] Kandidat IP terbaru: $latest_ip"
        else
            echo "[DRY-RUN] Kandidat IP terbaru: tidak ditemukan"
        fi

        echo "[DRY-RUN] Tidak ada koneksi yang diputus."
    fi
}

show_users() {

    printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
        "USER" "PROTOCOL" "IP AKTIF" "LIMIT" "STATE" "IP ADDRESS"

    echo "--------------------------------------------------------------------------"

    while IFS="|" read -r username protocol credential created expired max_device status; do

        [ -z "$username" ] && continue

        info=$(get_user_info "$username")

        protocol_db=$(echo "$info" | cut -d"|" -f1)
        limit=$(echo "$info" | cut -d"|" -f2)
        user_status=$(echo "$info" | cut -d"|" -f3)

        ips=$(get_user_ips "$username")

        ip_count=0

        if [ -n "$ips" ]; then
            ip_count=$(printf '%s\n' "$ips" | grep -c .)
        fi

        if [ "$user_status" != "ACTIVE" ]; then
            state="$user_status"
        elif [ "$ip_count" -gt 0 ]; then
            if [ "$ip_count" -gt "$limit" ]; then
                state="OVERLIMIT"
            else
                state="ONLINE"
            fi
        else
            state="OFFLINE"
        fi

        if [ "$state" = "OVERLIMIT" ]; then
            dry_run_enforcement "$username" "$protocol_db" "$limit" "$ips" "$ip_count"
        fi

        ip_display=$(printf '%s\n' "$ips" | paste -sd ',' -)

        [ -z "$ip_display" ] && ip_display="-"

        printf "%-10s %-10s %-10s %-8s %-12s %s\n" \
            "$username" \
            "$protocol_db" \
            "$ip_count" \
            "$limit" \
            "$state" \
            "$ip_display"

        printf "%s|%s|%s|%s|%s|%s|%s\n" \
            "$(date '+%Y-%m-%d %H:%M:%S')" \
            "$username" \
            "$protocol_db" \
            "$ip_count" \
            "$limit" \
            "$state" \
            "$ip_display" >> "$SESSION_DB"

    done < "$DB"
}

main() {

    show_users

    echo
    echo "=============================================="
    echo "Session window : ${WINDOW} detik"
    echo "Session DB     : $SESSION_DB"
    echo "IP monitoring  : ENABLED"
    echo "Enforcement    : DISABLED"
    echo "=============================================="
}

main
