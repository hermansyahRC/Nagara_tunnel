#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/nagara-tunnel"
DB="$BASE/users/users.db"
SYNC="$BASE/bin/sync-users.sh"
SYSTEM_CONF="$BASE/config/system.conf"

VMESS_WS_PORT="10002"
VMESS_GRPC_PORT="10004"
VMESS_WS_PATH="/vmess-ws"
VMESS_GRPC_SERVICE="vmess-grpc"

DOMAIN=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
RESET='\033[0m'

load_config() {
    if [[ -f "$SYSTEM_CONF" ]]; then
        DOMAIN="$(awk -F= '$1=="DOMAIN" {
            gsub(/^[[:space:]]*"/,"",$2)
            gsub(/"[[:space:]]*$/,"",$2)
            print $2
        }' "$SYSTEM_CONF" | tail -n1)"
    fi

    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$(hostname -f 2>/dev/null || true)"
    fi
}

pause() {
    echo
    read -r -p "Tekan Enter untuk kembali..." _
}

ensure_db() {
    if [[ ! -f "$DB" ]]; then
        echo -e "${RED}Database user tidak ditemukan.${RESET}"
        return 1
    fi
}

username_valid() {
    [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]]
}

user_exists() {
    local username="$1"
    awk -F'|' -v u="$username" '$1==u {found=1} END{exit !found}' "$DB"
}

get_user_line() {
    local username="$1"
    awk -F'|' -v u="$username" '$1==u && $2=="vmess" {print; exit}' "$DB"
}

get_status() {
    local username="$1"
    local line
    line="$(get_user_line "$username")"
    [[ -n "$line" ]] && echo "$line" | cut -d'|' -f7
}

get_expired() {
    local username="$1"
    local line
    line="$(get_user_line "$username")"
    [[ -n "$line" ]] && echo "$line" | cut -d'|' -f5
}

is_date_expired() {
    local expired="$1"
    [[ "$expired" < "$(date +%F)" ]]
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_password() {
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}

sync_xray() {
    echo
    echo -e "${CYAN}Sinkronisasi Xray...${RESET}"

    if [[ ! -x "$SYNC" ]]; then
        echo -e "${RED}sync-users.sh tidak ditemukan/executable.${RESET}"
        return 1
    fi

    if ! "$SYNC"; then
        echo -e "${RED}Sinkronisasi Xray gagal.${RESET}"
        return 1
    fi
}

add_user() {
    clear
    echo "==================== TAMBAH VMESS ===================="
    echo

    read -r -p "Username       : " username

    if ! username_valid "$username"; then
        echo -e "${RED}Username hanya boleh huruf, angka, titik, underscore, dan tanda minus.${RESET}"
        pause
        return
    fi

    if user_exists "$username"; then
        echo -e "${RED}Username sudah ada.${RESET}"
        pause
        return
    fi

    read -r -p "Masa aktif (hari): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]] || (( days < 1 )); then
        echo -e "${RED}Masa aktif tidak valid.${RESET}"
        pause
        return
    fi

    read -r -p "Max device     : " max_device
    if ! [[ "$max_device" =~ ^[0-9]+$ ]] || (( max_device < 1 )); then
        echo -e "${RED}Max device tidak valid.${RESET}"
        pause
        return
    fi

    local uuid created expired
    uuid="$(generate_uuid)"
    created="$(date +%F)"
    expired="$(date -d "+${days} days" +%F)"

    printf '%s|vmess|%s|%s|%s|%s|ACTIVE\n' \
        "$username" "$uuid" "$created" "$expired" "$max_device" >> "$DB"

    chmod 600 "$DB"

    echo
    echo -e "${GREEN}User VMess berhasil dibuat.${RESET}"
    echo
    echo "Username : $username"
    echo "UUID     : $uuid"
    echo "Created  : $created"
    echo "Expired  : $expired"
    echo "Max Dev  : $max_device"
    echo "Status   : ACTIVE"

    if ! sync_xray; then
        echo
        echo -e "${RED}Peringatan: user tersimpan, tetapi sinkronisasi Xray gagal.${RESET}"
    fi

    echo
    generate_links_for_user "$username"
    pause
}

list_users() {
    clear
    echo "==================== DAFTAR VMESS ===================="
    echo

    printf "%-18s %-12s %-12s %-10s %-10s\n" \
        "USERNAME" "CREATED" "EXPIRED" "DEVICE" "STATUS"
    printf "%-18s %-12s %-12s %-10s %-10s\n" \
        "------------------" "------------" "------------" "----------" "----------"

    while IFS='|' read -r username protocol credential created expired max_device status; do
        [[ "$protocol" != "vmess" ]] && continue

        local display_status="$status"

        if is_date_expired "$expired"; then
            display_status="EXPIRED"
        fi

        printf "%-18s %-12s %-12s %-10s %-10s\n" \
            "$username" "$created" "$expired" "$max_device" "$display_status"
    done < "$DB"

    pause
}

select_vmess_user() {
    echo
    echo "================ PILIH USER VMESS ================"
    echo
    local users=()
    local line username protocol credential created expired maxdev status
    local n=0

    while IFS='|' read -r username protocol credential created expired maxdev status; do
        [ "$protocol" = "vmess" ] || continue
        [ -n "$username" ] || continue

        n=$((n + 1))
        users+=("$username")

        local display_status="$status"
        if is_date_expired "$expired"; then
            display_status="EXPIRED"
        fi

        printf "[%2d] %-18s %-12s %-10s\\n" \
            "$n" "$username" "$expired" "$display_status"
    done < "$DB"

    if [ "$n" -eq 0 ]; then
        echo "Tidak ada user VMess."
        return 1
    fi

    echo
    echo "[ 0] Kembali"
    echo
    read -rp "Pilih nomor: " choice

    if [ "$choice" = "0" ]; then
        return 1
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$n" ]; then
        echo "Pilihan tidak valid."
        return 1
    fi

    SELECTED_USERNAME="${users[$((choice - 1))]}"
    return 0
}

user_info() {
    clear
    echo "================== INFORMASI VMESS =================="
    echo

    if ! select_vmess_user; then
        return
    fi

    username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VMess tidak ditemukan.${RESET}"
        pause
        return
    fi

    IFS='|' read -r _ protocol credential created expired max_device status <<< "$line"

    if is_date_expired "$expired"; then
        status="EXPIRED"
    fi

    echo
    echo "Username : $username"
    echo "Protocol : VMess"
    echo "UUID     : $credential"
    echo "Created  : $created"
    echo "Expired  : $expired"
    echo "Max Dev  : $max_device"
    echo "Status   : $status"
    echo "Domain   : $DOMAIN"
    echo "WS Port  : $VMESS_WS_PORT"
    echo "WS Path  : $VMESS_WS_PATH"
    echo "gRPC Port: $VMESS_GRPC_PORT"
    echo "Service  : $VMESS_GRPC_SERVICE"

    pause
}

renew_user() {
    clear
    echo "==================== RENEW VMESS ===================="
    echo

    if ! select_vmess_user; then
        return
    fi

    username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VMess tidak ditemukan.${RESET}"
        pause
        return
    fi

    IFS='|' read -r _ _ _ created expired max_device status <<< "$line"

    read -r -p "Tambah masa aktif (hari): " days

    if ! [[ "$days" =~ ^[0-9]+$ ]] || (( days < 1 )); then
        echo -e "${RED}Jumlah hari tidak valid.${RESET}"
        pause
        return
    fi

    local base_date new_expired
    if is_date_expired "$expired"; then
        base_date="$(date +%F)"
    else
        base_date="$expired"
    fi

    new_expired="$(date -d "$base_date + ${days} days" +%F)"

    awk -F'|' -v OFS='|' \
        -v u="$username" -v e="$new_expired" \
        '$1==u && $2=="vmess" {$5=e; $7="ACTIVE"} {print}' \
        "$DB" > "$DB.tmp"

    mv "$DB.tmp" "$DB"
    chmod 600 "$DB"

    echo
    echo -e "${GREEN}User berhasil di-renew.${RESET}"
    echo "Username : $username"
    echo "Expired  : $new_expired"
    echo "Status   : ACTIVE"

    sync_xray || true
    pause
}

delete_user() {
    clear
    echo "==================== HAPUS VMESS ===================="
    echo

    if ! select_vmess_user; then
        return
    fi

    username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VMess tidak ditemukan.${RESET}"
        pause
        return
    fi

    echo
    echo "User ditemukan: $username"
    read -r -p "Yakin hapus user ini? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Dibatalkan."
        pause
        return
    fi

    awk -F'|' -v OFS='|' -v u="$username" \
        '!( $1==u && $2=="vmess" ) {print}' \
        "$DB" > "$DB.tmp"

    mv "$DB.tmp" "$DB"
    chmod 600 "$DB"

    echo
    echo -e "${GREEN}User berhasil dihapus dari database.${RESET}"

    sync_xray || true
    pause
}

change_status() {
    local action="$1"
    local target_status="$2"
    local title="$3"

    clear
    echo "==================== $title ===================="
    echo

    if ! select_vmess_user; then
        return
    fi

    username="$SELECTED_USERNAME"

    local line
    line="$(get_user_line "$username")"

    if [[ -z "$line" ]]; then
        echo -e "${RED}User VMess tidak ditemukan.${RESET}"
        pause
        return
    fi

    awk -F'|' -v OFS='|' \
        -v u="$username" -v s="$target_status" \
        '$1==u && $2=="vmess" {$7=s} {print}' \
        "$DB" > "$DB.tmp"

    mv "$DB.tmp" "$DB"
    chmod 600 "$DB"

    echo
    echo -e "${GREEN}Status user diubah menjadi $target_status.${RESET}"

    sync_xray || true
    pause
}

generate_links_for_user() {
    local username="$1"

    local line uuid expired
    line="$(get_user_line "$username")"

    [[ -z "$line" ]] && return 1

    uuid="$(echo "$line" | cut -d'|' -f3)"
    expired="$(echo "$line" | cut -d'|' -f5)"

    local json_ws json_http json_grpc
    local link_ws link_http link_grpc

    json_ws="$(cat <<JSON
{
  "v": "2",
  "ps": "${username}-VMESS-WS-TLS",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${uuid}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${VMESS_WS_PATH}",
  "tls": "tls",
  "sni": "${DOMAIN}"
}
JSON
)"

    json_http="$(cat <<JSON
{
  "v": "2",
  "ps": "${username}-VMESS-WS-80",
  "add": "${DOMAIN}",
  "port": "80",
  "id": "${uuid}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${VMESS_WS_PATH}",
  "tls": ""
}
JSON
)"

    json_grpc="$(cat <<JSON
{
  "v": "2",
  "ps": "${username}-VMESS-GRPC",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${uuid}",
  "aid": "0",
  "scy": "auto",
  "net": "grpc",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${VMESS_GRPC_SERVICE}",
  "tls": "tls",
  "sni": "${DOMAIN}"
}
JSON
)"

    link_ws="vmess://$(printf '%s' "$json_ws" | base64 -w 0)"
    link_http="vmess://$(printf '%s' "$json_http" | base64 -w 0)"
    link_grpc="vmess://$(printf '%s' "$json_grpc" | base64 -w 0)"

    echo
    echo "==================== VMESS LINKS ===================="
    echo
    echo "Username : $username"
    echo "Expired  : $expired"
    echo "Domain   : $DOMAIN"
    echo
    echo "---------------- VMESS WS TLS ----------------"
    echo "Server   : $DOMAIN"
    echo "Port     : 443"
    echo "Security : TLS"
    echo "Network  : WebSocket"
    echo "Path     : $VMESS_WS_PATH"
    echo
    echo "$link_ws"
    echo
    echo "---------------- VMESS WS NON-TLS -------------"
    echo "Server   : $DOMAIN"
    echo "Port     : 80"
    echo "Security : NONE"
    echo "Network  : WebSocket"
    echo "Path     : $VMESS_WS_PATH"
    echo
    echo "$link_http"
    echo
    echo "---------------- VMESS gRPC TLS ----------------"
    echo "Server   : $DOMAIN"
    echo "Port     : 443"
    echo "Security : TLS"
    echo "Network  : gRPC"
    echo "Service  : $VMESS_GRPC_SERVICE"
    echo
    echo "$link_grpc"
    echo
}

generate_link() {
    clear
    echo "================ GENERATE VMESS LINK ================"
    echo

    if ! select_vmess_user; then
        return
    fi

    username="$SELECTED_USERNAME"

    if [[ -z "$(get_user_line "$username")" ]]; then
        echo -e "${RED}User VMess tidak ditemukan.${RESET}"
        pause
        return
    fi

    generate_links_for_user "$username"
    pause
}

check_connection() {
    clear
    echo "================== CEK KONEKSI VMESS ================="
    echo

    if ! select_vmess_user; then
        return
    fi

    local username="$SELECTED_USERNAME"

    echo
    echo "User            : $username"
    echo

    echo "Domain          : $DOMAIN"
    echo "WS Backend      : $VMESS_WS_PORT"
    echo "WS Path         : $VMESS_WS_PATH"
    echo "gRPC Backend    : $VMESS_GRPC_PORT"
    echo "gRPC Service    : $VMESS_GRPC_SERVICE"
    echo

    if ss -lnt 2>/dev/null | grep -q ":${VMESS_WS_PORT} "; then
        echo -e "Port ${VMESS_WS_PORT} : ${GREEN}OPEN / LISTENING${RESET}"
    else
        echo -e "Port ${VMESS_WS_PORT} : ${RED}NOT LISTENING${RESET}"
    fi

    if ss -lnt 2>/dev/null | grep -q ":${VMESS_GRPC_PORT} "; then
        echo -e "Port ${VMESS_GRPC_PORT} : ${GREEN}OPEN / LISTENING${RESET}"
    else
        echo -e "Port ${VMESS_GRPC_PORT} : ${RED}NOT LISTENING${RESET}"
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

    pause
}

menu() {
    while true; do
        clear

        echo "======================================================"
        echo "              NAGARA TUNNEL - VMESS"
        echo "======================================================"
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
        echo
        echo "  [ 0 ] Kembali"
        echo
        read -r -p "Pilih menu [0-11]: " choice

        case "$choice" in
            1) add_user ;;
            2) list_users ;;
            3) user_info ;;
            4) renew_user ;;
            5) delete_user ;;
            6) change_status "freeze" "FROZEN" "FREEZE VMESS" ;;
            7) change_status "unfreeze" "ACTIVE" "UNFREEZE VMESS" ;;
            8) change_status "ban" "BANNED" "BAN VMESS" ;;
            9) change_status "unban" "ACTIVE" "UNBAN VMESS" ;;
            10) check_connection ;;
            11) generate_link ;;
            0) clear; return ;;
            *) echo -e "${RED}Pilihan tidak valid.${RESET}"; sleep 1 ;;
        esac
    done
}

load_config
ensure_db || exit 1
menu
