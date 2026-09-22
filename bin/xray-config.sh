#!/usr/bin/env bash

set -euo pipefail

XRAY_CONFIG="/usr/local/etc/xray/config.json"
BACKUP_DIR="/opt/nagara-tunnel/backups"

mkdir -p "$BACKUP_DIR"

echo
echo "=============================================="
echo "       NAGARA TUNNEL XRAY CONFIG"
echo "=============================================="
echo

# --------------------------------------------------
# CHECK DEPENDENCIES
# --------------------------------------------------

if ! command -v xray >/dev/null 2>&1; then
    echo "ERROR: Xray belum terpasang."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq belum terpasang."
    exit 1
fi

# --------------------------------------------------
# BACKUP EXISTING CONFIG
# --------------------------------------------------

if [ -f "$XRAY_CONFIG" ]; then
    BACKUP_FILE="$BACKUP_DIR/xray-config-before-generate-$(date +%Y%m%d-%H%M%S).json"

    cp "$XRAY_CONFIG" "$BACKUP_FILE"

    echo "[OK] Backup konfigurasi:"
    echo "     $BACKUP_FILE"
fi

# --------------------------------------------------
# CREATE BASELINE CONFIG
# --------------------------------------------------

mkdir -p /opt/nagara-tunnel/logs
touch /opt/nagara-tunnel/logs/xray-access.log
chown nobody:nogroup /opt/nagara-tunnel/logs
chown nobody:nogroup /opt/nagara-tunnel/logs/xray-access.log
chmod 750 /opt/nagara-tunnel/logs
chmod 640 /opt/nagara-tunnel/logs/xray-access.log

cat > "$XRAY_CONFIG" <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/opt/nagara-tunnel/logs/xray-access.log"
  },

  "api": {
    "tag": "api",
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ]
  },

  "inbounds": [

    {
      "tag": "api",
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      }
    },

    {
      "tag": "vless-in",
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/nagara-ws"
        }
      }
    },

    {
      "tag": "vmess-in",
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vmess",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/vmess-ws"
        }
      }
    },

    {
      "tag": "trojan-in",
      "listen": "0.0.0.0",
      "port": 10003,
      "protocol": "trojan",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "tcp"
      }
    },

    {
      "tag": "vmess-grpc-in",
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vmess",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "grpc",

        "grpcSettings": {
          "serviceName": "vmess-grpc"
        }
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
    },

    {
      "protocol": "freedom",
      "tag": "api"
    }
  ],

  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api"
      }
    ]
  }
}
EOF

# --------------------------------------------------
# PERMISSIONS
# --------------------------------------------------

chown nobody:nogroup "$XRAY_CONFIG"
chmod 640 "$XRAY_CONFIG"

# --------------------------------------------------
# VALIDATE JSON
# --------------------------------------------------

echo
echo "[INFO] Memeriksa JSON..."

if ! jq empty "$XRAY_CONFIG"; then
    echo
    echo "ERROR: JSON Xray tidak valid."
    exit 1
fi

# --------------------------------------------------
# VALIDATE XRAY CONFIG
# --------------------------------------------------

echo
echo "[INFO] Memeriksa konfigurasi Xray..."

if ! xray run -test -config "$XRAY_CONFIG"; then
    echo
    echo "ERROR: Konfigurasi Xray tidak valid."
    exit 1
fi

echo
echo "=============================================="
echo "       KONFIGURASI XRAY BERHASIL"
echo "=============================================="
echo
echo "VLESS WS    : 127.0.0.1:10001 /nagara-ws"
echo "VMess WS    : 127.0.0.1:10002 /vmess-ws"
echo "Trojan TCP  : 0.0.0.0:10003"
echo "VMess gRPC  : 127.0.0.1:10004 /vmess-grpc"
echo
echo "API         : 127.0.0.1:10085"
echo
echo "User        : dikelola melalui users.db"
echo "Credential  : tidak dibuat oleh script ini"
echo
echo "=============================================="
