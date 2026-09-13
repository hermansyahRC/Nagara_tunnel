#!/bin/bash

BASE="/opt/nagara-tunnel"
source "$BASE/config/system.conf"

BACKUP_DIR="$BASE/backups"
DATE=$(date +%Y%m%d-%H%M%S)
WORK_DIR="/tmp/nagara-migration-$DATE"
ARCHIVE="$BACKUP_DIR/NagaraTunnel-MIGRATION-$DATE.tar.gz"

set -e

echo "=============================================="
echo "       NAGARA TUNNEL MIGRATION BACKUP v1"
echo "=============================================="
echo
echo "Domain : $DOMAIN"
echo "Date   : $(date '+%Y-%m-%d %H:%M:%S')"
echo

mkdir -p "$WORK_DIR/nagara-tunnel/bin"
mkdir -p "$WORK_DIR/nagara-tunnel/config"
mkdir -p "$WORK_DIR/nagara-tunnel/users"
mkdir -p "$WORK_DIR/nagara-tunnel/runtime"
mkdir -p "$WORK_DIR/xray"
mkdir -p "$WORK_DIR/nginx"
mkdir -p "$WORK_DIR/ssl"

echo "[1/7] Backup user database..."

cp -a "$BASE/users/users.db" \
    "$WORK_DIR/nagara-tunnel/users/"

echo "[2/7] Backup konfigurasi Nagara Tunnel..."

cp -a "$BASE/config/system.conf" \
    "$WORK_DIR/nagara-tunnel/config/"

cp -a "$BASE/menu.sh" \
    "$WORK_DIR/nagara-tunnel/"

cp -a "$BASE/install.sh" \
    "$WORK_DIR/nagara-tunnel/"

cp -a "$BASE/check-system.sh" \
    "$WORK_DIR/nagara-tunnel/"

echo "[3/7] Backup script yang diperlukan..."

for file in \
    user-manager.sh \
    sync-users.sh \
    xray-config.sh \
    vless-link.sh \
    vmess-link.sh \
    session-manager.sh \
    session-tracker.sh \
    device-monitor.sh \
    device-monitor-v4.sh
do
    if [ -f "$BASE/bin/$file" ]; then
        cp -a "$BASE/bin/$file" \
            "$WORK_DIR/nagara-tunnel/bin/"
    fi
done

echo "[4/7] Backup runtime..."

if [ -d "$BASE/runtime" ]; then
    cp -a "$BASE/runtime/." \
        "$WORK_DIR/nagara-tunnel/runtime/"
fi
echo "[5/7] Backup Xray dan Nginx..."

cp -f /usr/local/etc/xray/config.json \
    "$WORK_DIR/xray/config.json"

cp -f /etc/systemd/system/xray.service \
    "$WORK_DIR/xray/xray.service"

cp -f /etc/nginx/sites-available/nagara-tunnel \
    "$WORK_DIR/nginx/nagara-tunnel"

if [ -f /etc/nginx/sites-enabled/nagara-tunnel ]; then
    cp -f /etc/nginx/sites-enabled/nagara-tunnel \
        "$WORK_DIR/nginx/nagara-tunnel-enabled"
fi

echo "[6/7] Backup SSL..."

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    cp -a "/etc/letsencrypt/live/$DOMAIN" \
        "$WORK_DIR/ssl/"
fi

if [ -d "/etc/letsencrypt/archive/$DOMAIN" ]; then
    cp -a "/etc/letsencrypt/archive/$DOMAIN" \
        "$WORK_DIR/ssl/"
fi

echo "[7/7] Membuat metadata..."

cat > "$WORK_DIR/MIGRATION-INFO.txt" <<INFO
Nagara Tunnel Migration Backup v1
=================================

Backup date : $(date '+%Y-%m-%d %H:%M:%S')
Hostname    : $(hostname)
Domain      : $DOMAIN
OS          : $(. /etc/os-release && echo "$PRETTY_NAME")
Architecture: $(uname -m)

Tujuan:
Backup ini dibuat untuk migrasi Nagara Tunnel
dari VPS lama ke VPS baru.

Data yang dibackup:
- User database
- UUID user
- Masa aktif user
- Device/IP limit
- Konfigurasi Nagara Tunnel
- Xray configuration
- Xray service
- Nginx configuration
- SSL certificate
- SSL private key
- Runtime/session data

PENTING:
File ini berisi data SENSITIF.
Jangan upload ke repository GitHub.
Jangan membagikan file ini kepada orang lain.
INFO

echo
echo "Membuat archive..."

mkdir -p "$BACKUP_DIR"

tar -czf "$ARCHIVE" -C "$WORK_DIR" .

rm -rf "$WORK_DIR"

chmod 600 "$ARCHIVE"

echo
echo "=============================================="
echo "       MIGRATION BACKUP BERHASIL"
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
