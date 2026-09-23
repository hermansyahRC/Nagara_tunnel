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

if [ "$PROTOCOL" != "vmess" ]; then
    echo "ERROR: User $USERNAME bukan VMess." >&2
    exit 1
fi

JSON_WS=$(cat <<EOF
{
  "v": "2",
  "ps": "${USERNAME}-VMESS-WS-TLS",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "/vmess-ws",
  "tls": "tls",
  "sni": "${DOMAIN}"
}
EOF
)

LINK_WS="vmess://$(printf '%s' "$JSON_WS" | base64 -w 0)"

JSON_HTTP=$(cat <<EOF
{
  "v": "2",
  "ps": "${USERNAME}-VMESS-WS-80",
  "add": "${DOMAIN}",
  "port": "80",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "/vmess-ws",
  "tls": ""
}
EOF
)

LINK_HTTP="vmess://$(printf '%s' "$JSON_HTTP" | base64 -w 0)"

JSON_GRPC=$(cat <<EOF
{
  "v": "2",
  "ps": "${USERNAME}-VMESS-GRPC",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "grpc",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "vmess-grpc",
  "tls": "tls",
  "sni": "${DOMAIN}"
}
EOF
)

LINK_GRPC="vmess://$(printf '%s' "$JSON_GRPC" | base64 -w 0)"

echo "USERNAME=$USERNAME"
echo "PROTOCOL=vmess"
echo "EXPIRED=$EXPIRED"
echo "MAX_DEVICE=$MAX_DEVICE"
echo "STATUS=$STATUS"
echo
echo "VMESS_WS_TLS=$LINK_WS"
echo "VMESS_WS_80=$LINK_HTTP"
echo "VMESS_GRPC_TLS=$LINK_GRPC"
