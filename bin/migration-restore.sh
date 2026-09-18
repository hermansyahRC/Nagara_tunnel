#!/bin/bash

DRY_RUN=false

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

BASE="/opt/nagara-tunnel"
source "$BASE/config/system.conf"

BACKUP_DIR="$BASE/backups"
RESTORE_DIR="/tmp/nagara-restore-$(date +%Y%m%d-%H%M%S)"

set -e

echo "=============================================="
echo "       NAGARA TUNNEL MIGRATION RESTORE v2"
echo "=============================================="
echo
echo "Domain saat ini : $DOMAIN"
echo

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Jalankan sebagai root."
    exit 1
fi

echo "Mencari backup migration terbaru..."

LATEST_BACKUP=$(ls -1t "$BACKUP_DIR"/NagaraTunnel-MIGRATION-*.tar.gz 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo
    echo "ERROR: Backup migration tidak ditemukan."
    echo "Lokasi yang dicari:"
    echo "$BACKUP_DIR/NagaraTunnel-MIGRATION-*.tar.gz"
    exit 1
fi

echo
echo "Backup ditemukan:"
echo "$LATEST_BACKUP"
echo

if [ "$DRY_RUN" = true ]; then
    echo "=============================================="
    echo "          DRY-RUN MODE AKTIF"
    echo "=============================================="
    echo
    echo "Backup akan diperiksa."
    echo "Tidak ada konfigurasi aktif yang diubah."
    echo "Tidak ada service yang direstart."
    echo

    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"

    echo "Mengekstrak backup sementara..."
    tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"

    echo
    echo "Struktur backup:"
    echo

    test -f "$RESTORE_DIR/nagara-tunnel/users/users.db" \
        && echo "OK: users.db" \
        || { echo "ERROR: users.db tidak ditemukan."; rm -rf "$RESTORE_DIR"; exit 1; }

    test -f "$RESTORE_DIR/cron/nagara-traffic" \
        && echo "OK: Cron nagara-traffic" \
        || echo "WARNING: Cron nagara-traffic tidak ditemukan."

    test -f "$RESTORE_DIR/xray/config.json" \
        && echo "OK: Xray config" \
        || { echo "ERROR: Xray config tidak ditemukan."; rm -rf "$RESTORE_DIR"; exit 1; }

    test -f "$RESTORE_DIR/xray/xray.service" \
        && echo "OK: Xray service" \
        || { echo "ERROR: Xray service tidak ditemukan."; rm -rf "$RESTORE_DIR"; exit 1; }

    test -f "$RESTORE_DIR/nginx/nagara-tunnel" \
        && echo "OK: Nginx config" \
        || { echo "ERROR: Nginx config tidak ditemukan."; rm -rf "$RESTORE_DIR"; exit 1; }

    test -d "$RESTORE_DIR/letsencrypt/live/$DOMAIN" \
        && echo "OK: SSL live" \
        || echo "WARNING: SSL live tidak ditemukan."

    test -d "$RESTORE_DIR/letsencrypt/archive/$DOMAIN" \
        && echo "OK: SSL archive" \
        || echo "WARNING: SSL archive tidak ditemukan."

    if [ -d "$RESTORE_DIR/xray/drop-ins" ]; then
        echo "OK: Xray systemd drop-ins"
    else
        echo "WARNING: Xray systemd drop-ins tidak ditemukan."
    fi

    echo
    rm -rf "$RESTORE_DIR"

    echo "=============================================="
    echo "           DRY-RUN SELESAI"
    echo "=============================================="
    echo
    echo "Tidak ada konfigurasi aktif yang diubah."
    echo "Tidak ada service yang direstart."

    exit 0
fi

read -rp "Lanjutkan restore backup ini? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo
    echo "Restore dibatalkan."
    exit 0
fi

echo
echo "Menyiapkan restore..."

mkdir -p "$RESTORE_DIR"

echo "Mengekstrak backup..."

tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"

echo
echo "Backup berhasil diekstrak."
echo

echo "Memeriksa struktur backup..."

if [ ! -f "$RESTORE_DIR/nagara-tunnel/users/users.db" ]; then
    echo "ERROR: users.db tidak ditemukan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

if [ ! -f "$RESTORE_DIR/xray/config.json" ]; then
    echo "ERROR: Xray config tidak ditemukan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

if [ ! -f "$RESTORE_DIR/xray/xray.service" ]; then
    echo "ERROR: Xray service tidak ditemukan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

if [ ! -f "$RESTORE_DIR/nginx/nagara-tunnel" ]; then
    echo "ERROR: Nginx config tidak ditemukan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

echo "Struktur backup utama OK."
echo

echo "Membuat safety backup sebelum restore..."

SAFETY_BACKUP="$BASE/backups/pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"

mkdir -p "$BASE/backups"

tar -czf "$SAFETY_BACKUP" \
    -C "$BASE" \
    config \
    users \
    runtime \
    menu.sh \
    install.sh \
    check-system.sh \
    bin 2>/dev/null || true

chmod 600 "$SAFETY_BACKUP"

echo
echo "Safety backup:"
echo "$SAFETY_BACKUP"
echo

echo "Restore konfigurasi Nagara Tunnel..."

cp -a "$RESTORE_DIR/nagara-tunnel/config/system.conf" \
    "$BASE/config/system.conf"

cp -a "$RESTORE_DIR/nagara-tunnel/menu.sh" \
    "$BASE/menu.sh"

cp -a "$RESTORE_DIR/nagara-tunnel/install.sh" \
    "$BASE/install.sh"

cp -a "$RESTORE_DIR/nagara-tunnel/check-system.sh" \
    "$BASE/check-system.sh"

echo "Konfigurasi utama berhasil dipulihkan."
echo

echo "Restore user database..."

mkdir -p "$BASE/users"

cp -a "$RESTORE_DIR/nagara-tunnel/users/users.db" \
    "$BASE/users/users.db"

chmod 600 "$BASE/users/users.db"

echo "User database berhasil dipulihkan."
echo

echo "Restore script Nagara Tunnel..."

mkdir -p "$BASE/bin"

cp -a "$RESTORE_DIR/nagara-tunnel/bin/." \
    "$BASE/bin/"

chown -R root:root "$BASE/bin"

chmod +x "$BASE/bin/"*.sh 2>/dev/null || true

echo "Script Nagara Tunnel berhasil dipulihkan."
echo

echo "Restore runtime..."

mkdir -p "$BASE/runtime"

if [ -d "$RESTORE_DIR/nagara-tunnel/runtime" ]; then
    cp -a "$RESTORE_DIR/nagara-tunnel/runtime/." \
        "$BASE/runtime/"
fi

echo "Runtime berhasil dipulihkan."
echo
echo "=============================================="
echo "Restore Cron..."
echo "=============================================="
echo

mkdir -p /etc/cron.d

if [ -f "$RESTORE_DIR/cron/nagara-traffic" ]; then

    cp -a "$RESTORE_DIR/cron/nagara-traffic" \
        /etc/cron.d/nagara-traffic

    chown root:root /etc/cron.d/nagara-traffic
    chmod 644 /etc/cron.d/nagara-traffic

    echo "Cron nagara-traffic berhasil dipulihkan."

else

    echo "WARNING: Cron nagara-traffic tidak ditemukan."

fi

echo
echo "=============================================="
echo "Restore konfigurasi Xray..."
echo "=============================================="
echo

mkdir -p /usr/local/etc/xray

cp -a "$RESTORE_DIR/xray/config.json" \
    /usr/local/etc/xray/config.json

cp -a "$RESTORE_DIR/xray/xray.service" \
    /etc/systemd/system/xray.service

echo "Xray config berhasil dipulihkan."
echo "Xray service berhasil dipulihkan."
echo

echo "Restore Xray systemd drop-ins..."

if [ -d "$RESTORE_DIR/xray/drop-ins" ]; then

    mkdir -p /etc/systemd/system/xray.service.d

    cp -a "$RESTORE_DIR/xray/drop-ins/." \
        /etc/systemd/system/xray.service.d/

    echo "Xray systemd drop-ins berhasil dipulihkan."

else

    echo "Tidak ada Xray systemd drop-ins."

fi

echo

echo "Reload systemd..."

systemctl daemon-reload

echo "Systemd berhasil di-reload."
echo

echo "=============================================="
echo "Restore konfigurasi Nginx..."
echo "=============================================="
echo

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

cp -a "$RESTORE_DIR/nginx/nagara-tunnel" \
    /etc/nginx/sites-available/nagara-tunnel

echo "Nginx config berhasil dipulihkan."

if [ -f "$RESTORE_DIR/nginx/nagara-tunnel-enabled" ]; then

    cp -a "$RESTORE_DIR/nginx/nagara-tunnel-enabled" \
        /etc/nginx/sites-enabled/nagara-tunnel

    echo "Nginx enabled config berhasil dipulihkan."

else

    echo "WARNING: Nginx enabled config tidak ditemukan."

fi

echo

echo "=============================================="
echo "Restore Let's Encrypt SSL..."
echo "=============================================="
echo

mkdir -p /etc/letsencrypt/live
mkdir -p /etc/letsencrypt/archive

if [ -d "$RESTORE_DIR/letsencrypt/archive/$DOMAIN" ]; then

    echo "Memulihkan SSL archive..."

    if [ -d "/etc/letsencrypt/archive/$DOMAIN" ]; then
        mv "/etc/letsencrypt/archive/$DOMAIN" \
           "/etc/letsencrypt/archive/${DOMAIN}.old-$(date +%Y%m%d-%H%M%S)"
    fi

    cp -a "$RESTORE_DIR/letsencrypt/archive/$DOMAIN" \
        "/etc/letsencrypt/archive/"

    echo "SSL archive berhasil dipulihkan."

else

    echo "WARNING: SSL archive tidak ditemukan."

fi

if [ -d "$RESTORE_DIR/letsencrypt/live/$DOMAIN" ]; then

    echo
    echo "Memulihkan SSL live..."

    if [ -e "/etc/letsencrypt/live/$DOMAIN" ]; then
        mv "/etc/letsencrypt/live/$DOMAIN" \
           "/etc/letsencrypt/live/${DOMAIN}.old-$(date +%Y%m%d-%H%M%S)"
    fi

    cp -a "$RESTORE_DIR/letsencrypt/live/$DOMAIN" \
        "/etc/letsencrypt/live/"

    echo "SSL live berhasil dipulihkan."

else

    echo "WARNING: SSL live tidak ditemukan."

fi

echo
echo "Memeriksa struktur SSL..."

if [ -L "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    echo "OK: cert.pem adalah symlink"
else
    echo "WARNING: cert.pem bukan symlink"
fi

if [ -L "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    echo "OK: privkey.pem adalah symlink"
else
    echo "WARNING: privkey.pem bukan symlink"
fi

if [ -L "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "OK: fullchain.pem adalah symlink"
else
    echo "WARNING: fullchain.pem bukan symlink"
fi

echo

echo "=============================================="
echo "Finalisasi restore..."
echo "=============================================="
echo

echo "[1/6] Memperbaiki permission..."

chown -R root:root "$BASE"

chmod 600 "$BASE/users/users.db"

chmod +x "$BASE/menu.sh"
chmod +x "$BASE/install.sh"
chmod +x "$BASE/check-system.sh"

chmod +x "$BASE/bin/"*.sh 2>/dev/null || true

if [ -d "/etc/letsencrypt/archive/$DOMAIN" ]; then
    chmod 700 "/etc/letsencrypt/archive/$DOMAIN"
    chmod 600 "/etc/letsencrypt/archive/$DOMAIN/"*.pem
fi

echo "Permission selesai."
echo

echo "[2/6] Memeriksa Xray..."

if xray run -test -config /usr/local/etc/xray/config.json; then
    echo "OK: konfigurasi Xray valid."
else
    echo "ERROR: konfigurasi Xray tidak valid."
    echo
    echo "Restore dihentikan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

echo

echo "[3/6] Memeriksa systemd Xray..."

systemctl daemon-reload

if systemctl cat xray >/dev/null 2>&1; then
    echo "OK: Xray service terdaftar di systemd."
else
    echo "ERROR: Xray service tidak terdaftar."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

echo

echo "[4/6] Memeriksa Nginx..."

if nginx -t; then
    echo "OK: konfigurasi Nginx valid."
else
    echo "ERROR: konfigurasi Nginx tidak valid."
    echo
    echo "Restore dihentikan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

echo

echo "[5/6] Memeriksa SSL..."

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && \
   [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then

    echo "OK: SSL certificate ditemukan."

else

    echo "WARNING: file SSL tidak lengkap."

fi

echo

echo "[6/6] Menghitung user..."

USER_COUNT=$(awk 'NF && $0 !~ /^#/ {count++} END {print count+0}' \
    "$BASE/users/users.db")

echo "Jumlah user dalam database: $USER_COUNT"

echo

rm -rf "$RESTORE_DIR"

echo "Temporary restore directory dibersihkan."

echo
echo "=============================================="
echo "     NAGARA TUNNEL RESTORE v2 BERHASIL"
echo "=============================================="
echo
echo "User          : $USER_COUNT"
echo "Domain        : $DOMAIN"
echo
echo "Xray           : konfigurasi dipulihkan"
echo "Nginx          : konfigurasi dipulihkan"
echo "SSL            : dipulihkan"
echo "Systemd        : dipulihkan"
echo
echo "CATATAN:"
echo "Xray dan Nginx TIDAK direstart otomatis."
echo "=============================================="
echo
