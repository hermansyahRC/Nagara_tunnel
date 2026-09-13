#!/usr/bin/env bash

set -e

APP_NAME="Nagara Tunnel"
APP_DIR="/opt/nagara-tunnel"

clear

echo "=============================================="
echo "              NAGARA TUNNEL"
echo "              INSTALLER"
echo "=============================================="
echo
echo "Memulai instalasi..."
echo

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Jalankan installer sebagai root."
    exit 1
fi

echo "[1/5] Update repository..."
apt-get update

echo "[2/5] Memasang paket dasar..."
apt-get install -y \
    curl \
    wget \
    unzip \
    tar \
    jq \
    ca-certificates \
    gnupg \
    lsof \
    net-tools \
    iproute2 \
    nano

echo "[3/5] Membuat struktur Nagara Tunnel..."

mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/bin"
mkdir -p "$APP_DIR/config"
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/backup"

echo "[4/5] Membuat informasi instalasi..."

cat > "$APP_DIR/config/system.conf" <<EOF
APP_NAME="$APP_NAME"
APP_DIR="$APP_DIR"
INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF

echo "[5/5] Membuat menu dasar..."

cat > "$APP_DIR/menu.sh" <<'EOF'
#!/usr/bin/env bash

APP_DIR="/opt/nagara-tunnel"

while true; do
    clear

    echo "=============================================="
    echo "              NAGARA TUNNEL"
    echo "              MANAGEMENT MENU"
    echo "=============================================="
    echo
    echo "  1. System Check"
    echo "  2. Cek Service"
    echo "  3. Cek Network"
    echo "  4. Lihat Folder Config"
    echo "  5. Backup"
    echo "  0. Exit"
    echo
    read -rp "Pilih menu [0-5]: " MENU

    case "$MENU" in
        1)
            bash "$APP_DIR/check-system.sh"
            read -rp "Tekan Enter untuk kembali..."
            ;;
        2)
            echo
            echo "=== SERVICE STATUS ==="
            systemctl --no-pager --type=service --state=running | head -20
            read -rp "Tekan Enter untuk kembali..."
            ;;
        3)
            echo
            echo "=== NETWORK ==="
            ip -br addr
            echo
            echo "=== LISTENING PORT ==="
            ss -lntup
            read -rp "Tekan Enter untuk kembali..."
            ;;
        4)
            echo
            echo "=== CONFIGURATION ==="
            ls -lah "$APP_DIR/config"
            read -rp "Tekan Enter untuk kembali..."
            ;;
        5)
            BACKUP="$APP_DIR/backup/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
            tar -czf "$BACKUP" "$APP_DIR/config" 2>/dev/null || true
            echo
            echo "Backup dibuat:"
            echo "$BACKUP"
            read -rp "Tekan Enter untuk kembali..."
            ;;
        0)
            clear
            exit 0
            ;;
        *)
            echo
            echo "Pilihan tidak valid."
            sleep 1
            ;;
    esac
done
EOF

chmod +x "$APP_DIR/menu.sh"

echo
echo "=============================================="
echo "          INSTALASI FONDASI SELESAI"
echo "=============================================="
echo
echo "Nagara Tunnel sudah dibuat di:"
echo "$APP_DIR"
echo
echo "Menu dapat dijalankan dengan:"
echo "bash $APP_DIR/menu.sh"
echo
echo "=============================================="
