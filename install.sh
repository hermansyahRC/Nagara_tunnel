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

if curl -fsI --max-time 10 https://github.com >/dev/null 2>&1; then
    echo "[OK] Internet tersedia."
else
    echo "ERROR: VPS tidak dapat mengakses GitHub."
    exit 1
fi

# ==================================================
# GITHUB SOURCE CHECK
# ==================================================

echo
echo "[OK] Memeriksa source Nagara Tunnel di GitHub..."

if curl -fsI --max-time 15 "$GITHUB_TARBALL" >/dev/null 2>&1; then
    echo "[OK] Source GitHub tersedia."
else
    echo "ERROR: Source Nagara Tunnel tidak dapat diakses."
    echo
    echo "Repository : $GITHUB_REPO"
    echo "Branch     : $GITHUB_BRANCH"
    exit 1
fi

# ==================================================
# APT UPDATE
# ==================================================

echo
echo "[2/5] Update repository paket..."

export DEBIAN_FRONTEND=noninteractive

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
    iproute2
    lsof
    net-tools
    nano
)

apt-get install -y "${REQUIRED_PACKAGES[@]}"

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

cat > "$APP_DIR/config/system.conf" <<EOF
APP_NAME="$APP_NAME"
APP_DIR="$APP_DIR"
INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
OS="$OS_NAME"
ARCH="$ARCH"
EOF

chmod 755 "$APP_DIR"
chmod 700 "$APP_DIR/config"

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
echo "Nagara dir  : $APP_DIR"
echo
echo "Tahap berikutnya:"
echo "Source Nagara akan dipasang dari GitHub."
echo
echo "=============================================="
