#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="Nagara Tunnel"
APP_DIR="/opt/nagara-tunnel"

# ==================================================
# GITHUB SOURCE
# ==================================================

GITHUB_REPO="hermansyahRC/Nagara_tunnel"
GITHUB_BRANCH="main"
GITHUB_TARBALL="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"

clear

echo "=============================================="
echo "              NAGARA TUNNEL"
echo "          1-CLICK INSTALLER v2"
echo "=============================================="
echo

# ==================================================
# ROOT CHECK
# ==================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Installer harus dijalankan sebagai root."
    exit 1
fi

echo "[OK] Root access"

# ==================================================
# OS DETECTION
# ==================================================

if [ ! -f /etc/os-release ]; then
    echo "ERROR: Tidak dapat mendeteksi sistem operasi."
    exit 1
fi

. /etc/os-release

OS_ID="${ID:-}"
OS_VERSION="${VERSION_ID:-}"
OS_NAME="${PRETTY_NAME:-Unknown}"

echo "[INFO] OS          : $OS_NAME"
echo "[INFO] Architecture: $(uname -m)"
echo

case "$OS_ID:$OS_VERSION" in
    ubuntu:20.04|ubuntu:22.04|ubuntu:24.04)
        echo "[OK] Ubuntu $OS_VERSION didukung."
        ;;
    debian:11|debian:12|debian:13)
        echo "[OK] Debian $OS_VERSION didukung."
        ;;
    *)
        echo
        echo "ERROR: OS/version belum didukung."
        echo "OS terdeteksi: $OS_NAME"
        echo
        echo "Didukung:"
        echo "Ubuntu 20.04 / 22.04 / 24.04"
        echo "Debian 11 / 12 / 13"
        exit 1
        ;;
esac

# ==================================================
# ARCHITECTURE CHECK
# ==================================================

ARCH="$(dpkg --print-architecture)"

case "$ARCH" in
    amd64)
        echo "[OK] Architecture amd64."
        ;;
    *)
        echo
        echo "ERROR: Architecture tidak didukung: $ARCH"
        echo "Saat ini Nagara Tunnel mendukung amd64."
        exit 1
        ;;
esac

# ==================================================
# SYSTEM INFORMATION
# ==================================================

CPU_CORES="$(nproc)"
RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
DISK_INFO="$(df -h / | awk 'NR==2 {print $2 " total, " $4 " free"}')"

echo
echo "----------------------------------------------"
echo "SYSTEM INFORMATION"
echo "----------------------------------------------"
echo "CPU          : $CPU_CORES core"
echo "RAM          : ${RAM_MB} MB"
echo "Disk         : $DISK_INFO"
echo "----------------------------------------------"

# ==================================================
# EXISTING INSTALLATION CHECK
# ==================================================

if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/config/system.conf" ]; then
    echo
    echo "=============================================="
    echo "   INSTALASI NAGARA TERDETEKSI"
    echo "=============================================="
    echo
    echo "Lokasi : $APP_DIR"
    echo
    echo "Installer tidak akan menimpa instalasi yang ada."
    echo
    echo "Untuk upgrade/migration gunakan mekanisme"
    echo "upgrade atau migration Nagara Tunnel."
    echo
    exit 0
fi

echo
echo "[OK] Tidak ada instalasi Nagara sebelumnya."

# ==================================================
# INTERNET CHECK
# ==================================================

echo
echo "[1/5] Memeriksa koneksi internet..."

if getent hosts github.com >/dev/null 2>&1; then
    echo "[OK] DNS/Internet tersedia."
else
    echo "ERROR: VPS tidak dapat mengakses internet."
    exit 1
fi

# ==================================================
# SWAP CONFIGURATION
# ==================================================
configure_swap() {
    echo
    echo "=============================================="
    echo "             SWAP CONFIGURATION"
    echo "=============================================="
    echo

    CURRENT_SWAP_MB="$(awk '/SwapTotal:/ {print int($2/1024)}' /proc/meminfo)"

    if [ "$CURRENT_SWAP_MB" -gt 0 ]; then
        echo "[OK] Swap sudah tersedia: ${CURRENT_SWAP_MB} MB"
        return 0
    fi

    echo "RAM terdeteksi : ${RAM_MB} MB"
    echo "Swap saat ini  : 0 MB"
    echo
    read -rp "Buat Swap 1 GB? [Y/n]: " SWAP_CHOICE
    SWAP_CHOICE="${SWAP_CHOICE:-Y}"

    case "$SWAP_CHOICE" in
        Y|y)
            echo
            echo "[INFO] Membuat Swap 1 GB..."

            if ! fallocate -l 1G /swapfile 2>/dev/null; then
                dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
            fi

            chmod 600 /swapfile
            mkswap /swapfile >/dev/null
            swapon /swapfile

            if ! grep -q '^/swapfile ' /etc/fstab; then
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            fi

            echo
            echo "[OK] Swap 1 GB berhasil diaktifkan."
            swapon --show
            ;;

        N|n)
            echo
            echo "[INFO] Swap tidak dibuat."
            ;;

        *)
            echo
            echo "[INFO] Pilihan tidak dikenali. Swap tidak dibuat."
            ;;
    esac
}

# ==================================================
# APT UPDATE
# ==================================================

echo
echo "[2/5] Update repository paket..."

export DEBIAN_FRONTEND=noninteractive

configure_swap

apt-get update

# ==================================================
# APT UPGRADE
# ==================================================

echo
echo "[3/5] Upgrade paket sistem..."

apt-get upgrade -y

# ==================================================
# DEPENDENCY
# ==================================================

echo
echo "[4/5] Memasang dependency Nagara Tunnel..."

REQUIRED_PACKAGES=(
    curl
    wget
    jq
    tar
    unzip
    ca-certificates
    gnupg
    openssl
    iproute2
    lsof
    net-tools
    nano
)

apt-get install -y "${REQUIRED_PACKAGES[@]}"

# ==================================================
# DOWNLOAD NAGARA SOURCE
# ==================================================

SOURCE_TMP="/tmp/nagara-tunnel-source-$$"
SOURCE_ARCHIVE="$SOURCE_TMP/source.tar.gz"

cleanup_source() {
    rm -rf "$SOURCE_TMP"
}

trap cleanup_source EXIT

echo
echo "[OK] Menyiapkan source Nagara Tunnel..."

mkdir -p "$SOURCE_TMP"

echo "Mengunduh source dari GitHub..."

curl -fL --retry 3 --connect-timeout 10 \
    "$GITHUB_TARBALL" \
    -o "$SOURCE_ARCHIVE"

echo "[OK] Source berhasil diunduh."

echo "Mengekstrak source..."

tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_TMP"

SOURCE_DIR="$(find "$SOURCE_TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Struktur source GitHub tidak valid."
    exit 1
fi

echo "[OK] Source berhasil diekstrak."
echo "Source : $SOURCE_DIR"

echo
echo "Memasang source Nagara Tunnel..."


if [ ! -f "$SOURCE_DIR/menu.sh" ]; then
    echo "ERROR: menu.sh tidak ditemukan di source GitHub."
    exit 1
fi

if [ ! -f "$SOURCE_DIR/check-system.sh" ]; then
    echo "ERROR: check-system.sh tidak ditemukan di source GitHub."
    exit 1
fi

if [ ! -d "$SOURCE_DIR/bin" ] || ! compgen -G "$SOURCE_DIR/bin/*.sh" > /dev/null; then
    echo "ERROR: Direktori bin atau script Nagara tidak lengkap."
    exit 1
fi

echo "[OK] Struktur source Nagara valid."

mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/bin"

cp "$SOURCE_DIR/menu.sh" "$APP_DIR/menu.sh"
cp "$SOURCE_DIR/check-system.sh" "$APP_DIR/check-system.sh"

cp "$SOURCE_DIR/bin/"*.sh "$APP_DIR/bin/"

chmod +x "$APP_DIR/menu.sh"
chmod +x "$APP_DIR/check-system.sh"
chmod +x "$APP_DIR/bin/"*.sh

echo "[OK] Source Nagara Tunnel terpasang."

# ==================================================
# CREATE APP DIRECTORY
# ==================================================

echo
echo "[5/5] Menyiapkan direktori Nagara Tunnel..."

mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/bin"
mkdir -p "$APP_DIR/config"
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/backups"
mkdir -p "$APP_DIR/runtime"
mkdir -p "$APP_DIR/users"

# ==================================================
# XRAY INSTALLATION
# ==================================================

install_xray() {
    echo
    echo "=============================================="
    echo "             XRAY INSTALLATION"
    echo "=============================================="
    echo

    if command -v xray >/dev/null 2>&1; then
        echo "[INFO] Xray sudah terpasang."
        echo "[INFO] Version:"
        xray version | head -n 1
        echo
        echo "[INFO] Installer tidak akan menimpa Xray yang sudah ada."
        return 0
    fi

    echo "[INFO] Xray belum terpasang."
    echo "[INFO] Menggunakan installer resmi XTLS/Xray-install."
    echo

    curl -fsSL \
        https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh \
        -o /tmp/nagara-xray-install.sh

    chmod 700 /tmp/nagara-xray-install.sh

    bash /tmp/nagara-xray-install.sh

    rm -f /tmp/nagara-xray-install.sh

    if [ ! -x /usr/local/bin/xray ]; then
        echo
        echo "ERROR: Binary Xray tidak ditemukan setelah instalasi."
        exit 1
    fi

    mkdir -p /usr/local/etc/xray

    echo
    echo "[OK] Xray berhasil dipasang."
    xray version | head -n 1
}

# ==================================================
# NGINX + CERTBOT INSTALLATION
# ==================================================

install_nginx_certbot() {
    echo
    echo "=============================================="
    echo "        NGINX + CERTBOT INSTALLATION"
    echo "=============================================="
    echo

    echo "[INFO] Memasang Nginx dan Certbot..."
    apt-get install -y nginx certbot python3-certbot-nginx

    if ! command -v nginx >/dev/null 2>&1; then
        echo
        echo "ERROR: Nginx tidak ditemukan setelah instalasi."
        exit 1
    fi

    if ! command -v certbot >/dev/null 2>&1; then
        echo
        echo "ERROR: Certbot tidak ditemukan setelah instalasi."
        exit 1
    fi

    systemctl enable nginx >/dev/null 2>&1 || true

    mkdir -p /etc/letsencrypt/renewal-hooks/deploy

    cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/usr/bin/env bash
set -e

if systemctl is-active --quiet nginx; then
    systemctl reload nginx
fi
EOF

    chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

    echo
    echo "[OK] Nginx terpasang."
    nginx -v 2>&1

    echo "[OK] Certbot terpasang."
    certbot --version
}

# ==================================================
# DOMAIN CONFIGURATION
# ==================================================

echo
echo "=============================================="
echo "          DOMAIN CONFIGURATION"
echo "=============================================="
echo
echo "Masukkan domain yang akan digunakan Nagara Tunnel."
echo "Contoh: vpn.domainkamu.com"
echo

while true; do
    read -rp "Domain: " DOMAIN

    DOMAIN="${DOMAIN#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN%/}"

    if [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        break
    fi

    echo
    echo "ERROR: Format domain tidak valid."
    echo "Contoh: vpn.domainkamu.com"
    echo
done

echo
echo "[OK] Domain : $DOMAIN"

cat > "$APP_DIR/config/system.conf" <<EOF
APP_NAME="$APP_NAME"
APP_DIR="$APP_DIR"
INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
DOMAIN="$DOMAIN"
EOF

chmod 755 "$APP_DIR"
chmod 700 "$APP_DIR/config"

echo
echo "=============================================="
echo "       DOMAIN BERHASIL DIKONFIGURASI"
echo "=============================================="
echo
echo "Domain      : $DOMAIN"
echo "Nagara dir  : $APP_DIR"
echo

install_xray

install_nginx_certbot

echo
echo "=============================================="
echo "       CONFIGURING XRAY + NGINX + SSL"
echo "=============================================="
echo

DOMAIN="$DOMAIN" bash "$APP_DIR/bin/setup-stack.sh"

if [ -f /etc/profile.d/nagara-tunnel.sh ]; then
    rm -f /etc/profile.d/nagara-tunnel.sh
fi

cat > /etc/profile.d/nagara-tunnel.sh <<'EOF'
# Nagara Tunnel Auto Menu
if [ -n "$SSH_CONNECTION" ] && [[ "$-" == *i* ]] && [ "$(id -u)" -eq 0 ]; then
    if [ -x /opt/nagara-tunnel/menu.sh ]; then
        /opt/nagara-tunnel/menu.sh
    fi
fi
EOF

chmod 644 /etc/profile.d/nagara-tunnel.sh

echo
echo "=============================================="
echo "       INSTALLER FOUNDATION SELESAI"
echo "=============================================="
echo
echo "OS          : $OS_NAME"
echo "Architecture: $ARCH"
echo "CPU         : $CPU_CORES core"
echo "RAM         : ${RAM_MB} MB"
echo
echo "Domain      : $DOMAIN"
echo "Nagara dir  : $APP_DIR"
echo
echo "Xray        : $(command -v xray || echo "NOT FOUND")"
echo "Nginx       : $(command -v nginx || echo "NOT FOUND")"
echo "Certbot     : $(command -v certbot || echo "NOT FOUND")"
echo
echo "Tahap berikutnya:"
echo "Konfigurasi Xray, Nginx, SSL, dan user manager akan ditambahkan."
echo
echo "=============================================="
