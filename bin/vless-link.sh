#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/nagara-tunnel"
CONFIG="$BASE/config/system.conf"
DB="$BASE/users/users.db"

clear

echo "=============================================="
echo "          NAGARA TUNNEL - VLESS"
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
    awk -F'|' '$2=="vless" {print $1}' "$DB"
)

if [ ${#USERS[@]} -eq 0 ]; then
    echo "Belum ada user VLESS."
    exit 1
fi

echo "Daftar User VLESS:"
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
    '$1==u && $2=="vless" {print; exit}' "$DB")

if [ -z "$LINE" ]; then
    echo
    echo "User VLESS tidak ditemukan."
    exit 1
fi

UUID=$(echo "$LINE" | cut -d'|' -f3)
EXPIRED=$(echo "$LINE" | cut -d'|' -f5)

LINK="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=%2Fnagara-ws&sni=${DOMAIN}#Nagara-${USERNAME}"

echo
echo "=============================================="
echo "             VLESS CONFIG"
echo "=============================================="
echo
echo "Username : $USERNAME"
echo "Domain   : $DOMAIN"
echo "Port     : 443"
echo "Security : TLS"
echo "Network  : WebSocket"
echo "Path     : /nagara-ws"
echo "SNI      : $DOMAIN"
echo "Expired  : $EXPIRED"
echo
echo "VLESS LINK:"
echo
echo "$LINK"
echo
echo "=============================================="
