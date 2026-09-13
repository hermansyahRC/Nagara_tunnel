#!/bin/bash

BASE="/opt/nagara-tunnel"

while true; do
    clear

    echo "=============================================="
    echo "              NAGARA TUNNEL"
    echo "=============================================="
    echo
    echo "  1. User Manager"
    echo "  2. VLESS Link Generator"
    echo "  3. VMess Manager"
    echo "  4. Trojan Manager"
    echo "  5. Service Status"
    echo "  6. System Information"
    echo "  7. Backup"
    echo "  0. Exit"
    echo
    echo "=============================================="
    read -p "Pilih menu: " MENU

    case "$MENU" in

        1)
            "$BASE/bin/user-manager.sh"
            read -p "Tekan Enter untuk kembali..."
            ;;

        2)
            "$BASE/bin/vless-link.sh"
            read -p "Tekan Enter untuk kembali..."
            ;;

        3)
            echo
            /opt/nagara-tunnel/bin/vmess-link.sh
            read -p "Tekan Enter..."
            ;;

        4)
            echo
            echo "Trojan Manager belum diaktifkan."
            read -p "Tekan Enter..."
            ;;

        5)
            echo
            echo "============== SERVICE STATUS =============="
            printf "Xray  : "
            systemctl is-active --quiet xray && echo "ACTIVE" || echo "OFF"
            printf "Nginx : "
            systemctl is-active --quiet nginx && echo "ACTIVE" || echo "OFF"
            echo
            read -p "Tekan Enter..."
            ;;

        6)
            "$BASE/check-system.sh"
            read -p "Tekan Enter..."
            ;;

        7)
            echo
            echo "================ BACKUP ===================="
            DATE=$(date +%Y%m%d-%H%M%S)
            DEST="$BASE/backups/manual-$DATE"

            mkdir -p "$DEST"

            cp -f /usr/local/etc/xray/config.json "$DEST/xray-config.json"
            cp -f /etc/nginx/sites-available/nagara-tunnel "$DEST/nginx-nagara-tunnel"

            if [ -f "$BASE/users/users.db" ]; then
                cp -f "$BASE/users/users.db" "$DEST/users.db"
            fi

            echo
            echo "Backup berhasil:"
            echo "$DEST"
            echo
            read -p "Tekan Enter..."
            ;;

        0)
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
