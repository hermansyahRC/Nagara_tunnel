#!/bin/bash

DB="/opt/nagara-tunnel/users/users.db"
CONFIG="/usr/local/etc/xray/config.json"
LOG_DIR="/opt/nagara-tunnel/logs"
ACCESS_LOG="$LOG_DIR/xray-access.log"

TMP_CONFIG=$(mktemp --suffix=.json)

cleanup() {
    rm -f "$TMP_CONFIG" "$TMP_CONFIG.new"
}

trap cleanup EXIT

mkdir -p "$LOG_DIR"
touch "$ACCESS_LOG"

if [ ! -f "$DB" ]; then
    echo "ERROR: Database tidak ditemukan: $DB"
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Config Xray tidak ditemukan: $CONFIG"
    exit 1
fi

cp "$CONFIG" "$TMP_CONFIG"

# Aktifkan access log Xray
jq --arg access_log "$ACCESS_LOG" '
    .log = {
        "loglevel": "warning",
        "access": $access_log
    }
' "$TMP_CONFIG" > "${TMP_CONFIG}.new" &&
mv "${TMP_CONFIG}.new" "$TMP_CONFIG"

# Reset semua client agar tidak duplicate
jq '
(.inbounds[]
 | select(
     .tag == "vless-in"
     or .tag == "vmess-in"
     or .tag == "vmess-grpc-in"
     or .tag == "trojan-in"
   )
 | .settings.clients) = []
' "$TMP_CONFIG" > "${TMP_CONFIG}.new" &&
mv "${TMP_CONFIG}.new" "$TMP_CONFIG"

TODAY=$(date +%F)

while IFS='|' read -r username protocol credential created expired max_device status; do

    [ -z "$username" ] && continue

    case "$username" in
        \#*) continue ;;
    esac

    [ -z "$status" ] && status="ACTIVE"

    # Jika tanggal sudah lewat, user tidak dimasukkan.
    if [ -n "$expired" ] && [[ "$expired" < "$TODAY" ]]; then
        echo "SKIP: $username [EXPIRED]"
        continue
    fi

    # Hanya ACTIVE yang boleh masuk Xray.
    if [ "$status" != "ACTIVE" ]; then
        echo "SKIP: $username [$status]"
        continue
    fi

    case "$protocol" in

        vless)
            jq --arg id "$credential" \
               --arg email "nagara-$username" \
               '(.inbounds[]
                 | select(.tag == "vless-in")
                 | .settings.clients) += [{
                   "id": $id,
                   "email": $email
                 }]' \
               "$TMP_CONFIG" > "${TMP_CONFIG}.new" &&
            mv "${TMP_CONFIG}.new" "$TMP_CONFIG"

            echo "SYNC: $username [vless]"
            ;;

        vmess)
            jq --arg id "$credential" \
               --arg email "nagara-$username" \
               '(.inbounds[]
                 | select(.tag == "vmess-in" or .tag == "vmess-grpc-in")
                 | .settings.clients) += [{
                   "id": $id,
                   "alterId": 0,
                   "email": $email
                 }]' \
               "$TMP_CONFIG" > "${TMP_CONFIG}.new" &&
            mv "${TMP_CONFIG}.new" "$TMP_CONFIG"

            echo "SYNC: $username [vmess + grpc]"
            ;;

        trojan)
            jq --arg password "$credential" \
               --arg email "nagara-$username" \
               '(.inbounds[]
                 | select(.tag == "trojan-in")
                 | .settings.clients) += [{
                   "password": $password,
                   "email": $email
                 }]' \
               "$TMP_CONFIG" > "${TMP_CONFIG}.new" &&
            mv "${TMP_CONFIG}.new" "$TMP_CONFIG"

            echo "SYNC: $username [trojan]"
            ;;

        *)
            echo "SKIP: $username [protocol tidak dikenal: $protocol]"
            ;;

    esac

done < "$DB"

echo
echo "=== TEST CONFIG ==="

if xray run -test -config "$TMP_CONFIG"; then

    cp "$TMP_CONFIG" "$CONFIG"

    systemctl restart xray

    echo
    echo "USER SYNC BERHASIL"
    echo "Xray : $(systemctl is-active xray)"
    echo "Access log : $ACCESS_LOG"

else

    echo
    echo "ERROR: CONFIG TIDAK VALID"
    echo "Konfigurasi lama TIDAK diubah."
    exit 1

fi
