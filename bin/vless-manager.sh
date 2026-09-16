#!/usr/bin/env bash

BASE="/opt/nagara-tunnel"
DB="$BASE/users/users.db"
SYNC="$BASE/bin/sync-users.sh"
SYSTEM_CONF="$BASE/config/system.conf"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

DOMAIN=""
VLESS_PORT="10001"
VLESS_PATH="/nagara-ws"

load_config() {
    if [[ -f "$SYSTEM_CONF" ]]; then
        DOMAIN="$(awk -F= '$1=="DOMAIN" {gsub(/^[[:space:]]*"/,"",$2); gsub(/"[[:space:]]*$/,"",$2); print $2}' "$SYSTEM_CONF" | tail -n1)"
    fi

    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$(hostname -f 2>/dev/null || true)"
    fi
}

pause_screen() {
    echo
    read -rp "Tekan Enter untuk kembali..."
}

valid_username() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]
}

user_exists() {
    local username="$1"
    awk -F'|' -v u="$username" '$1==u && $2=="vless" {found=1} END{exit !found}' "$DB"
}

get_user_line() {
    local username="$1"
    awk -F'|' -v u="$username" '$1==u && $2=="vless" {print; exit}' "$DB"
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

sync_xray() {
    echo
    echo -e "${CYAN}Sinkronisasi Xray...${RESET}"

    if [[ ! -x "$SYNC" ]]; then
        chmod +x "$SYNC" 2>/dev/null || true
    fi

    "$SYNC"
}

add_user() {
    clear
    echo -e "${CYAN}${BOLD}==================== TAMBAH VLESS ====================${RESET}"
    echo

    read -rp "Username: " username
    username="${username// /}"

    if ! valid_username "$username"; then
        echo -e "${RED}Username tidak valid.${RESET}"
        echo "Gunakan huruf, angka, underscore (_) atau dash (-), maksimal 32 karakter."
        pause_screen
        return
    fi

    if user_exists "$username"; then
        echo -e "${RED}User VLESS '$username' sudah ada.${RESET}"
        pause_screen
        return
    fi

    read -rp "Masa aktif (hari) [30]: " days
    days="${days:-30}"

    if ! [[ "$days" =~ ^[0-9]+$ ]] || (( days < 1 || days > 3650 )); then
        echo -e "${RED}Masa aktif harus 1-3650 hari.${RESET}"
        pause_screen
        return
    fi

    read -rp "Max device [2]: " max_device
    max_device="${max_device:-2}"

    if ! [[ "$max_device" =~ ^[0-9]+$ ]] || (( max_device < 1 || max_device > 100 )); then
        echo -e "${RED}Max device harus 1-100.${RESET}"
        pause_screen
        return
    fi

    local credential created expired
    credential="$(generate_uuid)"
    created="$(date +%F)"
    expired="$(date -d "+${days} days" +%F)"

    printf '%s|vless|%s|%s|%s|%s|ACTIVE\n' \
        "$username" "$credential" "$created" "$expired" "$max_device" >> "$DB"

    chmod 600 "$DB"

    echo
    echo -e "${GREEN}User VLESS berhasil dibuat.${RESET}"
    echo "Username : $username"
    echo "Created  : $created"
    echo "Expired  : $expired"
    echo "Max Dev  : $max_device"

    sync_xray

    echo
    generate_link "$username"
    pause_screen
}

list_users() {
    clear
    echo -e "${CYAN}${BOLD}==================== DAFTAR VLESS ====================${RESET}"
    echo

    if ! grep -q '|vless|' "$DB" 2>/dev/null; then
        echo "Belum ada user VLESS."
        pause_screen
        return
    fi

    printf "%-18s %-12s %-12s %-10s %-10s\n" \
        "USERNAME" "CREATED" "EXPIRED" "DEVICE" "STATUS"
    printf "%-18s %-12s %-12s %-10s %-10s\n" \
        "------------------" "------------" "------------" "----------" "----------"

    while IFS='|' read -r username protocol credential created expired max_device status; do
        [[ "$protocol" == "vless" ]] || continue

        local display_status="$status"

        if [[ "$expired" < "$(date +%F)" && "$status" == "ACTIVE" ]]; then
            display_status="EXPIRED"
        fi

        printf "%-18s %-12s %-12s %-10s %-10s\n" \
            "$username" "$created" "$expired" "$max_device" "$display_status"
    done < "$DB"

    pause_screen
}

select_vless_user() {
    echo
    echo "================ PILIH USER VLESS ================"
    echo

    local users=()
    local username protocol credential created expired maxdev status
    local n=0

    while IFS='|' read -r username protocol credential created expired maxdev status; do
        [ "$protocol" = "vless" ] || continue
        [ -n "$username" ] || continue

        n=$((n + 1))
        users+=("$username")

        local display_status="$status"
        if [[ "$expired" < "$(date +%F)" && "$status" == "ACTIVE" ]]; then
            display_status="EXPIRED"
        fi

        printf "[%2d] %-18s %-12s %-10s\n" \
            "$n" "$username" "$expired" "$display_status"
    done < "$DB"

    if [ "$n" -eq 0 ]; then
        echo "Tidak ada user VLESS."
        return 1
    fi

    echo
    echo "[ 0] Kembali"
    echo
    read -rp "Pilih nomor: " choice

    if [ "$choice" = "0" ]; then
        return 1
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || \
       [ "$choice" -lt 1 ] || [ "$choice" -gt "$n" ]; then
        echo "Pilihan tidak valid."
        return 1
    fi

    SELECTED_USERNAME="${users[$((choice - 1))]}"
    return 0
}

user_info() {
    clear
    echo -e "${CYAN}${BOLD}================== INFORMASI VLESS ==================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    IFS='|' read -r u protocol credential created expired max_device status <<< "$line"

    echo
    echo -e "${WHITE}Username : ${RESET}$u"
    echo -e "${WHITE}Protocol : ${RESET}VLESS"
    echo -e "${WHITE}UUID     : ${RESET}$credential"
    echo -e "${WHITE}Created  : ${RESET}$created"
    echo -e "${WHITE}Expired  : ${RESET}$expired"
    echo -e "${WHITE}Max Dev  : ${RESET}$max_device"
    echo -e "${WHITE}Status   : ${RESET}$status"
    echo -e "${WHITE}Domain   : ${RESET}$DOMAIN"
    echo -e "${WHITE}Port     : ${RESET}$VLESS_PORT"
    echo -e "${WHITE}Path     : ${RESET}$VLESS_PATH"

    pause_screen
}

renew_user() {
    clear
    echo -e "${CYAN}${BOLD}==================== RENEW VLESS ====================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    IFS='|' read -r u protocol credential created expired max_device status <<< "$line"

    echo "Username : $u"
    echo "Expired  : $expired"
    echo

    read -rp "Tambah berapa hari? [30]: " days
    days="${days:-30}"

    if ! [[ "$days" =~ ^[0-9]+$ ]] || (( days < 1 || days > 3650 )); then
        echo -e "${RED}Jumlah hari harus 1-3650.${RESET}"
        pause_screen
        return
    fi

    local base_date new_expired today
    today="$(date +%F)"

    if [[ "$expired" > "$today" ]]; then
        base_date="$expired"
    else
        base_date="$today"
    fi

    new_expired="$(date -d "$base_date +${days} days" +%F)"

    awk -F'|' -v OFS='|' \
        -v u="$username" -v e="$new_expired" \
        'BEGIN{found=0}
         $1==u && $2=="vless" {
             $5=e
             $7="ACTIVE"
             found=1
         }
         {print}
         END{if(!found) exit 1}' "$DB" > "$DB.tmp" && mv "$DB.tmp" "$DB"

    chmod 600 "$DB"

    echo
    echo -e "${GREEN}User berhasil di-RENEW.${RESET}"
    echo "Username : $username"
    echo "Expired  : $new_expired"

    sync_xray
    pause_screen
}

delete_user() {
    clear
    echo -e "${CYAN}${BOLD}=================== HAPUS VLESS ====================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    IFS='|' read -r u protocol credential created expired max_device status <<< "$line"

    echo
    echo "Username : $u"
    echo "Expired  : $expired"
    echo
    read -rp "Yakin hapus user ini? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Dibatalkan."
        pause_screen
        return
    fi

    awk -F'|' -v u="$username" \
        '$1!=u || $2!="vless"' "$DB" > "$DB.tmp" && mv "$DB.tmp" "$DB"

    chmod 600 "$DB"

    echo -e "${GREEN}User berhasil dihapus.${RESET}"

    sync_xray
    pause_screen
}

change_status() {
    local username="$1"
    local new_status="$2"

    awk -F'|' -v OFS='|' \
        -v u="$username" -v s="$new_status" \
        'BEGIN{found=0}
         $1==u && $2=="vless" {
             $7=s
             found=1
         }
         {print}
         END{if(!found) exit 1}' "$DB" > "$DB.tmp" || {
            rm -f "$DB.tmp"
            return 1
        }

    mv "$DB.tmp" "$DB"
    chmod 600 "$DB"
    return 0
}

freeze_user() {
    clear
    echo -e "${CYAN}${BOLD}=================== FREEZE VLESS ===================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    if ! user_exists "$username"; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    if change_status "$username" "FROZEN"; then
        echo -e "${YELLOW}User berhasil di-FREEZE.${RESET}"
        sync_xray
    else
        echo -e "${RED}Gagal mengubah status user.${RESET}"
    fi

    pause_screen
}

unfreeze_user() {
    clear
    echo -e "${CYAN}${BOLD}================== UNFREEZE VLESS ==================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    if ! user_exists "$username"; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    if change_status "$username" "ACTIVE"; then
        echo -e "${GREEN}User berhasil di-UNFREEZE.${RESET}"
        sync_xray
    else
        echo -e "${RED}Gagal mengubah status user.${RESET}"
    fi

    pause_screen
}

ban_user() {
    clear
    echo -e "${CYAN}${BOLD}===================== BAN VLESS =====================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    if ! user_exists "$username"; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    if change_status "$username" "BANNED"; then
        echo -e "${RED}User berhasil di-BAN.${RESET}"
        sync_xray
    else
        echo -e "${RED}Gagal mengubah status user.${RESET}"
    fi

    pause_screen
}

unban_user() {
    clear
    echo -e "${CYAN}${BOLD}==================== UNBAN VLESS ===================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi
    local username="$SELECTED_USERNAME"

    if ! user_exists "$username"; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        pause_screen
        return
    fi

    if change_status "$username" "ACTIVE"; then
        echo -e "${GREEN}User berhasil di-UNBAN.${RESET}"
        sync_xray
    else
        echo -e "${RED}Gagal mengubah status user.${RESET}"
    fi

    pause_screen
}

check_connection() {
    clear
    echo -e "${CYAN}${BOLD}================== CEK KONEKSI VLESS =================${RESET}"
    echo

    if ! select_vless_user; then
        pause_screen
        return
    fi

    local username="$SELECTED_USERNAME"

    echo
    echo "User        : $username"
    echo "Domain      : $DOMAIN"
    echo "Port VLESS  : $VLESS_PORT"
    echo "Path WS     : $VLESS_PATH"
    echo

    if ss -lntp 2>/dev/null | grep -Eq ":${VLESS_PORT}[[:space:]]"; then
        echo -e "Port $VLESS_PORT : ${GREEN}OPEN / LISTENING${RESET}"
    else
        echo -e "Port $VLESS_PORT : ${RED}TIDAK LISTENING${RESET}"
    fi

    echo
    echo "Xray:"
    systemctl is-active xray || true

    echo
    echo "Nginx:"
    systemctl is-active nginx || true

    echo
    echo "Nginx config test:"
    nginx -t 2>&1 || true

    pause_screen
}

generate_link() {
    local username="${1:-}"

    if [[ -z "$username" ]]; then
        clear
        echo -e "${CYAN}${BOLD}================ GENERATE VLESS LINK ================${RESET}"
        echo

        if ! select_vless_user; then
            pause_screen
            return
        fi

        username="$SELECTED_USERNAME"
    fi

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VLESS tidak ditemukan.${RESET}"
        [[ -n "${1:-}" ]] || pause_screen
        return
    fi

    IFS='|' read -r u protocol credential created expired max_device status <<< "$line"

    echo
    echo -e "${GREEN}VLESS WebSocket Link:${RESET}"
    echo
    echo "vless://${credential}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=${VLESS_PATH}#${username}"
    echo
    echo "Catatan: Link menggunakan TLS/Nginx di port 443."
    echo "Xray VLESS backend: 127.0.0.1:${VLESS_PORT}"
    echo
    [[ -n "${1:-}" ]] || pause_screen
}

main_menu() {
    load_config

    while true; do
        clear
        echo -e "${CYAN}${BOLD}======================================================${RESET}"
        echo -e "${CYAN}${BOLD}                 VLESS MANAGER${RESET}"
        echo -e "${CYAN}${BOLD}======================================================${RESET}"
        echo
        echo -e " Domain : ${WHITE}${DOMAIN}${RESET}"
        echo -e " Port   : ${WHITE}${VLESS_PORT}${RESET}"
        echo -e " Path   : ${WHITE}${VLESS_PATH}${RESET}"
        echo
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
        read -rp "Pilih menu: " choice

        case "$choice" in
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
            11) generate_link ;;
            0) return ;;
            *) echo -e "${RED}Pilihan tidak valid.${RESET}"; sleep 1 ;;
        esac
    done
}

main_menu
