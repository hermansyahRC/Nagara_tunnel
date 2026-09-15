#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/nagara-tunnel"
CONFIG="$BASE/config/system.conf"
DB="$BASE/users/users.db"

clear

echo "=============================================="
echo "          NAGARA TUNNEL - VMESS"
echo "=============================================="
echo

if [ ! -f "$CONFIG" ]; then
    echo "File system.conf tidak ditemukan."
    exit 1
fi

source "$CONFIG"

if [ -z "${DOMAIN:-}" ]; then
    echo "DOMAIN belum dikonfigurasi."
    exit 1
fi

if [ ! -f "$DB" ]; then
    echo "Database user tidak ditemukan."
    exit 1
fi

mapfile -t USERS < <(
    awk -F'|' '$2=="vmess" {print $1}' "$DB"
)

if [ ${#USERS[@]} -eq 0 ]; then
    echo "Belum ada user VMess."
    exit 1
fi

echo "Daftar User VMess:"
echo "----------------------------------------------"

i=1
for USER in "${USERS[@]}"; do
    echo "$i. $USER"
    ((i++))
done

echo
read -r -p "Pilih nomor user: " CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || \
   [ "$CHOICE" -lt 1 ] || \
   [ "$CHOICE" -gt "${#USERS[@]}" ]; then
    echo
    echo "Pilihan tidak valid."
    exit 1
fi

USERNAME="${USERS[$((CHOICE-1))]}"

LINE=$(awk -F'|' -v u="$USERNAME" \
    '$1==u && $2=="vmess" {print; exit}' "$DB")

if [ -z "$LINE" ]; then
    echo
    echo "User VMess tidak ditemukan."
    exit 1
fi

UUID=$(echo "$LINE" | cut -d'|' -f3)
EXPIRED=$(echo "$LINE" | cut -d'|' -f5)

# ==============================================
# VMESS WS TLS 443
# ==============================================

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

LINK_WS=$(printf '%s' "$JSON_WS" | base64 -w 0)

# ==============================================
# VMESS WS NON-TLS 80
# ==============================================

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

LINK_HTTP=$(printf '%s' "$JSON_HTTP" | base64 -w 0)

# ==============================================
# VMESS GRPC TLS 443
# ==============================================

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

LINK_GRPC=$(printf '%s' "$JSON_GRPC" | base64 -w 0)

echo
echo "=============================================="
echo "             VMESS CONFIG"
echo "=============================================="
echo
echo "Username : $USERNAME"
echo "Domain   : $DOMAIN"
echo "Expired  : $EXPIRED"
echo
echo "----------------------------------------------"
echo "VMESS WEBSOCKET TLS"
echo "----------------------------------------------"
echo "Server   : $DOMAIN"
echo "Port     : 443"
echo "Security : TLS"
echo "Network  : WebSocket"
echo "Path     : /vmess-ws"
echo "SNI      : $DOMAIN"
echo
echo "VMESS LINK:"
echo
echo "$LINK_WS"
echo
echo "----------------------------------------------"
echo "VMESS WEBSOCKET NON-TLS"
echo "----------------------------------------------"
echo "Server   : $DOMAIN"
echo "Port     : 80"
echo "Security : NONE"
echo "Network  : WebSocket"
echo "Path     : /vmess-ws"
echo "Host     : $DOMAIN"
echo
echo "VMESS LINK:"
echo
echo "$LINK_HTTP"
echo
echo "----------------------------------------------"
echo "VMESS GRPC TLS"
echo "----------------------------------------------"
echo "Server   : $DOMAIN"
echo "Port     : 443"
echo "Security : TLS"
echo "Network  : gRPC"
echo "Service  : vmess-grpc"
echo "SNI      : $DOMAIN"
echo
echo "VMESS GRPC LINK:"
echo
echo "$LINK_GRPC"
echo
echo "=============================================="
