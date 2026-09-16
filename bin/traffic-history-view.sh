#!/bin/bash

BASE="/opt/nagara-tunnel"

while true; do
    clear
    echo "=============================================="
    echo "          NAGARA TRAFFIC HISTORY"
    echo "=============================================="
    echo
    echo "1. Today"
    echo "2. Last 7 Days"
    echo "0. Kembali"
    echo
    read -rp "Pilih: " HISTORY_MENU

    case "$HISTORY_MENU" in
        1)
            "$BASE/bin/traffic-history-today.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;
        2)
            "$BASE/bin/traffic-history-7d.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;
        0)
            break
            ;;
    esac
done
