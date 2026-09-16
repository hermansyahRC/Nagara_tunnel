#!/bin/bash
BASE="/opt/nagara-tunnel"
HISTORY="$BASE/runtime/traffic-history/traffic.csv"

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

START=$(date -d '6 days ago' '+%Y-%m-%d')
TODAY=$(date '+%Y-%m-%d')

echo "=============================================="
echo "        NAGARA TRAFFIC - LAST 7 DAYS"
echo "=============================================="
printf "%-10s %-14s %-14s %-14s\n" "USER" "DOWNLOAD" "UPLOAD" "TOTAL"
echo "----------------------------------------------"

awk -F'|' -v start="$START" -v today="$TODAY" '
NR > 1 && $1 >= start && $1 <= today {
    down[$2] += $3
    up[$2] += $4
    total[$2] += $5
}
END {
    for (u in total)
        printf "%s|%s|%s|%s\n", u, down[u], up[u], total[u]
}
' "$HISTORY" |
while IFS='|' read -r username download upload total; do
    printf "%-10s %-14s %-14s %-14s\n" \
        "$username" \
        "$(format_bytes "$download")" \
        "$(format_bytes "$upload")" \
        "$(format_bytes "$total")"
done

echo "----------------------------------------------"
echo "Period : $START to $TODAY"
echo "=============================================="
