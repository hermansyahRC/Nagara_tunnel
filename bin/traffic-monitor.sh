#!/bin/bash
BASE="/opt/nagara-tunnel"
SERVER="127.0.0.1:10085"
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
stats=$(xray api statsquery --server="$SERVER" 2>/dev/null)

echo "=============================================="
echo "           NAGARA TRAFFIC MONITOR"
echo "=============================================="
printf "%-10s %-12s %-12s %-12s\n" "USER" "DOWNLOAD" "UPLOAD" "TOTAL"
echo "----------------------------------------------"
while IFS='|' read -r username protocol credential created expired limit status; do
    down=$(printf '%s\n' "$stats" | jq -r --arg n "user>>>nagara-$username>>>traffic>>>downlink" '.stat[] | select(.name==$n) | (.value // 0)' | head -1)
    up=$(printf '%s\n' "$stats" | jq -r --arg n "user>>>nagara-$username>>>traffic>>>uplink" '.stat[] | select(.name==$n) | (.value // 0)' | head -1)

    down=${down:-0}
    up=${up:-0}
    total=$((down + up))

    printf "%-10s %-12s %-12s %-12s\n" \
        "$username" "$(format_bytes "$down")" "$(format_bytes "$up")" "$(format_bytes "$total")"
done < "$BASE/users/users.db"
echo "=============================================="
echo "Xray API : $SERVER"
echo "=============================================="
