#!/bin/bash

BASE="/opt/nagara-tunnel"
DB="$BASE/users/users.db"
SYNC="$BASE/bin/sync-users.sh"

DOMAIN="$(awk -F= '/^DOMAIN=/{gsub(/"/,"",$2); print $2}' "$BASE/config/system.conf" 2>/dev/null)"
TROJAN_PORT="10003"

RESET='\033[0m'
BOLD='\033[1m'
WHITE='\033[97m'
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'

mkdir -p "$BASE/users"
touch "$DB"
chmod 600 "$DB"

pause_menu() {
    echo
    read -rp "Tekan Enter untuk kembali..."
}

generate_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 12
    else
        tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 24
        echo
    fi
}

sync_xray() {
    echo
    echo -e "${CYAN}Sinkronisasi Xray...${RESET}"
    "$SYNC"
}

username_exists() {
    awk -F'|' -v u="$1" '$1==u {found=1} END {exit !found}' "$DB"
}

get_user_line() {
    awk -F'|' -v u="$1" '$1==u {print; exit}' "$DB"
}

replace_user() {
    local username="$1"
    local newline="$2"
    local tmp

    tmp="$(mktemp)"

    awk -F'|' -v u="$username" -v n="$newline" '
        $1==u {$0=n}
        {print}
    ' "$DB" > "$tmp"

    cat "$tmp" > "$DB"
    rm -f "$tmp"

    chmod 600 "$DB"
}

add_user() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "              TROJAN - TAMBAH USER"
    echo "================================================"
    echo -e "${RESET}"

    read -rp "Username: " username

    if [ -z "$username" ]; then
        echo -e "${RED}Username tidak boleh kosong.${RESET}"
        pause_menu
        return
    fi

    if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo -e "${RED}Username hanya boleh huruf, angka, titik, garis bawah, atau minus.${RESET}"
        pause_menu
        return
    fi

    if username_exists "$username"; then
        echo -e "${RED}Username sudah ada.${RESET}"
        pause_menu
        return
    fi

    read -rp "Masa aktif (hari) [30]: " days
    days="${days:-30}"

    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
        echo -e "${RED}Jumlah hari tidak valid.${RESET}"
        pause_menu
        return
    fi

    read -rp "Max device [2]: " max_device
    max_device="${max_device:-2}"

    if ! [[ "$max_device" =~ ^[0-9]+$ ]] || [ "$max_device" -lt 1 ]; then
        echo -e "${RED}Max device tidak valid.${RESET}"
        pause_menu
        return
    fi

    local created
    local expired
    local password

    created="$(date +%Y-%m-%d)"
    expired="$(date -d "+${days} days" +%Y-%m-%d)"
    password="$(generate_password)"

    echo
    echo "Username : $username"
    echo "Protocol : trojan"
    echo "Created  : $created"
    echo "Expired  : $expired"
    echo "Max Dev  : $max_device"
    echo "Password : $password"
    echo

    read -rp "Simpan user ini? [y/N]: " confirm

    case "$confirm" in
        y|Y)
            printf '%s|trojan|%s|%s|%s|%s|ACTIVE\n' \
                "$username" \
                "$password" \
                "$created" \
                "$expired" \
                "$max_device" >> "$DB"

            chmod 600 "$DB"

            echo
            echo -e "${GREEN}User Trojan berhasil dibuat.${RESET}"

            sync_xray

            echo
            echo -e "${CYAN}Trojan Link:${RESET}"
            generate_link "$username"

            pause_menu
            ;;

        *)
            echo "Dibatalkan."
            pause_menu
            ;;
    esac
}

list_users() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "                DAFTAR TROJAN"
    echo "================================================"
    echo -e "${RESET}"

    printf "%-16s %-12s %-12s %-10s\n" \
        "USERNAME" "EXPIRED" "STATUS" "MAXDEV"

    echo "------------------------------------------------"

    awk -F'|' '
        $2=="trojan" {
            printf "%-16s %-12s %-12s %-10s\n",
                $1,$5,$7,$6
        }
    ' "$DB"

    echo
    pause_menu
}

user_info() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "             INFORMASI TROJAN"
    echo "================================================"
    echo -e "${RESET}"

    read -rp "Username: " username

    local line
    line="$(get_user_line "$username")"

    if [ -z "$line" ]; then
        echo -e "${RED}User tidak ditemukan.${RESET}"
        pause_menu
        return
    fi

    IFS='|' read -r name protocol credential created expired max_device status <<< "$line"

    if [ "$protocol" != "trojan" ]; then
        echo -e "${RED}User tersebut bukan user Trojan.${RESET}"
        pause_menu
        return
    fi

    echo
    echo "Username   : $name"
    echo "Protocol   : $protocol"
    echo "Password   : $credential"
    echo "Created    : $created"
    echo "Expired    : $expired"
    echo "Max Device : $max_device"
    echo "Status     : $status"
    echo "Domain     : $DOMAIN"
    echo "Port       : $TROJAN_PORT"

    echo
    pause_menu
}

renew_user() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "                RENEW TROJAN"
    echo "================================================"
    echo -e "${RESET}"

    read -rp "Username: " username

    local line
    line="$(get_user_line "$username")"

    if [ -z "$line" ]; then
        echo -e "${RED}User tidak ditemukan.${RESET}"
        pause_menu
        return
    fi

    IFS='|' read -r name protocol credential created expired max_device status <<< "$line"

    if [ "$protocol" != "trojan" ]; then
        echo -e "${RED}User tersebut bukan user Trojan.${RESET}"
        pause_menu
        return
    fi

    read -rp "Tambah berapa hari? [30]: " days
    days="${days:-30}"

    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
        echo -e "${RED}Jumlah hari tidak valid.${RESET}"
        pause_menu
        return
    fi

    local base_date
    local today
    local new_expired

    today="$(date +%Y-%m-%d)"

    if [[ "$expired" > "$today" ]]; then
        base_date="$expired"
    else
        base_date="$today"
    fi

    new_expired="$(date -d "$base_date +${days} days" +%Y-%m-%d)"

    replace_user "$username" \
        "$name|$protocol|$credential|$created|$new_expired|$max_device|ACTIVE"

    echo
    echo -e "${GREEN}User berhasil diperpanjang.${RESET}"
    echo "Expired baru: $new_expired"

    sync_xray
    pause_menu
}

delete_user() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "                HAPUS TROJAN"
    echo "================================================"
    echo -e "${RESET}"

    read -rp "Username: " username

    local line
    line="$(get_user_line "$username")"

    if [ -z "$line" ]; then
        echo -e "${RED}User tidak ditemukan.${RESET}"
        pause_menu
        return
    fi

    IFS='|' read -r name protocol credential created expired max_device status <<< "$line"

    if [ "$protocol" != "trojan" ]; then
        echo -e "${RED}User tersebut bukan user Trojan.${RESET}"
        pause_menu
        return
    fi

    echo
    echo "Username : $name"
    echo "Expired  : $expired"
    echo

    read -rp "Yakin hapus user ini? [y/N]: " confirm

    case "$confirm" in
        y|Y)
            local tmp
            tmp="$(mktemp)"

            awk -F'|' -v u="$username" '$1!=u {print}' "$DB" > "$tmp"
            cat "$tmp" > "$DB"
            rm -f "$tmp"

            chmod 600 "$DB"

            echo -e "${GREEN}User berhasil dihapus.${RESET}"

            sync_xray
            pause_menu
            ;;

        *)
            echo "Dibatalkan."
            pause_menu
            ;;
    esac
}

change_status() {

    local username="$1"
    local new_status="$2"

    local line
    line="$(get_user_line "$username")"

    if [ -z "$line" ]; then
        echo -e "${RED}User tidak ditemukan.${RESET}"
        return 1
    fi

    IFS='|' read -r name protocol credential created expired max_device status <<< "$line"

    if [ "$protocol" != "trojan" ]; then
        echo -e "${RED}User tersebut bukan user Trojan.${RESET}"
        return 1
    fi

    replace_user "$username" \
        "$name|$protocol|$credential|$created|$expired|$max_device|$new_status"

    return 0
}

freeze_user() {

    clear
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo -e "${CYAN}${BOLD}                 FREEZE TROJAN${RESET}"
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo

    read -rp "Username: " username

    if change_status "$username" "FROZEN"; then
        echo
        echo -e "${YELLOW}User berhasil di-FREEZE.${RESET}"
        sync_xray
    fi

    pause_menu
}

unfreeze_user() {

    clear
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo -e "${CYAN}${BOLD}                UNFREEZE TROJAN${RESET}"
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo

    read -rp "Username: " username

    if change_status "$username" "ACTIVE"; then
        echo
        echo -e "${GREEN}User berhasil di-UNFREEZE.${RESET}"
        sync_xray
    fi

    pause_menu
}

ban_user() {

    clear
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo -e "${CYAN}${BOLD}                  BAN TROJAN${RESET}"
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo

    read -rp "Username: " username

    if change_status "$username" "BANNED"; then
        echo
        echo -e "${RED}User berhasil di-BAN.${RESET}"
        sync_xray
    fi

    pause_menu
}

unban_user() {

    clear
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo -e "${CYAN}${BOLD}                 UNBAN TROJAN${RESET}"
    echo -e "${CYAN}${BOLD}================================================${RESET}"
    echo

    read -rp "Username: " username

    if change_status "$username" "ACTIVE"; then
        echo
        echo -e "${GREEN}User berhasil di-UNBAN.${RESET}"
        sync_xray
    fi

    pause_menu
}

check_connection() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "              CEK KONEKSI TROJAN"
    echo "================================================"
    echo -e "${RESET}"

    echo "Port Trojan : $TROJAN_PORT"
    echo

    if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${TROJAN_PORT}$"; then
        echo -e "Port ${TROJAN_PORT} : ${GREEN}OPEN / LISTENING${RESET}"
    else
        echo -e "Port ${TROJAN_PORT} : ${RED}TIDAK LISTENING${RESET}"
    fi

    echo
    echo "Xray:"
    systemctl is-active xray 2>/dev/null || true

    echo
    echo "Socket:"
    ss -lntp 2>/dev/null | grep ":${TROJAN_PORT}" || echo "Tidak ditemukan."

    pause_menu
}

generate_link() {

    local username="$1"
    local line

    line="$(get_user_line "$username")"

    if [ -z "$line" ]; then
        echo -e "${RED}User tidak ditemukan.${RESET}"
        return 1
    fi

    IFS='|' read -r name protocol password created expired max_device status <<< "$line"

    if [ "$protocol" != "trojan" ]; then
        echo -e "${RED}User tersebut bukan user Trojan.${RESET}"
        return 1
    fi

    local encoded_name

    encoded_name="$(printf '%s' "$name" | sed 's/ /%20/g')"

    echo
    echo "trojan://${password}@${DOMAIN}:${TROJAN_PORT}#${encoded_name}"
}

generate_link_menu() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "              GENERATE TROJAN LINK"
    echo "================================================"
    echo -e "${RESET}"

    read -rp "Username: " username

    generate_link "$username"

    echo
    pause_menu
}

# ============================================================
# MAIN MENU
# ============================================================

while true; do

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                TROJAN MANAGER                 ║"
    echo "╠════════════════════════════════════════════════╣"
    echo -e "${RESET}"

    echo "  [ 1 ] Tambah User"
    echo "  [ 2 ] Daftar User"
    echo "  [ 3 ] Informasi User"
    echo "  [ 4 ] Renew User"
    echo "  [ 5 ] Hapus User"
    echo "  [ 6 ] Freeze User"
    echo "  [ 7 ] Unfreeze User"
    echo "  [ 8 ] Ban User"
    echo "  [ 9 ] Unban User"
    echo "  [10 ] Cek Koneksi"
    echo "  [11 ] Generate Link"
    echo "  [ 0 ] Kembali"

    echo
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${RESET}"
    echo

    read -rp "Pilih menu: " menu

    case "$menu" in
        1) add_user ;;
        2) list_users ;;
        3) user_info ;;
        4) renew_user ;;
        5) delete_user ;;
        6) freeze_user ;;
        7) unfreeze_user ;;
        8) ban_user ;;
        9) unban_user ;;
        10) check_connection ;;
        11) generate_link_menu ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid.${RESET}"
            sleep 1
            ;;
    esac

done
