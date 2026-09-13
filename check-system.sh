#!/bin/bash

clear

echo "=============================================="
echo "              NAGARA TUNNEL"
echo "              SYSTEM CHECK"
echo "=============================================="
echo
echo "OS           : $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Kernel       : $(uname -r)"
echo "Architecture : $(uname -m)"
echo "CPU Core     : $(nproc)"
echo "RAM          : $(free -h | awk '/Mem:/ {print $2}')"
echo "Disk         : $(df -h / | awk 'NR==2 {print $2}')"
echo "Disk Used    : $(df -h / | awk 'NR==2 {print $5}')"
echo "Hostname     : $(hostname)"
echo "Uptime       : $(uptime -p)"
echo
echo "----------------------------------------------"
echo "NETWORK"
echo "----------------------------------------------"
echo "IPv4         : $(curl -4 -s --max-time 5 https://api.ipify.org || echo "Tidak terdeteksi")"
echo
echo "----------------------------------------------"
echo "SERVICES"
echo "----------------------------------------------"

if systemctl is-active --quiet ssh; then
    echo "SSH          : ON"
else
    echo "SSH          : OFF"
fi

if systemctl is-active --quiet nginx; then
    echo "NGINX        : ON"
else
    echo "NGINX        : OFF"
fi

if systemctl is-active --quiet xray; then
    echo "XRAY         : ON"
else
    echo "XRAY         : OFF"
fi

echo
echo "=============================================="
echo "              CHECK SELESAI"
echo "=============================================="
