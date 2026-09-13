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
echo "       NAGARA TUNNEL MIGRATION RESTORE v1"
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
    echo
    echo "=============================================="
    echo "          DRY-RUN MODE AKTIF"
    echo "=============================================="
    echo
    echo "Backup ditemukan dan akan diperiksa."
    echo "Tidak ada file aktif yang akan diubah."
    echo "Tidak ada service yang direstart."
    echo

    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"

    tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"

    echo "Memeriksa struktur backup..."

    [ -f "$RESTORE_DIR/nagara-tunnel/users/users.db" ] \
        && echo "OK: users.db" \
        || { echo "ERROR: users.db tidak ditemukan."; exit 1; }

    [ -f "$RESTORE_DIR/xray/config.json" ] \
        && echo "OK: Xray config" \
        || { echo "ERROR: Xray config tidak ditemukan."; exit 1; }

    [ -f "$RESTORE_DIR/nginx/nagara-tunnel" ] \
        && echo "OK: Nginx config" \
        || { echo "ERROR: Nginx config tidak ditemukan."; exit 1; }

    [ -d "$RESTORE_DIR/ssl/$DOMAIN" ] \
        && echo "OK: SSL $DOMAIN" \
        || echo "WARNING: SSL tidak ditemukan."

    echo
    echo "DRY-RUN SELESAI."
    echo "Tidak ada konfigurasi aktif yang diubah."

    rm -rf "$RESTORE_DIR"
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

if [ "$DRY_RUN" = true ]; then
    echo "=============================================="
    echo "          DRY-RUN MODE AKTIF"
    echo "=============================================="
    echo
    echo "Backup berhasil diekstrak dan siap diperiksa."
    echo
    echo "Tidak ada file aktif yang akan diubah."
    echo "Tidak ada safety backup yang dibuat."
    echo "Tidak ada Xray/Nginx yang direstart."
    echo
    echo "File penting yang ditemukan:"
    echo "- User database"
    echo "- Xray config"
    echo "- Xray service"
    echo "- Nginx config"
    echo "- SSL"
    echo "- Nagara Tunnel config"
    echo "- Runtime/session"
    echo
    rm -rf "$RESTORE_DIR"
    echo "DRY-RUN SELESAI."
    exit 0
fi

echo "Membuat backup keamanan sebelum restore..."

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

echo
echo "Safety backup:"
echo "$SAFETY_BACKUP"
echo

echo "Memeriksa struktur backup..."

if [ ! -f "$RESTORE_DIR/nagara-tunnel/users/users.db" ]; then
    echo "ERROR: users.db tidak ditemukan."
    echo "Restore dihentikan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

if [ ! -f "$RESTORE_DIR/xray/config.json" ]; then
    echo "ERROR: Xray config tidak ditemukan."
    echo "Restore dihentikan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

if [ ! -f "$RESTORE_DIR/nginx/nagara-tunnel" ]; then
    echo "ERROR: Nginx config tidak ditemukan."
    echo "Restore dihentikan."
    rm -rf "$RESTORE_DIR"
    exit 1
fi

echo "Struktur backup OK."
echo

echo "Restore konfigurasi Nagara Tunnel..."

echo "Restore konfigurasi Nagara Tunnel..."

cp -a "$RESTORE_DIR/nagara-tunnel/config/system.conf" \
    "$BASE/config/system.conf"

cp -a "$RESTORE_DIR/nagara-tunnel/menu.sh" \
    "$BASE/menu.sh"

cp -a "$RESTORE_DIR/nagara-tunnel/install.sh" \
    "$BASE/install.sh"

cp -a "$RESTORE_DIR/nagara-tunnel/check-system.sh" \
    "$BASE/check-system.sh"

echo
echo "Restore user database..."

mkdir -p "$BASE/users"

cp -a "$RESTORE_DIR/nagara-tunnel/users/users.db" \
    "$BASE/users/users.db"

chmod 600 "$BASE/users/users.db"

echo
echo "Restore script Nagara Tunnel..."

mkdir -p "$BASE/bin"

cp -a "$RESTORE_DIR/nagara-tunnel/bin/." \
    "$BASE/bin/"

chmod +x "$BASE/bin/"*.sh 2>/dev/null || true

echo
echo "Restore runtime..."

mkdir -p "$BASE/runtime"

if [ -d "$RESTORE_DIR/nagara-tunnel/runtime" ]; then
    cp -a "$RESTORE_DIR/nagara-tunnel/runtime/." \
        "$BASE/runtime/"
fi

echo
echo "Konfigurasi Nagara Tunnel berhasil dipulihkan."
echo

echo "Restore konfigurasi Xray..."

mkdir -p /usr/local/etc/xray

cp -a "$RESTORE_DIR/xray/config.json" \
    /usr/local/etc/xray/config.json

cp -a "$RESTORE_DIR/xray/xray.service" \
    /etc/systemd/system/xray.service

echo
echo "Restore konfigurasi Nginx..."

mkdir -p /etc/nginx/sites-available

cp -a "$RESTORE_DIR/nginx/nagara-tunnel" \
    /etc/nginx/sites-available/nagara-tunnel

if [ -f "$RESTORE_DIR/nginx/nagara-tunnel-enabled" ]; then
    mkdir -p /etc/nginx/sites-enabled

    cp -a "$RESTORE_DIR/nginx/nagara-tunnel-enabled" \
        /etc/nginx/sites-enabled/nagara-tunnel
fi

echo
echo "Konfigurasi Xray dan Nginx berhasil dipulihkan."
echo

echo "Restore SSL..."

if [ -d "$RESTORE_DIR/ssl/$DOMAIN" ]; then
    mkdir -p /etc/letsencrypt/live
    mkdir -p /etc/letsencrypt/archive

    cp -a "$RESTORE_DIR/ssl/$DOMAIN" \
        "/etc/letsencrypt/live/"

    cp -a "$RESTORE_DIR/ssl/$DOMAIN" \
        "/etc/letsencrypt/archive/"

    echo "SSL certificate dan private key berhasil dipulihkan."
else
    echo "WARNING: SSL certificate untuk $DOMAIN tidak ditemukan."
fi

echo
echo "Memperbaiki permission..."

chown -R root:root "$BASE/config" "$BASE/bin"

chmod +x "$BASE/menu.sh"
chmod +x "$BASE/install.sh"
chmod +x "$BASE/check-system.sh"
chmod +x "$BASE/bin/"*.sh 2>/dev/null || true

if [ -f "$BASE/users/users.db" ]; then
    chmod 600 "$BASE/users/users.db"
fi

echo
echo "=============================================="
echo "       VALIDASI KONFIGURASI"
echo "=============================================="
echo

echo "[1/3] Validasi Xray..."

if xray run -test -config /usr/local/etc/xray/config.json; then
    echo "Xray config: OK"
else
    echo "ERROR: Xray config tidak valid."
    echo "Restore dihentikan sebelum restart service."
    exit 1
fi

echo
echo "[2/3] Validasi Nginx..."

if nginx -t; then
    echo "Nginx config: OK"
else
    echo "ERROR: Nginx config tidak valid."
    echo "Restore dihentikan sebelum restart service."
    exit 1
fi

echo
echo "[3/3] Cek database user..."

USER_COUNT=$(grep -cve '^[[:space:]]*$' "$BASE/users/users.db" 2>/dev/null || true)

echo "Jumlah user ditemukan: $USER_COUNT"

echo
echo "Validasi selesai."

echo
echo "=============================================="
echo "     NAGARA TUNNEL RESTORE SELESAI"
echo "=============================================="
echo
echo "Safety backup:"
echo "$SAFETY_BACKUP"
echo
echo "User database:"
echo "$BASE/users/users.db"
echo
echo "Jumlah user:"
echo "$USER_COUNT"
echo
echo "PENTING:"
echo "Xray dan Nginx BELUM direstart."
echo "Silakan cek konfigurasi terlebih dahulu."
echo

rm -rf "$RESTORE_DIR"

exit 0
