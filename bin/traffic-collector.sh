#!/bin/bash
BASE="/opt/nagara-tunnel"
SERVER="127.0.0.1:10085"
STATE="$BASE/runtime/traffic-history/state"
HISTORY="$BASE/runtime/traffic-history/traffic.csv"
get_previous() {
    local name="$1"
    awk -v n="$name" '$1 == n {print $2; exit}' "$STATE/xray-baseline.tsv"
}
DATE=$(date '+%Y-%m-%d')
stats=$(xray api statsquery --server="$SERVER" 2>/dev/null)

while IFS='|' read -r username protocol credential created expired limit status; do
    down_name="user>>>nagara-$username>>>traffic>>>downlink"
    up_name="user>>>nagara-$username>>>traffic>>>uplink"

    down=$(printf '%s\n' "$stats" | jq -r --arg n "$down_name" '.stat[] | select(.name==$n) | (.value // 0)' | head -1)
    up=$(printf '%s\n' "$stats" | jq -r --arg n "$up_name" '.stat[] | select(.name==$n) | (.value // 0)' | head -1)

    down=${down:-0}
    up=${up:-0}

    old_down=$(get_previous "$down_name")
    old_up=$(get_previous "$up_name")

    old_down=${old_down:-$down}
    old_up=${old_up:-$up}

    delta_down=$((down - old_down))
    delta_up=$((up - old_up))

    [ "$delta_down" -lt 0 ] && delta_down=0
    [ "$delta_up" -lt 0 ] && delta_up=0

    delta_total=$((delta_down + delta_up))

    if [ "$delta_total" -gt 0 ]; then
        printf '%s|%s|%s|%s|%s\n' \
            "$DATE" "$username" "$delta_down" "$delta_up" "$delta_total" >> "$HISTORY"
    fi

    printf '%s\t%s\n' "$down_name" "$down"
    printf '%s\t%s\n' "$up_name" "$up"
done < "$BASE/users/users.db" > "$STATE/xray-baseline.new"
mv "$STATE/xray-baseline.new" "$STATE/xray-baseline.tsv"
