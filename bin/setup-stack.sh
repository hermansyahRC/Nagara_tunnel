#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/nagara-tunnel"
CONFIG_DIR="$APP_DIR/config"
BACKUP_DIR="$APP_DIR/backups"
DOMAIN="${DOMAIN:-}"

XRAY_CONFIG="/usr/local/etc/xray/config.json"
NGINX_SITE="/etc/nginx/sites-available/nagara-tunnel"
NGINX_LINK="/etc/nginx/sites-enabled/nagara-tunnel"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Script harus dijalankan sebagai root."
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    echo "ERROR: DOMAIN belum diberikan."
    exit 1
fi

echo
echo "=============================================="
echo "       NAGARA TUNNEL STACK SETUP"
echo "=============================================="
echo
echo "Domain : $DOMAIN"
echo

mkdir -p "$BACKUP_DIR"

# ==================================================
# XRAY BASELINE
# ==================================================

echo "[1/6] Menyiapkan baseline Xray..."

if [ ! -x "$APP_DIR/bin/xray-config.sh" ]; then
    echo "ERROR: xray-config.sh tidak ditemukan."
    exit 1
fi

bash "$APP_DIR/bin/xray-config.sh"

if ! xray run -test -config "$XRAY_CONFIG" >/dev/null 2>&1; then
    echo "ERROR: Konfigurasi Xray tidak valid."
    exit 1
fi

echo "[OK] Baseline Xray valid."

# ==================================================
# NGINX DIRECTORIES
# ==================================================

echo
echo "[2/6] Menyiapkan Nginx..."

mkdir -p /var/www/html

if [ -f "$NGINX_SITE" ]; then
    cp "$NGINX_SITE" \
       "$BACKUP_DIR/nginx-before-nagara-$(date '+%Y%m%d-%H%M%S').conf"
fi

cat > "$NGINX_SITE" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location /nagara-ws {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /vmess-ws {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location / {
        return 404;
    }
}
EOF

ln -sf "$NGINX_SITE" "$NGINX_LINK"

nginx -t

systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx

echo "[OK] Nginx HTTP aktif."

# ==================================================
# SSL
# ==================================================

echo
echo "[3/6] Meminta SSL Let's Encrypt..."

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then

    certbot certonly \
        --webroot \
        -w /var/www/html \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email

else
    echo "[INFO] SSL sudah tersedia."
fi

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo
    echo "ERROR: Sertifikat SSL tidak ditemukan."
    exit 1
fi

echo "[OK] SSL tersedia."

# ==================================================
# NGINX HTTPS
# ==================================================

echo
echo "[4/6] Mengaktifkan HTTPS..."

cat > "$NGINX_SITE" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    http2 on;

    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /nagara-ws {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /vmess-ws {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /vmess-grpc {
        grpc_pass grpc://127.0.0.1:10004;
    }

    location / {
        return 404;
    }
}
EOF

nginx -t
systemctl reload nginx

echo "[OK] HTTPS aktif."

# ==================================================
# XRAY SERVICE
# ==================================================

echo
echo "[5/6] Mengaktifkan Xray..."

systemctl daemon-reload
systemctl enable xray >/dev/null 2>&1 || true

if ! systemctl is-active --quiet xray; then
    systemctl start xray
else
    systemctl restart xray
fi

sleep 2

if ! systemctl is-active --quiet xray; then
    echo "ERROR: Xray gagal aktif."
    systemctl status xray --no-pager -l || true
    exit 1
fi

echo "[OK] Xray aktif."

# ==================================================
# FINAL VALIDATION
# ==================================================

echo
echo "[6/6] Validasi..."

echo
echo "----------------------------------------------"
echo "SERVICE STATUS"
echo "----------------------------------------------"

echo "Nginx : $(systemctl is-active nginx)"
echo "Xray  : $(systemctl is-active xray)"

echo
echo "----------------------------------------------"
echo "LISTEN PORT"
echo "----------------------------------------------"

ss -lntp | grep -E ':(80|443|10001|10002|10003|10004|10085)\b' || true

echo
echo "=============================================="
echo "       STACK SETUP SELESAI"
echo "=============================================="
echo
echo "Domain : $DOMAIN"
echo
echo "VLESS WS TLS : https://$DOMAIN/nagara-ws"
echo "VMess WS TLS : https://$DOMAIN/vmess-ws"
echo "VMess gRPC   : $DOMAIN:443"
echo "Trojan       : tahap berikutnya"
echo
