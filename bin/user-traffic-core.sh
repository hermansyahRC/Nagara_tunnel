#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SERVER="127.0.0.1:10085"

usage() {
    echo "Usage:"
    echo "  $0 USERNAME"
}

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
    usage
    exit 1
fi

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Username tidak valid." >&2
    exit 1
fi

LINE="$(awk -F'|' -v u="$USERNAME" '$1 == u {print; exit}' "$USER_FILE")"

if [ -z "$LINE" ]; then
    echo "ERROR: User tidak ditemukan: $USERNAME" >&2
    exit 1
fi

IFS='|' read -r USER PROTOCOL CREDENTIAL CREATED EXPIRED MAX_DEVICE STATUS <<< "$LINE"

STATS="$(xray api statsquery --server="$SERVER" 2>/dev/null)"

DOWN="$(printf '%s\n' "$STATS" | jq -r \
    --arg n "user>>>nagara-$USERNAME>>>traffic>>>downlink" \
    '.stat[] | select(.name==$n) | (.value // 0)' | head -1)"

UP="$(printf '%s\n' "$STATS" | jq -r \
    --arg n "user>>>nagara-$USERNAME>>>traffic>>>uplink" \
    '.stat[] | select(.name==$n) | (.value // 0)' | head -1)"

DOWN="${DOWN:-0}"
UP="${UP:-0}"

if ! [[ "$DOWN" =~ ^[0-9]+$ ]]; then
    DOWN=0
fi

if ! [[ "$UP" =~ ^[0-9]+$ ]]; then
    UP=0
fi

TOTAL=$((DOWN + UP))

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

echo "USERNAME=$USER"
echo "PROTOCOL=$PROTOCOL"
echo "EXPIRED=$EXPIRED"
echo "MAX_DEVICE=$MAX_DEVICE"
echo "STATUS=$STATUS"
echo "DOWNLOAD=$(format_bytes "$DOWN")"
echo "UPLOAD=$(format_bytes "$UP")"
echo "TOTAL=$(format_bytes "$TOTAL")"
