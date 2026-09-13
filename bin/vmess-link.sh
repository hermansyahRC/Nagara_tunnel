#!/bin/bash

BASE="/opt/nagara-tunnel"
source "$BASE/config/system.conf"
DB="$BASE/users/users.db"

clear

echo "=============================================="
echo "          NAGARA TUNNEL - VMESS"
echo "=============================================="
echo

if [ ! -f "$DB" ]; then
    echo "Database user tidak ditemukan."
    exit 1
fi

mapfile -t USERS < <(awk -F'|' '$2=="vmess" {print $1}' "$DB")

if [ ${#USERS[@]} -eq 0 ]; then
    echo "Belum ada user VMess."
    exit 1
fi

echo "Daftar User VMess:"
echo

i=1
for USER in "${USERS[@]}"; do
    echo "$i. $USER"
    ((i++))
done

echo
read -p "Pilih nomor user: " CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#USERS[@]}" ]; then
    echo "Pilihan tidak valid."
    exit 1
fi

USERNAME="${USERS[$((CHOICE-1))]}"

LINE=$(awk -F'|' -v u="$USERNAME" '$1==u && $2=="vmess" {print; exit}' "$DB")

UUID=$(echo "$LINE" | cut -d'|' -f3)
EXPIRED=$(echo "$LINE" | cut -d'|' -f5)

# ==============================================
# VMESS WS TLS 443
# ==============================================

JSON_TLS=$(cat <<EOF2
{
  "v": "2",
  "ps": "${USERNAME}-VMESS-TLS",
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
EOF2
)

LINK_TLS=$(echo -n "$JSON_TLS" | base64 -w 0)

# ==============================================
# VMESS WS 80
# ==============================================

JSON_HTTP=$(cat <<EOF2
{
  "v": "2",
  "ps": "${USERNAME}-VMESS-80",
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
EOF2
)

LINK_HTTP=$(echo -n "$JSON_HTTP" | base64 -w 0)

# ==============================================
# VMESS GRPC TLS 443
# ==============================================

JSON_GRPC=$(cat <<EOF2
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
EOF2
)

LINK_GRPC=$(echo -n "$JSON_GRPC" | base64 -w 0)

# ==============================================
# OUTPUT
# ==============================================

echo
echo "=============================================="
echo " USER VMESS"
echo "=============================================="
echo "Username : $USERNAME"
echo "Expired  : $EXPIRED"
echo "UUID     : $UUID"

echo
echo "=============================================="
echo " VMESS WS TLS 443"
echo "=============================================="
echo "Server : $DOMAIN"
echo "Port   : 443"
echo "Network: WS"
echo "Path   : /vmess-ws"
echo "TLS    : ON"
echo "SNI    : $DOMAIN"
echo
echo "vmess://$LINK_TLS"

echo
echo "----------------------------------------------"
echo " VMESS WS 80"
echo "----------------------------------------------"
echo "Server : $DOMAIN"
echo "Port   : 80"
echo "Network: WS"
echo "Path   : /vmess-ws"
echo "TLS    : OFF"
echo
echo "vmess://$LINK_HTTP"

echo
echo "----------------------------------------------"
echo " VMESS GRPC TLS 443"
echo "----------------------------------------------"
echo "Server : $DOMAIN"
echo "Port   : 443"
echo "Network: gRPC"
echo "Service: vmess-grpc"
echo "TLS    : ON"
echo "SNI    : $DOMAIN"
echo
echo "vmess://$LINK_GRPC"

echo
echo "=============================================="
echo "       SELESAI"
echo "=============================================="
