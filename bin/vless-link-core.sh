#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
CONFIG="$BASE/config/system.conf"
USER_CORE="$BASE/bin/user-core.sh"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: system.conf tidak ditemukan." >&2
    exit 1
fi

source "$CONFIG"

if [ -z "${DOMAIN:-}" ]; then
    echo "ERROR: DOMAIN belum dikonfigurasi." >&2
    exit 1
fi

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 USERNAME" >&2
    exit 1
fi

RECORD=$("$USER_CORE" get "$USERNAME")

if [ -z "$RECORD" ]; then
    echo "ERROR: User tidak ditemukan." >&2
    exit 1
fi

IFS='|' read -r NAME PROTOCOL UUID CREATED EXPIRED MAX_DEVICE STATUS <<< "$RECORD"

if [ "$PROTOCOL" != "vless" ]; then
    echo "ERROR: User $USERNAME bukan VLESS." >&2
    exit 1
fi

LINK_TLS="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=%2Fnagara-ws&sni=${DOMAIN}#Nagara-${USERNAME}-TLS"

LINK_HTTP="vless://${UUID}@${DOMAIN}:80?encryption=none&security=none&type=ws&host=${DOMAIN}&path=%2Fnagara-ws#Nagara-${USERNAME}-80"

echo "USERNAME=$USERNAME"
echo "PROTOCOL=vless"
echo "EXPIRED=$EXPIRED"
echo "MAX_DEVICE=$MAX_DEVICE"
echo "STATUS=$STATUS"
echo
echo "VLESS_WS_TLS=$LINK_TLS"
echo "VLESS_WS_80=$LINK_HTTP"
