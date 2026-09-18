#!/bin/bash

BASE="/opt/nagara-tunnel"
source "$BASE/config/system.conf"

BACKUP_DIR="$BASE/backups"
DATE=$(date +%Y%m%d-%H%M%S)
WORK_DIR="/tmp/nagara-migration-$DATE"
ARCHIVE="$BACKUP_DIR/NagaraTunnel-MIGRATION-$DATE.tar.gz"

set -e

echo "=============================================="
echo "       NAGARA TUNNEL MIGRATION BACKUP v2"
echo "=============================================="
echo
echo "Domain : $DOMAIN"
echo "Date   : $(date '+%Y-%m-%d %H:%M:%S')"
echo

mkdir -p "$WORK_DIR/nagara-tunnel/bin"
mkdir -p "$WORK_DIR/nagara-tunnel/config"
mkdir -p "$WORK_DIR/nagara-tunnel/users"
mkdir -p "$WORK_DIR/nagara-tunnel/runtime"

mkdir -p "$WORK_DIR/xray/drop-ins"
mkdir -p "$WORK_DIR/nginx"

mkdir -p "$WORK_DIR/letsencrypt/live"
mkdir -p "$WORK_DIR/letsencrypt/archive"

echo "[1/9] Backup user database..."

if [ ! -f "$BASE/users/users.db" ]; then
    echo "ERROR: users.db tidak ditemukan."
    rm -rf "$WORK_DIR"
    exit 1
fi

cp -a "$BASE/users/users.db" \
    "$WORK_DIR/nagara-tunnel/users/"

echo "[2/9] Backup konfigurasi Nagara Tunnel..."

cp -a "$BASE/config/system.conf" \
    "$WORK_DIR/nagara-tunnel/config/"

cp -a "$BASE/menu.sh" \
    "$WORK_DIR/nagara-tunnel/"

cp -a "$BASE/install.sh" \
    "$WORK_DIR/nagara-tunnel/"

cp -a "$BASE/check-system.sh" \
    "$WORK_DIR/nagara-tunnel/"

echo "[3/9] Backup script Nagara Tunnel..."

cp -a "$BASE/bin/." \
    "$WORK_DIR/nagara-tunnel/bin/"

echo "[4/9] Backup runtime..."

if [ -d "$BASE/runtime" ]; then
    cp -a "$BASE/runtime/." \
        "$WORK_DIR/nagara-tunnel/runtime/"
fi

echo "[5/9] Backup Cron..."

mkdir -p "$WORK_DIR/cron"

if [ -f /etc/cron.d/nagara-traffic ]; then
    cp -a /etc/cron.d/nagara-traffic \
        "$WORK_DIR/cron/nagara-traffic"
    echo "Cron nagara-traffic ditemukan."
else
    echo "WARNING: Cron nagara-traffic tidak ditemukan."
fi

echo "[6/9] Backup Xray..."

if [ ! -f /usr/local/etc/xray/config.json ]; then
    echo "ERROR: Xray config tidak ditemukan."
    rm -rf "$WORK_DIR"
    exit 1
fi

if [ ! -f /etc/systemd/system/xray.service ]; then
    echo "ERROR: Xray service tidak ditemukan."
    rm -rf "$WORK_DIR"
    exit 1
fi

cp -a /usr/local/etc/xray/config.json \
    "$WORK_DIR/xray/config.json"

cp -a /etc/systemd/system/xray.service \
    "$WORK_DIR/xray/xray.service"

if [ -d /etc/systemd/system/xray.service.d ]; then
    cp -a /etc/systemd/system/xray.service.d/. \
        "$WORK_DIR/xray/drop-ins/"
fi

echo "[7/9] Backup konfigurasi Nginx..."

if [ ! -f /etc/nginx/sites-available/nagara-tunnel ]; then
    echo "ERROR: Nginx config tidak ditemukan."
    rm -rf "$WORK_DIR"
    exit 1
fi

cp -a /etc/nginx/sites-available/nagara-tunnel \
    "$WORK_DIR/nginx/nagara-tunnel"

if [ -f /etc/nginx/sites-enabled/nagara-tunnel ]; then
    cp -a /etc/nginx/sites-enabled/nagara-tunnel \
        "$WORK_DIR/nginx/nagara-tunnel-enabled"
fi

echo "[8/9] Backup Let's Encrypt SSL..."

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    cp -a "/etc/letsencrypt/live/$DOMAIN" \
        "$WORK_DIR/letsencrypt/live/"
    echo "SSL live ditemukan."
else
    echo "WARNING: SSL live tidak ditemukan."
fi

if [ -d "/etc/letsencrypt/archive/$DOMAIN" ]; then
    cp -a "/etc/letsencrypt/archive/$DOMAIN" \
        "$WORK_DIR/letsencrypt/archive/"
    echo "SSL archive ditemukan."
else
    echo "WARNING: SSL archive tidak ditemukan."
fi

echo
echo "Memeriksa struktur SSL..."

if [ -d "$WORK_DIR/letsencrypt/live/$DOMAIN" ]; then
    echo "OK: letsencrypt/live/$DOMAIN"
fi

if [ -d "$WORK_DIR/letsencrypt/archive/$DOMAIN" ]; then
    echo "OK: letsencrypt/archive/$DOMAIN"
fi

echo "[9/9] Membuat metadata..."

cat > "$WORK_DIR/MIGRATION-INFO.txt" <<INFO
Nagara Tunnel Migration Backup v2
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
- Xray systemd drop-ins
- Nginx configuration
- Let's Encrypt live directory
- Let's Encrypt archive directory
- SSL certificate
- SSL private key
- Runtime/session data

PENTING:
File backup ini berisi data SENSITIF.
Jangan upload ke repository GitHub.
Jangan membagikan file ini kepada orang lain.
INFO

echo
echo "Memeriksa file sebelum archive..."

test -f "$WORK_DIR/nagara-tunnel/users/users.db"
test -f "$WORK_DIR/xray/config.json"
test -f "$WORK_DIR/xray/xray.service"
test -f "$WORK_DIR/nginx/nagara-tunnel"

echo "File utama OK."

echo
echo "Membuat archive..."

mkdir -p "$BACKUP_DIR"

tar -czf "$ARCHIVE" \
    -C "$WORK_DIR" .

rm -rf "$WORK_DIR"

chmod 600 "$ARCHIVE"

echo
echo "=============================================="
echo "       MIGRATION BACKUP v2 BERHASIL"
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
