#!/bin/bash

BASE="/opt/nagara-tunnel"

get_user_count() {
    if [ -f "$BASE/users/users.db" ]; then
        awk 'NF && $0 !~ /^#/ {count++} END {print count+0}' \
            "$BASE/users/users.db"
    else
        echo "0"
    fi
}

service_status() {
    if systemctl is-active --quiet xray; then
        echo "ONLINE"
    else
        echo "OFFLINE"
    fi
}

nginx_status() {
    if systemctl is-active --quiet nginx; then
        echo "ONLINE"
    else
        echo "OFFLINE"
    fi
}

while true; do

    clear

    USER_COUNT=$(get_user_count)

    echo "================================================"
    echo "              NAGARA TUNNEL"
    echo "           VPN MANAGEMENT SYSTEM"
    echo "================================================"
    echo
    printf " Server : %-30s\n" "$(hostname)"
    printf " Domain : %-30s\n" "$(awk -F= '/^DOMAIN=/{gsub(/"/,"",$2); print $2}' "$BASE/config/system.conf")"
    printf " Xray   : %-30s\n" "$(service_status)"
    printf " Nginx  : %-30s\n" "$(nginx_status)"
    printf " Users  : %-30s\n" "$USER_COUNT"
    echo
    echo "================================================"
    echo "  1. User Manager"
    echo "  2. VLESS Manager"
    echo "  3. VMess Manager"
    echo "  4. Trojan Manager"
    echo "  5. Connection Monitor"
    echo "  6. Service Manager"
    echo "  7. System Information"
    echo "  8. Backup"
    echo "  9. Migration VPS"
    echo
    echo "  0. Exit"
    echo "================================================"
    echo

    read -rp "Pilih menu: " MENU

    case "$MENU" in

        1)
            "$BASE/bin/user-manager.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        2)
            "$BASE/bin/vless-link.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        3)
            "$BASE/bin/vmess-link.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        4)
            clear
            echo "================================================"
            echo "              TROJAN MANAGER"
            echo "================================================"
            echo
            echo "Fitur Trojan Manager belum diaktifkan."
            echo
            read -rp "Tekan Enter untuk kembali..."
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
            "$BASE/check-system.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;

        8)
            clear
            echo "================================================"
            echo "                 BACKUP"
            echo "================================================"
            echo
            echo "1. Full Backup"
            echo "2. Migration Backup"
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
            esac
            ;;

        9)
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

        0|exit|EXIT|Exit|q|Q)
            clear
            exit 0
            ;;

        *)
            echo
            echo "Pilihan tidak valid."
            sleep 1
            ;;

    esac

done
