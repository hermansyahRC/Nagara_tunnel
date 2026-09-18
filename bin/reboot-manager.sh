#!/bin/bash

BASE="/opt/nagara-tunnel"
CONFIG_DIR="$BASE/config"
CONFIG_FILE="$CONFIG_DIR/reboot.conf"
TIMER_FILE="/etc/systemd/system/nagara-auto-reboot.timer"

mkdir -p "$CONFIG_DIR"

load_config() {
    ENABLED="false"
    INTERVAL=""

    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
ENABLED="$ENABLED"
INTERVAL="$INTERVAL"
EOF

    chmod 600 "$CONFIG_FILE"
}

apply_timer() {

    if [ "$ENABLED" != "true" ]; then
        systemctl disable --now nagara-auto-reboot.timer >/dev/null 2>&1 || true
        return
    fi

    case "$INTERVAL" in
        1)
            INTERVAL_TEXT="1 Jam"
            ;;
        3)
            INTERVAL_TEXT="3 Jam"
            ;;
        6)
            INTERVAL_TEXT="6 Jam"
            ;;
        12)
            INTERVAL_TEXT="12 Jam"
            ;;
        24)
            INTERVAL_TEXT="24 Jam"
            ;;
        *)
            echo "Interval tidak valid."
            return 1
            ;;
    esac

cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Nagara Tunnel Auto Reboot Timer

[Timer]
OnUnitActiveSec=${INTERVAL}h
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable --now nagara-auto-reboot.timer

    echo "Auto Reboot aktif."
    echo "Interval: setiap $INTERVAL_TEXT"
}

show_status() {

    load_config

    echo
    echo "=============================================="
    echo "             REBOOT MANAGER"
    echo "=============================================="
    echo

    if [ "$ENABLED" = "true" ]; then
        case "$INTERVAL" in
            1)  INTERVAL_TEXT="1 Jam" ;;
            3)  INTERVAL_TEXT="3 Jam" ;;
            6)  INTERVAL_TEXT="6 Jam" ;;
            12) INTERVAL_TEXT="12 Jam" ;;
            24) INTERVAL_TEXT="24 Jam" ;;
            *)  INTERVAL_TEXT="Tidak valid" ;;
        esac

        echo "Auto Reboot : ON"
        echo "Interval    : Setiap $INTERVAL_TEXT"

        echo
        systemctl list-timers nagara-auto-reboot.timer --no-pager

    else
        echo "Auto Reboot : OFF"
    fi

    echo
}

enable_reboot() {

    echo
    echo "=============================================="
    echo "         PILIH INTERVAL AUTO REBOOT"
    echo "=============================================="
    echo
    echo "1. Setiap 1 Jam"
    echo "2. Setiap 3 Jam"
    echo "3. Setiap 6 Jam"
    echo "4. Setiap 12 Jam"
    echo "5. Setiap 24 Jam"
    echo "0. Batal"
    echo

    read -rp "Pilih: " CHOICE

    case "$CHOICE" in

        1)
            INTERVAL=1
            ;;

        2)
            INTERVAL=3
            ;;

        3)
            INTERVAL=6
            ;;

        4)
            INTERVAL=12
            ;;

        5)
            INTERVAL=24
            ;;

        0)
            echo "Dibatalkan."
            return
            ;;

        *)
            echo "Pilihan tidak valid."
            return
            ;;

    esac

    ENABLED="true"
    save_config
    apply_timer
}

disable_reboot() {

    load_config

    ENABLED="false"
    save_config

    systemctl disable --now nagara-auto-reboot.timer >/dev/null 2>&1 || true

    echo
    echo "Auto Reboot berhasil dinonaktifkan."
}

do_reboot() {

    echo
    echo "=============================================="
    echo "              REBOOT VPS"
    echo "=============================================="
    echo
    echo "PERINGATAN!"
    echo "VPS akan melakukan reboot."
    echo

    read -rp "Ketik REBOOT untuk melanjutkan: " CONFIRM

    if [ "$CONFIRM" = "REBOOT" ]; then
        echo
        echo "VPS akan reboot dalam 3 detik..."
        sleep 3
        /sbin/reboot
    else
        echo
        echo "Reboot dibatalkan."
    fi
}

case "$1" in

    status)
        show_status
        ;;

    enable)
        enable_reboot
        ;;

    disable)
        disable_reboot
        ;;

    reboot)
        do_reboot
        ;;

    *)
        echo
        echo "Penggunaan:"
        echo
        echo "$0 status"
        echo "$0 enable"
        echo "$0 disable"
        echo "$0 reboot"
        echo
        ;;

esac
