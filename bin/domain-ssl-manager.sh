#!/usr/bin/env bash

BASE="/opt/nagara-tunnel"

RESET=$'\033[0m'
WHITE=$'\033[97m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
RED=$'\033[91m'
CYAN=$'\033[96m'

get_domain() {
    if [ -f "$BASE/config/system.conf" ]; then
        awk -F= '/^DOMAIN=/{gsub(/"/,"",$2); print $2}' \
            "$BASE/config/system.conf"
    else
        echo "-"
    fi
}

pause() {
    echo
    read -rp "Tekan Enter untuk kembali..."
}

show_domain() {
    local DOMAIN
    DOMAIN="$(get_domain)"

    echo
    echo "=============================================="
    echo "             DOMAIN AKTIF"
    echo "=============================================="
    echo

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ]; then
        printf "${RED}Domain belum ditemukan.${RESET}\n"
    else
        printf "Domain : ${GREEN}%s${RESET}\n" "$DOMAIN"
    fi

    pause
}

show_ssl() {
    local DOMAIN
    local CERT_FILE

    DOMAIN="$(get_domain)"
    CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"

    echo
    echo "=============================================="
    echo "              DETAIL SSL"
    echo "=============================================="
    echo

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ]; then
        printf "${RED}Domain belum ditemukan.${RESET}\n"
        pause
        return
    fi

    if [ ! -f "$CERT_FILE" ]; then
        printf "${RED}SSL belum tersedia.${RESET}\n"
        pause
        return
    fi

    echo "Domain  : $DOMAIN"
    echo "Status  : ${GREEN}SSL tersedia${RESET}"
    echo

    openssl x509 \
        -in "$CERT_FILE" \
        -noout \
        -issuer \
        -subject \
        -dates

    pause
}
check_dns() {
    local DOMAIN
    local DNS_IP
    local SERVER_IP

    DOMAIN="$(get_domain)"

    echo
    echo "=============================================="
    echo "                 CEK DNS"
    echo "=============================================="
    echo

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ]; then
        printf "${RED}Domain belum ditemukan.${RESET}\n"
        pause
        return
    fi

    DNS_IP="$(dig +short A "$DOMAIN" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
    SERVER_IP="$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || true)"

    echo "Domain    : $DOMAIN"
    echo "DNS IPv4  : ${DNS_IP:-Tidak ditemukan}"
    echo "VPS IPv4  : ${SERVER_IP:-Tidak diketahui}"
    echo

    if [ -z "$DNS_IP" ]; then
        printf "${RED}● DNS belum memiliki record A.${RESET}\n"
    elif [ -z "$SERVER_IP" ]; then
        printf "${YELLOW}● IP publik VPS tidak dapat diperiksa.${RESET}\n"
    elif [ "$DNS_IP" = "$SERVER_IP" ]; then
        printf "${GREEN}● DNS sudah mengarah ke VPS.${RESET}\n"
    else
        printf "${YELLOW}● DNS belum mengarah ke IP VPS.${RESET}\n"
    fi

    pause
}

test_https() {
    local DOMAIN
    local HTTP_CODE

    DOMAIN="$(get_domain)"

    echo
    echo "=============================================="
    echo "                TEST HTTPS"
    echo "=============================================="
    echo

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ]; then
        printf "${RED}Domain belum ditemukan.${RESET}\n"
        pause
        return
    fi

    echo "URL    : https://$DOMAIN"
    echo

    HTTP_CODE="$(curl -4 -k -s -o /dev/null \
        -w '%{http_code}' \
        --connect-timeout 5 \
        --max-time 10 \
        "https://$DOMAIN/" 2>/dev/null || true)"

    echo "HTTP   : ${HTTP_CODE:-Tidak ada respons}"
    echo

    if [ "$HTTP_CODE" = "200" ] || \
       [ "$HTTP_CODE" = "301" ] || \
       [ "$HTTP_CODE" = "302" ] || \
       [ "$HTTP_CODE" = "404" ]; then
        printf "${GREEN}● HTTPS dapat diakses.${RESET}\n"
    else
        printf "${RED}● HTTPS tidak memberikan respons normal.${RESET}\n"
    fi

    pause
}

refresh_ssl_nginx() {
    local DOMAIN

    DOMAIN="$(get_domain)"

    echo "=============================================="
    echo "          REFRESH SSL + NGINX"
    echo "=============================================="
    echo

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ]; then
        printf "${RED}Domain belum ditemukan.${RESET}\n"
        pause
        return
    fi

    echo "Domain : $DOMAIN"
    echo
    echo "[INFO] Menjalankan refresh SSL dan Nginx..."
    echo

    if RECOVERY_MODE=1 \
       DOMAIN="$DOMAIN" \
       bash "$BASE/bin/setup-stack.sh"; then

        echo
        printf "${GREEN}● Refresh SSL + Nginx berhasil.${RESET}\n"
    else
        echo
        printf "${RED}● Refresh SSL + Nginx gagal.${RESET}\n"
    fi

    echo
    echo "Status:"
    echo "Nginx : $(systemctl is-active nginx)"
    echo "Xray  : $(systemctl is-active xray)"

    pause
}

domain_ssl_menu() {
    while true; do
        clear

        echo "=============================================="
        echo "             DOMAIN & SSL MANAGER"
        echo "=============================================="
        echo
	echo "[1] Lihat Domain Aktif"
	echo "[2] Detail SSL"
	echo "[3] Cek DNS"
	echo "[4] Test HTTPS"
	echo "[5] Refresh SSL + Nginx"
	echo "[0] Kembali"
        echo

        read -rp "Pilih menu: " MENU

        case "$MENU" in
            1)
                show_domain
                ;;
            2)
                show_ssl
                ;;
            3)
                check_DNS
		;;
            4)
                test_https
                ;;
            5)
                refresh_ssl_nginx
                ;;
            0)
                return
                ;;
            *)
                echo
                echo "Pilihan tidak valid."
                sleep 1
                ;;
        esac
    done
}

domain_ssl_menu
