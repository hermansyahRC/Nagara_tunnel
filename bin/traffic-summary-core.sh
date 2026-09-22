#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
SERVER="127.0.0.1:10085"
USER_FILE="$BASE/users/users.db"

format_bytes() {
    local bytes="${1:-0}"

    if [ "$bytes" -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ]; then
        awk "BEGIN {printf \"%.2f KB\", $bytes/1024}"
    else
        printf "%s B" "$bytes"
    fi
}

if [ ! -f "$USER_FILE" ]; then
    echo "ERROR: Database user tidak ditemukan." >&2
    exit 1
fi

stats="$(xray api statsquery --server="$SERVER" 2>/dev/null)"

total_down=0
total_up=0
total_traffic=0
user_count=0

while IFS='|' read -r username protocol credential created expired limit status; do
    [ -z "$username" ] && continue

    down="$(
        printf '%s\n' "$stats" |
        jq -r --arg n "user>>>nagara-$username>>>traffic>>>downlink" \
        '.stat[] | select(.name==$n) | (.value // 0)' |
        head -1
    )"

    up="$(
        printf '%s\n' "$stats" |
        jq -r --arg n "user>>>nagara-$username>>>traffic>>>uplink" \
        '.stat[] | select(.name==$n) | (.value // 0)' |
        head -1
    )"

    down="${down:-0}"
    up="${up:-0}"

    [[ "$down" =~ ^[0-9]+$ ]] || down=0
    [[ "$up" =~ ^[0-9]+$ ]] || up=0

    total=$((down + up))

    total_down=$((total_down + down))
    total_up=$((total_up + up))
    total_traffic=$((total_traffic + total))
    user_count=$((user_count + 1))

    echo "USER=$username|DOWNLOAD=$(format_bytes "$down")|UPLOAD=$(format_bytes "$up")|TOTAL=$(format_bytes "$total")"

done < "$USER_FILE"

echo "SUMMARY_USERS=$user_count"
echo "SUMMARY_DOWNLOAD=$(format_bytes "$total_down")"
echo "SUMMARY_UPLOAD=$(format_bytes "$total_up")"
echo "SUMMARY_TOTAL=$(format_bytes "$total_traffic")"
