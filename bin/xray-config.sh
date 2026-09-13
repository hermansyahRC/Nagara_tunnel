#!/usr/bin/env bash

set -e

XRAY_CONFIG="/usr/local/etc/xray/config.json"
BACKUP_DIR="/opt/nagara-tunnel/backups"

mkdir -p "$BACKUP_DIR"

get_server_ip() {
    curl -4 -s --max-time 5 https://api.ipify.org || true
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_config() {
    SERVER_IP="$(get_server_ip)"

    if [ -z "$SERVER_IP" ]; then
        echo "Gagal mendapatkan IPv4 publik."
        exit 1
    fi

    VLESS_UUID="$(generate_uuid)"
    VMESS_UUID="$(generate_uuid)"
    TROJAN_PASSWORD="$(openssl rand -hex 16)"

    echo
    echo "=============================================="
    echo "       NAGARA TUNNEL CONFIG GENERATOR"
    echo "=============================================="
    echo
    echo "Server IP : $SERVER_IP"
    echo
    echo "VLESS UUID : $VLESS_UUID"
    echo "VMESS UUID : $VMESS_UUID"
    echo "TROJAN KEY : $TROJAN_PASSWORD"
    echo

    echo "Membuat backup konfigurasi lama..."

    if [ -f "$XRAY_CONFIG" ]; then
        cp "$XRAY_CONFIG" \
        "$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).json"
    fi

    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$VLESS_UUID",
            "email": "nagara-vless"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp"
      }
    },
    {
      "tag": "vmess-in",
      "listen": "0.0.0.0",
      "port": 10002,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$VMESS_UUID",
            "email": "nagara-vmess"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    },
    {
      "tag": "trojan-in",
      "listen": "0.0.0.0",
      "port": 10003,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$TROJAN_PASSWORD",
            "email": "nagara-trojan"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

    echo
    echo "Memeriksa konfigurasi Xray..."
    xray run -test -config "$XRAY_CONFIG"

    echo
    echo "=============================================="
    echo "       KONFIGURASI BERHASIL DIBUAT"
    echo "=============================================="
    echo
    echo "VLESS : $VLESS_UUID"
    echo "VMESS : $VMESS_UUID"
    echo "TROJAN: $TROJAN_PASSWORD"
    echo
    echo "Port:"
    echo "VLESS  = 10001"
    echo "VMess  = 10002"
    echo "Trojan = 10003"
    echo
    echo "CATAT UUID/password di atas."
    echo "=============================================="
}

generate_config
