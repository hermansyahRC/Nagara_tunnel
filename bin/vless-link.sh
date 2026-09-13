#!/bin/bash

DB="/opt/nagara-tunnel/users/users.db"
SERVER_IP=$(curl -4 -s --max-time 5 https://api.ipify.org)
PORT="80"
PATH_WS="/nagara-ws"

clear

echo "=============================================="
echo "          NAGARA TUNNEL"
echo "          VLESS LINK GENERATOR"
echo "=============================================="
echo

if [ ! -f "$DB" ]; then
    echo "Database user tidak ditemukan."
    exit 1
fi

echo "DAFTAR USER VLESS"
echo "----------------------------------------------"

awk -F'|' '$2=="vless" {
    printf "%-3s %-20s %-12s\n", NR, $1, $5
}' "$DB"

echo
read -p "Masukkan username: " USERNAME

DATA=$(grep "^${USERNAME}|vless|" "$DB")

if [ -z "$DATA" ]; then
    echo
    echo "User VLESS tidak ditemukan."
    exit 1
fi

UUID=$(echo "$DATA" | cut -d'|' -f3)
EXPIRED=$(echo "$DATA" | cut -d'|' -f5)

LINK="vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&security=none&type=ws&path=%2Fnagara-ws&host=${SERVER_IP}#Nagara-${USERNAME}"

echo
echo "=============================================="
echo "             VLESS CONFIG"
echo "=============================================="
echo
echo "Username : $USERNAME"
echo "Server   : $SERVER_IP"
echo "Port     : $PORT"
echo "Network  : WebSocket"
echo "Path     : /nagara-ws"
echo "Expired  : $EXPIRED"
echo
echo "VLESS LINK:"
echo
echo "$LINK"
echo
echo "=============================================="
