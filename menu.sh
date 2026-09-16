#!/bin/bash

BASE="/opt/nagara-tunnel"

# ============================================================
# NAGARA TUNNEL - MAIN DASHBOARD
# ============================================================

# Colors
RESET='\033[0m'
BOLD='\033[1m'
WHITE='\033[97m'
GRAY='\033[90m'
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'

# ============================================================
# SYSTEM INFORMATION
# ============================================================

get_domain() {
    if [ -f "$BASE/config/system.conf" ]; then
        awk -F= '/^DOMAIN=/{gsub(/"/,"",$2); print $2}' \
            "$BASE/config/system.conf"
    else
        echo "-"
    fi
}

get_user_count() {
    if [ -f "$BASE/users/users.db" ]; then
        awk 'NF && $0 !~ /^#/ {count++} END {print count+0}' \
            "$BASE/users/users.db"
    else
        echo "0"
    fi
}

get_protocol_count() {
    local protocol="$1"

    if [ -f "$BASE/users/users.db" ]; then
        awk -F'|' -v p="$protocol" \
            '$2==p && NF {count++} END {print count+0}' \
            "$BASE/users/users.db"
    else
        echo "0"
    fi
}

get_cpu() {
    nproc 2>/dev/null || echo "-"
}

get_ram() {
    free -h 2>/dev/null | awk '/^Mem:/ {print $2}'
}

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/^up //'
}

# ============================================================
# SERVICE STATUS
# ============================================================

service_status() {
    local service="$1"

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        printf "${GREEN}● RUNNING${RESET}"
    else
        printf "${RED}● OFFLINE${RESET}"
    fi
}

get_ssh_status() {
    if systemctl is-active --quiet ssh 2>/dev/null || \
       systemctl is-active --quiet sshd 2>/dev/null; then
        printf "${GREEN}● RUNNING${RESET}"
    else
        printf "${RED}● OFFLINE${RESET}"
    fi
}

get_certbot_status() {
    if systemctl is-enabled --quiet certbot.timer 2>/dev/null && \
       systemctl is-active --quiet certbot.timer 2>/dev/null; then
        printf "${GREEN}● ACTIVE${RESET}"
    else
        printf "${RED}● OFFLINE${RESET}"
    fi
}

get_ssl_status() {

    local DOMAIN
    local CERT_FILE
    local DAYS

    DOMAIN="$(get_domain)"
    CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "-" ]; then
        printf "${RED}● INVALID${RESET}"
        return
    fi

    if [ ! -f "$CERT_FILE" ]; then
        printf "${RED}● INVALID${RESET}"
        return
    fi

    if ! openssl x509 -in "$CERT_FILE" -noout >/dev/null 2>&1; then
        printf "${RED}● INVALID${RESET}"
        return
    fi

    DAYS="$(
        openssl x509 \
            -in "$CERT_FILE" \
            -checkend 2592000 \
            -noout >/dev/null 2>&1
        echo $?
    )"

    if [ "$DAYS" -eq 0 ]; then
        printf "${GREEN}● VALID${RESET}"
    else
        printf "${YELLOW}● EXPIRING${RESET}"
    fi
}

get_network_status() {

    if ip route show default 2>/dev/null | grep -q "default"; then
        printf "${GREEN}● ONLINE${RESET}"
    else
        printf "${RED}● OFFLINE${RESET}"
    fi
}

# ============================================================
# MAIN DASHBOARD
# ============================================================

draw_dashboard() {

    local DOMAIN
    local USER_COUNT
    local VLESS_COUNT
    local VMESS_COUNT
    local TROJAN_COUNT
    local CPU
    local RAM
    local IP
    local UPTIME

    DOMAIN="$(get_domain)"
    USER_COUNT="$(get_user_count)"
    VLESS_COUNT="$(get_protocol_count vless)"
    VMESS_COUNT="$(get_protocol_count vmess)"
    TROJAN_COUNT="$(get_protocol_count trojan)"
    CPU="$(get_cpu)"
    RAM="$(get_ram)"
    IP="$(get_ip)"
    UPTIME="$(get_uptime)"

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    NAGARA TUNNEL                            ║"
    echo "║                  VPS MANAGEMENT PANEL                       ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "${RESET}"

    printf "${WHITE}║${RESET} Host    : ${WHITE}%-48s${RESET}\n" "$(hostname)"
    printf "${WHITE}║${RESET} Domain  : ${WHITE}%-48s${RESET}\n" "$DOMAIN"
    printf "${WHITE}║${RESET} IP      : ${WHITE}%-48s${RESET}\n" "$IP"
    printf "${WHITE}║${RESET} CPU     : ${WHITE}%-48s${RESET}\n" "$CPU Core"
    printf "${WHITE}║${RESET} RAM     : ${WHITE}%-48s${RESET}\n" "$RAM"
    printf "${WHITE}║${RESET} Uptime  : ${WHITE}%-48s${RESET}\n" "$UPTIME"

    echo -e "${CYAN}${BOLD}"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║                         SERVICES                             ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "${RESET}"

    printf "${WHITE}║${RESET} Xray      : $(service_status xray)     "
    printf "Nginx    : $(service_status nginx)\n"

    printf "${WHITE}║${RESET} SSH       : $(get_ssh_status)     "
    printf "Certbot  : $(get_certbot_status)\n"

    printf "${WHITE}║${RESET} SSL       : $(get_ssl_status)     "
    printf "Network  : $(get_network_status)\n"

    echo -e "${CYAN}${BOLD}"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "${RESET}"

    printf "${WHITE}║${RESET} Users   : ${WHITE}%s${RESET}\n" "$USER_COUNT"
    printf "${WHITE}║${RESET} VLESS   : ${WHITE}%s${RESET}\n" "$VLESS_COUNT"
    printf "${WHITE}║${RESET} VMess   : ${WHITE}%s${RESET}\n" "$VMESS_COUNT"
    printf "${WHITE}║${RESET} Trojan  : ${WHITE}%s${RESET}\n" "$TROJAN_COUNT"

    echo -e "${CYAN}${BOLD}"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "${RESET}"

    printf "  ${WHITE}[ 1 ]${RESET} User Manager          ${WHITE}[ 7 ]${RESET} Backup & Restore\n"
    printf "  ${WHITE}[ 2 ]${RESET} VLESS Manager         ${WHITE}[ 8 ]${RESET} Migration VPS\n"
    printf "  ${WHITE}[ 3 ]${RESET} VMess Manager         ${WHITE}[ 9 ]${RESET} Telegram Bot\n"
    printf "  ${WHITE}[ 4 ]${RESET} Trojan Manager        ${WHITE}[10 ]${RESET} Server Settings\n"
    printf "  ${WHITE}[ 5 ]${RESET} Connection Monitor    ${WHITE}[11 ]${RESET} Security & Firewall\n"
    printf "  ${WHITE}[ 6 ]${RESET} Service Manager       ${WHITE}[12 ]${RESET} System Tools\n"
    echo
    printf "                         ${WHITE}[ 0 ]${RESET} Exit\n"

    echo -e "${CYAN}${BOLD}"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ============================================================
# MAIN LOOP
# ============================================================

while true; do

    draw_dashboard

    echo
    read -rp "Pilih menu: " MENU

    case "$MENU" in

        1)
            "$BASE/bin/user-manager.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        2)
            "$BASE/bin/vless-manager.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        3)
            "$BASE/bin/vmess-manager.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        4)
            "$BASE/bin/trojan-manager.sh"
            ;;

        5)
            clear

            if [ -x "$BASE/bin/session-manager.sh" ]; then
                "$BASE/bin/session-manager.sh"
                echo
                read -rp "Tekan Enter untuk kembali..."
            else
                echo
                echo "Connection Monitor belum tersedia."
                read -rp "Tekan Enter untuk kembali..."
            fi
            ;;

        6)
            clear

            echo "================================================"
            echo "              SERVICE MANAGER"
            echo "================================================"
            echo
            echo "1. Status Xray"
            echo "2. Status Nginx"
            echo "3. Restart Xray"
            echo "4. Restart Nginx"
            echo "0. Kembali"
            echo

            read -rp "Pilih: " SERVICE_MENU

            case "$SERVICE_MENU" in

                1)
                    systemctl status xray --no-pager
                    read -rp "Tekan Enter..."
                    ;;

                2)
                    systemctl status nginx --no-pager
                    read -rp "Tekan Enter..."
                    ;;

                3)
                    systemctl restart xray
                    echo
                    systemctl is-active xray
                    read -rp "Tekan Enter..."
                    ;;

                4)
                    systemctl restart nginx
                    echo
                    systemctl is-active nginx
                    read -rp "Tekan Enter..."
                    ;;

            esac
            ;;

        7)
            clear

            echo "================================================"
            echo "             BACKUP & RESTORE"
            echo "================================================"
            echo
            echo "1. Full Backup"
            echo "2. Migration Backup"
            echo "3. Migration Restore"
            echo "4. Restore Dry-Run"
            echo "0. Kembali"
            echo

            read -rp "Pilih: " BACKUP_MENU

            case "$BACKUP_MENU" in

                1)
                    "$BASE/bin/full-backup.sh"
                    read -rp "Tekan Enter..."
                    ;;

                2)
                    "$BASE/bin/migration-backup.sh"
                    read -rp "Tekan Enter..."
                    ;;

                3)
                    "$BASE/bin/migration-restore.sh"
                    read -rp "Tekan Enter..."
                    ;;

                4)
                    "$BASE/bin/migration-restore.sh" --dry-run
                    read -rp "Tekan Enter..."
                    ;;

            esac
            ;;

        8)
            clear

            echo "================================================"
            echo "              MIGRATION VPS"
            echo "================================================"
            echo
            echo "1. Migration Backup"
            echo "2. Migration Restore"
            echo "3. Restore Dry-Run"
            echo "0. Kembali"
            echo

            read -rp "Pilih: " MIGRATION_MENU

            case "$MIGRATION_MENU" in

                1)
                    "$BASE/bin/migration-backup.sh"
                    read -rp "Tekan Enter..."
                    ;;

                2)
                    "$BASE/bin/migration-restore.sh"
                    read -rp "Tekan Enter..."
                    ;;

                3)
                    "$BASE/bin/migration-restore.sh" --dry-run
                    read -rp "Tekan Enter..."
                    ;;

            esac
            ;;

        9)
            clear

            echo "================================================"
            echo "               TELEGRAM BOT"
            echo "================================================"
            echo
            echo "Telegram Bot belum dikonfigurasi."
            echo
            echo "Rencana fitur:"
            echo "- Notifikasi user baru"
            echo "- User expired"
            echo "- Xray/Nginx error"
            echo "- Backup selesai"
            echo "- Server alert"
            echo "- Remote management"
            echo
            read -rp "Tekan Enter untuk kembali..."
            ;;

        10)
            clear

            echo "================================================"
            echo "              SERVER SETTINGS"
            echo "================================================"
            echo
            echo "Server Settings belum diaktifkan."
            echo
            read -rp "Tekan Enter untuk kembali..."
            ;;

        11)
            clear

            echo "================================================"
            echo "           SECURITY & FIREWALL"
            echo "================================================"
            echo
            echo "Security & Firewall belum diaktifkan."
            echo
            read -rp "Tekan Enter untuk kembali..."
            ;;

        12)
            clear

            echo "================================================"
            echo "                SYSTEM TOOLS"
            echo "================================================"
            echo
	    echo "1. System Information"
	    echo "2. Traffic Monitor"
	    echo "3. Traffic History"
	    echo "0. Kembali"
            echo

            read -rp "Pilih: " SYSTEM_MENU

            case "$SYSTEM_MENU" in
                2)
                    "$BASE/bin/traffic-monitor.sh"
                    read -rp "Tekan Enter untuk kembali..."
                    ;;
                3)
                    "$BASE/bin/traffic-history-view.sh"
                    read -rp "Tekan Enter untuk kembali..."
                    ;;
                1)
                    "$BASE/check-system.sh"
                    read -rp "Tekan Enter untuk kembali..."
                    ;;
            esac
            ;;

        0|exit|EXIT|Exit|q|Q)
            clear
            exit 0
            ;;

        *)
            echo
            echo -e "${RED}Pilihan tidak valid.${RESET}"
            sleep 1
            ;;

    esac

done
