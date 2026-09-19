#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
SYSTEM_CONF="$BASE/config/system.conf"
USER_CORE="$BASE/bin/user-core.sh"

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 USERNAME"
    exit 1
fi

if [ ! -f "$SYSTEM_CONF" ]; then
    echo "ERROR: system.conf tidak ditemukan." >&2
    exit 1
fi

source "$SYSTEM_CONF"

if [ -z "${DOMAIN:-}" ]; then
    echo "ERROR: DOMAIN belum diset." >&2
    exit 1
fi

USER_DATA=$("$USER_CORE" get "$USERNAME")

if [ -z "$USER_DATA" ]; then
    echo "ERROR: User tidak ditemukan." >&2
    exit 1
fi

PROTOCOL=$(echo "$USER_DATA" | awk -F'|' '{print $2}')
CREDENTIAL=$(echo "$USER_DATA" | awk -F'|' '{print $3}')
EXPIRED=$(echo "$USER_DATA" | awk -F'|' '{print $5}')
MAX_DEVICE=$(echo "$USER_DATA" | awk -F'|' '{print $6}')
STATUS=$(echo "$USER_DATA" | awk -F'|' '{print $7}')

if [ "$PROTOCOL" != "trojan" ]; then
    echo "ERROR: User $USERNAME bukan user Trojan." >&2
    exit 1
fi

echo "USERNAME=$USERNAME"
echo "PROTOCOL=trojan"
echo "EXPIRED=$EXPIRED"
echo "MAX_DEVICE=$MAX_DEVICE"
echo "STATUS=$STATUS"
echo
echo "TROJAN_TLS_443=trojan://${CREDENTIAL}@${DOMAIN}:443?security=tls&sni=${DOMAIN}&type=tcp#Nagara-${USERNAME}-TLS"
