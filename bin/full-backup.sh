#!/bin/bash

BASE="/opt/nagara-tunnel"
source "$BASE/config/system.conf"
BACKUP_DIR="$BASE/backups"
DATE=$(date +%Y%m%d-%H%M%S)
WORK_DIR="/tmp/nagara-backup-$DATE"
ARCHIVE="$BACKUP_DIR/NagaraTunnel-$DATE.tar.gz"

set -e

echo "=============================================="
echo "       NAGARA TUNNEL FULL BACKUP v1"
echo "=============================================="
echo

mkdir -p "$WORK_DIR/nagara-tunnel"
mkdir -p "$WORK_DIR/xray"
mkdir -p "$WORK_DIR/nginx"
mkdir -p "$WORK_DIR/ssl"

echo "[1/6] Backup Nagara Tunnel..."
cp -a "$BASE/bin" "$WORK_DIR/nagara-tunnel/"
cp -a "$BASE/config" "$WORK_DIR/nagara-tunnel/"
cp -a "$BASE/runtime" "$WORK_DIR/nagara-tunnel/"
cp -a "$BASE/users" "$WORK_DIR/nagara-tunnel/"
cp -f "$BASE/menu.sh" "$WORK_DIR/nagara-tunnel/"
cp -f "$BASE/install.sh" "$WORK_DIR/nagara-tunnel/"
cp -f "$BASE/check-system.sh" "$WORK_DIR/nagara-tunnel/"

echo "[2/6] Backup Xray..."
cp -f /usr/local/etc/xray/config.json "$WORK_DIR/xray/config.json"
cp -f /etc/systemd/system/xray.service "$WORK_DIR/xray/xray.service"

echo "[3/6] Backup Nginx..."
cp -f /etc/nginx/sites-available/nagara-tunnel \
    "$WORK_DIR/nginx/nagara-tunnel"

if [ -f /etc/nginx/sites-enabled/nagara-tunnel ]; then
    cp -f /etc/nginx/sites-enabled/nagara-tunnel \
        "$WORK_DIR/nginx/nagara-tunnel-enabled"
fi

echo "[4/6] Backup SSL..."
cp -a /etc/letsencrypt/live/$DOMAIN \
    "$WORK_DIR/ssl/"

cp -a /etc/letsencrypt/archive/$DOMAIN \
    "$WORK_DIR/ssl/"

echo "[5/6] Membuat metadata..."
cat > "$WORK_DIR/BACKUP-INFO.txt" <<EOF
Nagara Tunnel Full Backup
=========================

Backup date : $(date '+%Y-%m-%d %H:%M:%S')
Hostname    : $(hostname)
OS          : $(. /etc/os-release && echo "$PRETTY_NAME")
Architecture: $(uname -m)

Nagara Tunnel:
$BASE

Xray config:
/usr/local/etc/xray/config.json

Xray service:
/etc/systemd/system/xray.service

Nginx:
/etc/nginx/sites-available/nagara-tunnel

SSL:
$DOMAIN

WARNING:
Backup ini berisi data sensitif:
- UUID user
- konfigurasi Xray
- private key SSL

Jangan membagikan file backup sembarangan.
EOF

echo "[6/6] Membuat archive..."
mkdir -p "$BACKUP_DIR"

tar -czf "$ARCHIVE" -C "$WORK_DIR" .

rm -rf "$WORK_DIR"

chmod 600 "$ARCHIVE"

echo
echo "=============================================="
echo "           BACKUP BERHASIL"
echo "=============================================="
echo
echo "File:"
echo "$ARCHIVE"
echo
echo "Ukuran:"
du -h "$ARCHIVE" | awk '{print $1}'
echo
echo "Permission:"
ls -lh "$ARCHIVE"
echo
