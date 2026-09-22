#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
HISTORY="$BASE/runtime/traffic-history/traffic.csv"

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
    echo "ERROR: Username wajib diisi." >&2
    exit 1
fi

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Username tidak valid." >&2
    exit 1
fi

if [ ! -f "$HISTORY" ]; then
    echo "ERROR: File history tidak ditemukan." >&2
    exit 1
fi

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

TODAY="$(date '+%Y-%m-%d')"
SEVEN_DAYS_AGO="$(date -d '6 days ago' '+%Y-%m-%d')"

TODAY_DATA="$(
    awk -F'|' -v u="$USERNAME" -v d="$TODAY" \
    'NR > 1 && $2 == u && $1 == d {
        down += $3
        up += $4
        total += $5
    }
    END {
        printf "%d|%d|%d\n", down, up, total
    }' "$HISTORY"
)"

WEEK_DATA="$(
    awk -F'|' -v u="$USERNAME" -v d="$SEVEN_DAYS_AGO" \
    'NR > 1 && $2 == u && $1 >= d {
        down += $3
        up += $4
        total += $5
    }
    END {
        printf "%d|%d|%d\n", down, up, total
    }' "$HISTORY"
)"

IFS='|' read -r TODAY_DOWN TODAY_UP TODAY_TOTAL <<< "$TODAY_DATA"
IFS='|' read -r WEEK_DOWN WEEK_UP WEEK_TOTAL <<< "$WEEK_DATA"

echo "USERNAME=$USERNAME"
echo "TODAY_DOWNLOAD=$(format_bytes "$TODAY_DOWN")"
echo "TODAY_UPLOAD=$(format_bytes "$TODAY_UP")"
echo "TODAY_TOTAL=$(format_bytes "$TODAY_TOTAL")"
echo "WEEK_DOWNLOAD=$(format_bytes "$WEEK_DOWN")"
echo "WEEK_UPLOAD=$(format_bytes "$WEEK_UP")"
echo "WEEK_TOTAL=$(format_bytes "$WEEK_TOTAL")"

