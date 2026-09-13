#!/usr/bin/env bash
BASE="/opt/nagara-tunnel"

USER_DIR="/opt/nagara-tunnel/users"
USER_FILE="$USER_DIR/users.db"
SYNC_SCRIPT="/opt/nagara-tunnel/bin/sync-users.sh"
VLESS_LINK="/opt/nagara-tunnel/bin/vless-link.sh"
VMESS_LINK="/opt/nagara-tunnel/bin/vmess-link.sh"

mkdir -p "$USER_DIR"
touch "$USER_FILE"

# =========================================================
# MIGRASI DATABASE LAMA
# Format lama:
# username|protocol|credential|created|expired
#
# Format baru:
# username|protocol|credential|created|expired|max_device|status
# =========================================================
migrate_database() {
    local tmp="${USER_FILE}.migration.tmp"

    while IFS='|' read -r username protocol credential created expired max_device status extra; do
        [ -z "$username" ] && continue

        if [ -z "$max_device" ]; then
            max_device="2"
        fi

        if [ -z "$status" ]; then
            status="ACTIVE"
        fi

        echo "${username}|${protocol}|${credential}|${created}|${expired}|${max_device}|${status}"
    done < "$USER_FILE" > "$tmp"

    mv "$tmp" "$USER_FILE"
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_password() {
    openssl rand -hex 16
}

sync_xray() {
    echo
    echo "Menyinkronkan user ke Xray..."
    echo

    if bash "$SYNC_SCRIPT"; then
        echo
        echo "SYNC X-RAY BERHASIL"
        return 0
    else
        echo
        echo "SYNC X-RAY GAGAL"
        return 1
    fi
}

show_links() {
    local username="$1"
    local protocol="$2"

    case "$protocol" in

        vless)
            echo
            echo "Membuat link VLESS..."
            echo

            printf '%s\n' "$username" | "$VLESS_LINK"
            ;;

        vmess)
            echo
            echo "Membuat 3 link VMess..."
            echo

            local vmess_number
            vmess_number=$(awk -F'|' -v u="$username" '
                $2=="vmess" {
                    count++
                    if ($1==u) {
                        print count
                        exit
                    }
                }
            ' "$USER_FILE")

            if [ -n "$vmess_number" ]; then
                printf '%s\n' "$vmess_number" | "$VMESS_LINK"
            else
                echo "User VMess tidak ditemukan pada database."
            fi
            ;;

        trojan)
            echo
            echo "Link Trojan belum diaktifkan."
            echo "Generator Trojan akan kita buat setelah bagian Trojan selesai."
            ;;

    esac
}

add_user() {

    echo
    echo "=============================================="
    echo "              TAMBAH USER"
    echo "=============================================="
    echo

    read -rp "Username: " username

    if [ -z "$username" ]; then
        echo "Username tidak boleh kosong."
        return
    fi

    if ! [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Username hanya boleh menggunakan huruf, angka, _ atau -."
        return
    fi

    if grep -q "^${username}|" "$USER_FILE"; then
        echo "User sudah ada."
        return
    fi

    echo
    echo "Pilih Protocol:"
    echo "  1. VLESS"
    echo "  2. VMess"
    echo "  3. Trojan"
    echo

    read -rp "Protocol [1-3]: " protocol_choice

    case "$protocol_choice" in

        1)
            protocol="vless"
            credential=$(generate_uuid)
            ;;

        2)
            protocol="vmess"
            credential=$(generate_uuid)
            ;;

        3)
            protocol="trojan"
            credential=$(generate_password)
            ;;

        *)
            echo "Protocol tidak valid."
            return
            ;;

    esac

    echo
    read -rp "Masa aktif (hari): " days

    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
        echo "Jumlah hari tidak valid."
        return
    fi

    echo
    read -rp "Max device: " max_device

    if ! [[ "$max_device" =~ ^[0-9]+$ ]] || [ "$max_device" -lt 1 ]; then
        echo "Max device harus berupa angka minimal 1."
        return
    fi

    created=$(date '+%Y-%m-%d')
    expired=$(date -d "+${days} days" '+%Y-%m-%d')
    status="ACTIVE"

    echo
    echo "Membuat user..."
    echo

    echo "${username}|${protocol}|${credential}|${created}|${expired}|${max_device}|${status}" >> "$USER_FILE"

    if ! sync_xray; then

        grep -v "^${username}|" "$USER_FILE" > "${USER_FILE}.tmp"
        mv "${USER_FILE}.tmp" "$USER_FILE"

        echo
        echo "User dibatalkan karena sync Xray gagal."
        return
    fi

    echo
    echo "=============================================="
    echo "          USER BERHASIL DIBUAT"
    echo "=============================================="
    echo "Username   : $username"
    echo "Protocol   : $protocol"
    echo "Dibuat     : $created"
    echo "Expired    : $expired"
    echo "Max Device : $max_device"
    echo "Status     : $status"
    echo "=============================================="

    show_links "$username" "$protocol"
}

list_users() {

    echo
    echo "=============================================="
    echo "              DAFTAR USER"
    echo "=============================================="
    echo

    if [ ! -s "$USER_FILE" ]; then
        echo "Belum ada user."
        return
    fi

    printf "%-15s %-10s %-12s %-12s %-8s %-10s\n" \
        "USERNAME" "PROTOCOL" "DIBUAT" "EXPIRED" "DEVICE" "STATUS"

    echo "------------------------------------------------------------------------"

    while IFS='|' read -r username protocol credential created expired max_device status extra; do

        [ -z "$username" ] && continue

        [ -z "$max_device" ] && max_device="2"
        [ -z "$status" ] && status="ACTIVE"

        printf "%-15s %-10s %-12s %-12s %-8s %-10s\n" \
            "$username" "$protocol" "$created" "$expired" "$max_device" "$status"

    done < "$USER_FILE"

    echo
}

delete_user() {

    echo
    read -rp "Username yang akan dihapus: " username

    if ! grep -q "^${username}|" "$USER_FILE"; then
        echo "User tidak ditemukan."
        return
    fi

    echo
    read -rp "Yakin hapus user $username? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Penghapusan dibatalkan."
        return
    fi

    cp "$USER_FILE" "${USER_FILE}.backup"

    grep -v "^${username}|" "$USER_FILE" > "${USER_FILE}.tmp"
    mv "${USER_FILE}.tmp" "$USER_FILE"

    if ! sync_xray; then

        mv "${USER_FILE}.backup" "$USER_FILE"

        echo
        echo "Penghapusan dibatalkan karena sync Xray gagal."
        return
    fi

    rm -f "${USER_FILE}.backup"

    echo
    echo "User $username berhasil dihapus."
}

user_info() {

    echo
    read -rp "Username: " username

    record=$(grep "^${username}|" "$USER_FILE" | head -n 1)

    if [ -z "$record" ]; then
        echo "User tidak ditemukan."
        return
    fi

    IFS='|' read -r name protocol credential created expired max_device status extra <<< "$record"

    [ -z "$max_device" ] && max_device="2"
    [ -z "$status" ] && status="ACTIVE"

    echo
    echo "=============================================="
    echo "              USER INFORMATION"
    echo "=============================================="
    echo "Username   : $name"
    echo "Protocol   : $protocol"
    echo "Credential : $credential"
    echo "Dibuat     : $created"
    echo "Expired    : $expired"
    echo "Max Device : $max_device"
    echo "Status     : $status"
    echo "=============================================="
}

# =========================================================
# STATUS MANAGEMENT
# =========================================================

change_status() {
    local target_status="$1"

    echo
    read -rp "Username: " username

    local record
    record=$(awk -F'|' -v u="$username" '$1 == u {print; exit}' "$USER_FILE")

    if [ -z "$record" ]; then
        echo "User tidak ditemukan."
        return
    fi

    IFS='|' read -r name protocol credential created expired max_device old_status extra <<< "$record"
    [ -z "$old_status" ] && old_status="ACTIVE"

    echo
    echo "Username : $name"
    echo "Status   : $old_status -> $target_status"
    echo

    read -rp "Konfirmasi? [y/N]: " confirm

    case "$confirm" in
        y|Y)
            ;;
        *)
            echo "Dibatalkan."
            return
            ;;
    esac

    local backup
    backup="$BASE/backups/users-db-status-$(date +%F-%H%M%S).db"

    cp "$USER_FILE" "$backup"

    awk -F'|' -v OFS='|' -v u="$username" -v s="$target_status" '
        $1 == u {
            $7 = s
        }
        {
            print
        }
    ' "$USER_FILE" > "$USER_FILE.tmp"

    mv "$USER_FILE.tmp" "$USER_FILE"

    echo
    echo "Status database diubah."
    echo "Melakukan sync Xray..."

    if "$SYNC_SCRIPT"; then
        echo
        echo "=============================================="
        echo "STATUS BERHASIL DIUBAH"
        echo "=============================================="
        echo "Username : $username"
        echo "Status   : $target_status"
        echo "=============================================="
    else
        echo
        echo "SYNC GAGAL."
        echo "Memulihkan database dari backup..."

        cp "$backup" "$USER_FILE"

        echo "Database berhasil dipulihkan."
    fi
}

freeze_user() {
    change_status "FROZEN"
}

unfreeze_user() {
    change_status "ACTIVE"
}

ban_user() {
    change_status "BANNED"
}

unban_user() {
    change_status "ACTIVE"
}

# =========================================================
# START
# =========================================================

migrate_database

while true; do
    clear

    echo "=============================================="
    echo "              NAGARA TUNNEL"
    echo "              USER MANAGER"
    echo "=============================================="
    echo
    echo "  1. Tambah User"
    echo "  2. Daftar User"
    echo "  3. Hapus User"
    echo "  4. Informasi User"
    echo "  5. Freeze User"
    echo "  6. Unfreeze User"
    echo "  7. Ban User"
    echo "  8. Unban User"
    echo
    echo "  0. Kembali"
    echo
    read -rp "Pilih menu [0-8]: " menu

    case "$menu" in
        1)
            add_user
            read -rp "Tekan Enter untuk kembali..."
            ;;
        2)
            list_users
            read -rp "Tekan Enter untuk kembali..."
            ;;
        3)
            delete_user
            read -rp "Tekan Enter untuk kembali..."
            ;;
        4)
            user_info
            read -rp "Tekan Enter untuk kembali..."
            ;;
        5)
            freeze_user
            read -rp "Tekan Enter untuk kembali..."
            ;;
        6)
            unfreeze_user
            read -rp "Tekan Enter untuk kembali..."
            ;;
        7)
            ban_user
            read -rp "Tekan Enter untuk kembali..."
            ;;
        8)
            unban_user
            read -rp "Tekan Enter untuk kembali..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid."
            sleep 1
            ;;
    esac
done
