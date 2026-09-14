#!/usr/bin/env bash

set -euo pipefail

APP_NAME="Nagara Tunnel"
APP_DIR="/opt/nagara-tunnel"

clear

echo "================================================"
echo "              NAGARA TUNNEL"
echo "              INSTALLER v2"
echo "================================================"
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

OS_ID="${ID:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"
OS_NAME="${PRETTY_NAME:-unknown}"

echo "[OK] OS          : $OS_NAME"
echo "[OK] OS ID       : $OS_ID"
echo "[OK] OS Version  : $OS_VERSION"

case "$OS_ID" in

    ubuntu)
        case "$OS_VERSION" in
            20.04|22.04|24.04)
                echo "[OK] Ubuntu version didukung."
                ;;
            *)
                echo
                echo "ERROR: Ubuntu $OS_VERSION belum didukung."
                echo "Supported: Ubuntu 20.04 / 22.04 / 24.04"
                exit 1
                ;;
        esac
        ;;

    debian)
        case "$OS_VERSION" in
            11|12|13)
                echo "[OK] Debian version didukung."
                ;;
            *)
                echo
                echo "ERROR: Debian $OS_VERSION belum didukung."
                echo "Supported: Debian 11 / 12 / 13"
                exit 1
                ;;
        esac
        ;;

    *)
        echo
        echo "ERROR: OS tidak didukung."
        echo "Nagara Tunnel mendukung Ubuntu dan Debian."
        exit 1
        ;;

esac

# ==================================================
# ARCHITECTURE CHECK
# ==================================================

ARCH="$(uname -m)"

echo "[OK] Architecture: $ARCH"

case "$ARCH" in
    x86_64|amd64)
        echo "[OK] Architecture didukung."
        ;;
    *)
        echo
        echo "ERROR: Architecture $ARCH belum didukung."
        echo "Saat ini Nagara Tunnel menargetkan x86_64/amd64."
        exit 1
        ;;
esac

# ==================================================
# CPU / RAM / DISK CHECK
# ==================================================

CPU_CORES="$(nproc)"
RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
DISK_INFO="$(df -h / | awk 'NR==2 {print $2 " total, " $4 " free, " $5 " used"}')"

echo "[OK] CPU         : $CPU_CORES core"
echo "[OK] RAM         : ${RAM_MB} MB"
echo "[OK] Disk        : $DISK_INFO"

# ==================================================
# INTERNET CHECK
# ==================================================

echo
echo "Memeriksa koneksi internet..."

if curl -fsS --max-time 10 https://github.com >/dev/null 2>&1; then
    echo "[OK] Internet     : CONNECTED"
else
    echo "[ERROR] Internet  : FAILED"
    echo
    echo "Installer membutuhkan koneksi internet."
    exit 1
fi

# ==================================================
# PACKAGE MANAGER CHECK
# ==================================================

echo
echo "Memeriksa package manager..."

if command -v apt-get >/dev/null 2>&1; then
    echo "[OK] apt-get tersedia."
else
    echo "[ERROR] apt-get tidak ditemukan."
    exit 1
fi

# ==================================================
# DEPENDENCY CHECK
# ==================================================

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
    nano
)

echo
echo "Memeriksa dependency..."

MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
        | grep -q "install ok installed"; then
        echo "[OK]      $package"
    else
        echo "[MISSING] $package"
        MISSING_PACKAGES+=("$package")
    fi
done

if [ "${#MISSING_PACKAGES[@]}" -gt 0 ]; then
    echo
    echo "Memasang dependency yang belum tersedia..."
    apt-get update
    apt-get install -y "${MISSING_PACKAGES[@]}"
else
    echo
    echo "[OK] Semua dependency sudah tersedia."
fi

# ==================================================
# INSTALLER SUMMARY
# ==================================================

echo
echo "================================================"
echo "          INSTALLER CHECK SELESAI"
echo "================================================"
echo
echo "Application : $APP_NAME"
echo "OS          : $OS_NAME"
echo "Architecture: $ARCH"
echo "CPU         : $CPU_CORES core"
echo "RAM         : ${RAM_MB} MB"
echo "Disk        : $DISK_INFO"
echo
echo "Tidak ada service yang diubah."
echo "Belum ada paket yang di-install."
echo
echo "Installer v2 tahap pertama berhasil."
echo "================================================"
