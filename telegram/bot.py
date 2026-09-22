#!/usr/bin/env python3

import json
import os
import time
import urllib.parse
import urllib.request
import subprocess


BASE = "/opt/nagara-tunnel"
CONFIG_FILE = f"{BASE}/telegram/config.env"
USERS_DB = f"{BASE}/users/users.db"


def load_config():
    config = {}

    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()

            if not line or line.startswith("#") or "=" not in line:
                continue

            key, value = line.split("=", 1)
            config[key.strip()] = value.strip().strip('"').strip("'")

    return config


CONFIG = load_config()
BOT_TOKEN = CONFIG.get("BOT_TOKEN", "")
OWNER_ID = CONFIG.get("OWNER_ID", "")

if not BOT_TOKEN or not OWNER_ID:
    raise SystemExit("BOT_TOKEN atau OWNER_ID belum dikonfigurasi.")


API = f"https://api.telegram.org/bot{BOT_TOKEN}"
USER_STATES = {}

def telegram(method, params=None):
    if params is None:
        params = {}

    data = urllib.parse.urlencode(params).encode()

    request = urllib.request.Request(
        f"{API}/{method}",
        data=data
    )

    with urllib.request.urlopen(request, timeout=40) as response:
        return json.loads(response.read().decode())


def send_message(chat_id, text, reply_markup=None):
    params = {
        "chat_id": chat_id,
        "text": text
    }

    if reply_markup:
        params["reply_markup"] = json.dumps(reply_markup)

    return telegram("sendMessage", params)


def main_menu():
    return {
        "inline_keyboard": [
            [
                {"text": "🖥 VPS Status", "callback_data": "vps_status"}
            ],
            [
                {"text": "👤 User Manager", "callback_data": "user_manager"},
                {"text": "📡 Connection", "callback_data": "connection"}
            ],
            [
                {"text": "📊 Traffic", "callback_data": "traffic"},
                {"text": "⚙️ Services", "callback_data": "services"}
            ],
            [
                {"text": "💾 Backup", "callback_data": "backup"},
                {"text": "🔥 Firewall", "callback_data": "firewall"}
            ],
            [
                {"text": "🔄 Reboot VPS", "callback_data": "reboot"},
                {"text": "⏱ Auto Reboot", "callback_data": "auto_reboot"}
            ]
        ]
    }


def run_command(command):
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )

        return result.stdout.strip()

    except Exception:
        return ""


def service_status(service):
    result = subprocess.run(
        ["systemctl", "is-active", service],
        capture_output=True,
        text=True
    )

    return "● RUNNING" if result.stdout.strip() == "active" else "● OFFLINE"


def get_public_ip():
    return run_command(
        "curl -4 -s --max-time 5 https://api.ipify.org"
    ) or "Tidak terdeteksi"


def get_user_count():
    if not os.path.exists(USERS_DB):
        return 0

    count = 0

    try:
        with open(USERS_DB, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()

                if not line:
                    continue

                parts = line.split("|")

                if len(parts) >= 7 and parts[6].upper() == "ACTIVE":
                    count += 1

    except Exception:
        return 0

    return count


def get_vps_status():
    hostname = run_command("hostname")
    cpu = run_command("nproc")
    ram = run_command(
        "free -h | awk '/Mem:/ {print $2}'"
    )
    uptime = run_command("uptime -p")
    ip = get_public_ip()

    xray = service_status("xray")
    nginx = service_status("nginx")
    ssh = service_status("ssh")

    users = get_user_count()

    return (
        "🖥 NAGARA TUNNEL — VPS STATUS\n"
        "\n"
        f"Host    : {hostname}\n"
        f"IP      : {ip}\n"
        f"CPU     : {cpu} Core\n"
        f"RAM     : {ram}\n"
        f"Uptime  : {uptime}\n"
        "\n"
        "SERVICES\n"
        f"Xray    : {xray}\n"
        f"Nginx   : {nginx}\n"
        f"SSH     : {ssh}\n"
        "\n"
        f"Users   : {users}"
    )

def get_user_config(username):
    user_data = get_user_data(username)

    if not user_data:
        return None

    protocol = user_data[1].lower()

    scripts = {
        "vless": "/opt/nagara-tunnel/bin/vless-link-core.sh",
        "vmess": "/opt/nagara-tunnel/bin/vmess-link-core.sh",
        "trojan": "/opt/nagara-tunnel/bin/trojan-link-core.sh"
    }

    script = scripts.get(protocol)

    if not script:
        return None

    try:
        result = subprocess.run(
            ["bash", script, username],
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode != 0:
            return None

        return result.stdout.strip()

    except Exception:
        return None



def get_user_data(username):
    if not os.path.exists(USERS_DB):
        return None

    try:
        with open(USERS_DB, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()

                if not line:
                    continue

                parts = line.split("|")

                if len(parts) < 7:
                    continue

                if parts[0] == username:
                    return parts

    except Exception:
        return None

    return None



def get_user_list():
    if not os.path.exists(USERS_DB):
        return "Belum ada database user."

    rows = []

    try:
        with open(USERS_DB, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()

                if not line:
                    continue

                parts = line.split("|")

                if len(parts) < 7:
                    continue

                username = parts[0]
                protocol = parts[1].upper()
                expired = parts[4]
                max_device = parts[5]
                status = parts[6].upper()

                rows.append(
                    f"👤 {username}\n"
                    f"   Protocol : {protocol}\n"
                    f"   Expired  : {expired}\n"
                    f"   Device   : {max_device}\n"
                    f"   Status   : {status}"
                )

    except Exception as e:
        return f"ERROR membaca database: {e}"

    if not rows:
        return "Belum ada user."

    return "📋 DAFTAR USER\n\n" + "\n\n".join(rows)

def user_action_menu(username):
    user_data = get_user_data(username)

    if not user_data:
        return {
            "inline_keyboard": [
                [
                    {
                        "text": "⬅️ Daftar User",
                        "callback_data": "user_list"
                    }
                ]
            ]
        }

    status = user_data[6]

    if status == "BANNED":
        status_buttons = [
            {
                "text": "▶️ Unban",
                "callback_data": f"user_unban:{username}"
            }
        ]
    else:
        status_buttons = [
            {
                "text": "❄️ Freeze",
                "callback_data": f"user_freeze:{username}"
            },
            {
                "text": "▶️ Unfreeze",
                "callback_data": f"user_unfreeze:{username}"
            }
        ]

    return {
        "inline_keyboard": [
[
    {
        "text": "🔗 Lihat Config",
        "callback_data": f"user_config:{username}"
    }
],
[
    {
        "text": "📊 Traffic",
        "callback_data": f"user_traffic:{username}"
    }
],
[
    {
        "text": "♻️ Perpanjang",
                    "callback_data": f"user_renew:{username}"
                }
            ],
            status_buttons,
            [
                {
                    "text": "🚫 Ban",
                    "callback_data": f"user_ban:{username}"
                },
                {
                    "text": "🗑️ Hapus",
                    "callback_data": f"user_delete:{username}"
                }
            ],
            [
                {
                    "text": "⬅️ Daftar User",
                    "callback_data": "user_list"
                }
            ]
        ]
    }

def user_manager_menu():
    return {
        "inline_keyboard": [
            [
                {"text": "➕ Buat User", "callback_data": "user_create"}
            ],
            [
                {"text": "📋 Daftar User", "callback_data": "user_list"}
            ],
            [
                {"text": "⬅️ Menu Utama", "callback_data": "main_menu"}
            ]
        ]
    }

def get_user_list_menu():
    keyboard = []

    if os.path.exists(USERS_DB):
        try:
            with open(USERS_DB, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()

                    if not line:
                        continue

                    parts = line.split("|")

                    if len(parts) < 7:
                        continue

                    username = parts[0]

                    keyboard.append([
                        {
                            "text": f"👤 {username}",
                            "callback_data": f"user_detail:{username}"
                        }
                    ])

        except Exception:
            pass

    keyboard.append([
        {"text": "🔄 Refresh", "callback_data": "user_list"}
    ])

    keyboard.append([
        {"text": "⬅️ User Manager", "callback_data": "user_manager"}
    ])

    return {"inline_keyboard": keyboard}



def user_create_menu():
    return {
        "inline_keyboard": [
            [
                {"text": "🟢 VLESS", "callback_data": "create_vless"},
                {"text": "🔵 VMess", "callback_data": "create_vmess"}
            ],
            [
                {"text": "🟠 Trojan", "callback_data": "create_trojan"}
            ],
            [
                {"text": "⬅️ User Manager", "callback_data": "user_manager"}
            ]
        ]
    }


def answer_callback(callback_id):
    try:
        telegram(
            "answerCallbackQuery",
            {
                "callback_query_id": callback_id
            }
        )
    except Exception:
        pass


def handle_callback(callback):
    callback_id = callback.get("id")
    data = callback.get("data")
    message = callback.get("message", {})
    chat = message.get("chat", {})
    sender = callback.get("from", {})

    chat_id = chat.get("id")
    user_id = str(sender.get("id", ""))

    if user_id != OWNER_ID:
        answer_callback(callback_id)

        if chat_id:
            send_message(
                chat_id,
                "⛔ Akses ditolak."
            )

        return

    answer_callback(callback_id)

    if data.startswith("user_renew:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(
                chat_id,
                "❌ User tidak ditemukan."
            )
            return

        USER_STATES[chat_id] = {
            "step": "renew_days",
            "username": username
        }

        send_message(
            chat_id,
            "♻️ PERPANJANG USER\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📅 Expired  : {user_data[4]}\n\n"
            "Masukkan jumlah hari perpanjangan.\n"
            "Contoh: 30"
        )

        return

    if data.startswith("user_delete:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(
                chat_id,
                "❌ User tidak ditemukan."
            )
            return

        USER_STATES[chat_id] = {
            "step": "delete_confirm",
            "username": username
        }

        send_message(
            chat_id,
            "⚠️ KONFIRMASI HAPUS USER\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📅 Expired  : {user_data[4]}\n"
            f"📱 Device   : {user_data[5]}\n"
            f"📊 Status   : {user_data[6]}\n\n"
            "⚠️ User akan dihapus permanen dari database "
            "dan dikeluarkan dari Xray.\n\n"
            "Lanjutkan?",
            {
                "inline_keyboard": [
                    [
                        {
                            "text": "🗑️ Ya, Hapus",
                            "callback_data": "delete_confirm"
                        },
                        {
                            "text": "❌ Batal",
                            "callback_data": "delete_cancel"
                        }
                    ]
                ]
            }
        )
        return

    elif data == "delete_confirm":
        state = USER_STATES.get(chat_id)

        if not state or state.get("step") != "delete_confirm":
            send_message(
                chat_id,
                "❌ Sesi hapus sudah tidak tersedia."
            )
            return

        username = state.get("username", "")

        try:
            result = subprocess.run(
                [
                    "bash",
                    "/opt/nagara-tunnel/bin/user-delete-core.sh",
                    username
                ],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode != 0:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL MENGHAPUS USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            send_message(
                chat_id,
                "╔══════════════════════════════╗\n"
                "║  🗑️ USER BERHASIL DIHAPUS   ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {username}\n\n"
                "User sudah dihapus dari database "
                "dan dikeluarkan dari Xray."
            )

            USER_STATES.pop(chat_id, None)
            return

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "delete_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Penghapusan dibatalkan.",
            user_manager_menu()
        )

    if data.startswith("user_ban:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(chat_id, "❌ User tidak ditemukan.")
            return

        USER_STATES[chat_id] = {
            "step": "ban_confirm",
            "username": username
        }

        send_message(
            chat_id,
            "🚫 KONFIRMASI BAN\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📊 Status sekarang : {user_data[6]}\n\n"
            "User akan diblokir dan dikeluarkan dari Xray.\n"
            "Lanjutkan?",
            {
                "inline_keyboard": [
                    [
                        {
                            "text": "🚫 Ya, Ban",
                            "callback_data": "ban_confirm"
                        },
                        {
                            "text": "❌ Batal",
                            "callback_data": "ban_cancel"
                        }
                    ]
                ]
            }
        )
        return

    if data.startswith("user_unban:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(chat_id, "❌ User tidak ditemukan.")
            return

        USER_STATES[chat_id] = {
            "step": "unban_confirm",
            "username": username
        }

        send_message(
            chat_id,
            "▶️ KONFIRMASI UNBAN\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📊 Status sekarang : {user_data[6]}\n\n"
            "User akan diaktifkan kembali ke Xray.\n"
            "Lanjutkan?",
            {
                "inline_keyboard": [
                    [
                        {
                            "text": "▶️ Ya, Unban",
                            "callback_data": "unban_confirm"
                        },
                        {
                            "text": "❌ Batal",
                            "callback_data": "unban_cancel"
                        }
                    ]
                ]
            }
        )
        return

    if data.startswith("user_freeze:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(chat_id, "❌ User tidak ditemukan.")
            return

        USER_STATES[chat_id] = {
            "step": "freeze_confirm",
            "username": username
        }

        send_message(
            chat_id,
            "❄️ KONFIRMASI FREEZE\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📊 Status sekarang : {user_data[6]}\n\n"
            "User akan dinonaktifkan dari Xray.\n"
            "Lanjutkan?",
            {
                "inline_keyboard": [
                    [
                        {
                            "text": "❄️ Ya, Freeze",
                            "callback_data": "freeze_confirm"
                        },
                        {
                            "text": "❌ Batal",
                            "callback_data": "freeze_cancel"
                        }
                    ]
                ]
            }
        )
        return

    if data.startswith("user_unfreeze:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(chat_id, "❌ User tidak ditemukan.")
            return

        USER_STATES[chat_id] = {
            "step": "unfreeze_confirm",
            "username": username
        }

        send_message(
            chat_id,
            "▶️ KONFIRMASI UNFREEZE\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📊 Status sekarang : {user_data[6]}\n\n"
            "User akan diaktifkan kembali ke Xray.\n"
            "Lanjutkan?",
            {
                "inline_keyboard": [
                    [
                        {
                            "text": "▶️ Ya, Unfreeze",
                            "callback_data": "unfreeze_confirm"
                        },
                        {
                            "text": "❌ Batal",
                            "callback_data": "unfreeze_cancel"
                        }
                    ]
                ]
            }
        )
        return

    if data.startswith("user_config:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)
        config = get_user_config(username)

        if not user_data or not config:
            send_message(
                chat_id,
                "❌ Config user tidak dapat dibuat."
            )
            return

        protocol = user_data[1].upper()
        expired = user_data[4]
        max_device = user_data[5]

        lines = config.splitlines()

        config_lines = []

        for line in lines:
            if line.startswith("VLESS_"):
                config_lines.append(line.split("=", 1)[1])
            elif line.startswith("VMESS_"):
                config_lines.append(line.split("=", 1)[1])
            elif line.startswith("TROJAN_"):
                config_lines.append(line.split("=", 1)[1])

        message = (
            "🔐 CONFIG USER\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {protocol}\n"
            f"📅 Expired  : {expired}\n"
            f"📱 Device   : {max_device}\n\n"
        )

        for item in config_lines:
            if item.startswith("vless://"):
                if ":443?" in item:
                    message += "🟢 VLESS TLS 443\n"
                elif ":80?" in item:
                    message += "🌐 VLESS HTTP 80\n"

                message += item + "\n\n"

            elif item.startswith("vmess://"):
                message += "🔵 VMESS\n"
                message += item + "\n\n"

            elif item.startswith("trojan://"):
                message += "🔴 TROJAN\n"
                message += item + "\n\n"

        message += "━━━━━━━━━━━━━━━━━━━━\nNagara Tunnel"

        send_message(
            chat_id,
            message
        )

        return


    if data.startswith("user_traffic:"):
        username = data.split(":", 1)[1]

        try:
            result = subprocess.run(
                [
                    "bash",
                    "/opt/nagara-tunnel/bin/user-traffic-core.sh",
                    username
                ],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL MENGAMBIL TRAFFIC\n\n"
                    f"{error}"
                )
                return

            traffic = {}

            for line in result.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    traffic[key] = value

            if not traffic.get("USERNAME"):
                send_message(
                    chat_id,
                    "❌ Data traffic tidak ditemukan."
                )
                return

            message = (
                "╔══════════════════════════════╗\n"
                "║      📊 USER TRAFFIC        ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {traffic.get('USERNAME', username)}\n"
                f"🔌 Protocol : {traffic.get('PROTOCOL', '-').upper()}\n"
                f"📅 Expired  : {traffic.get('EXPIRED', '-')}\n"
                f"📱 Device   : {traffic.get('MAX_DEVICE', '-')}\n"
                f"📊 Status   : {traffic.get('STATUS', '-')}\n\n"
                f"📥 Download : {traffic.get('DOWNLOAD', '0 B')}\n"
                f"📤 Upload   : {traffic.get('UPLOAD', '0 B')}\n"
                f"📊 Total    : {traffic.get('TOTAL', '0 B')}\n\n"
                "━━━━━━━━━━━━━━━━━━━━\n"
                "Nagara Tunnel"
            )

            send_message(
                chat_id,
                message
            )

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )

        return

    if data.startswith("user_detail:"):
        username = data.split(":", 1)[1]

        user_data = get_user_data(username)

        if not user_data:
            send_message(
                chat_id,
                "❌ User tidak ditemukan."
            )
            return

        protocol = user_data[1].upper()
        expired = user_data[4]
        max_device = user_data[5]
        status = user_data[6].upper()

        send_message(
            chat_id,
            "👤 USER: " + username + "\n\n"
            "🔌 Protocol : " + protocol + "\n"
            "📅 Expired  : " + expired + "\n"
            "📱 Device   : " + max_device + "\n"
            "📊 Status   : " + status + "\n\n"
            "🛠️ Pilih tindakan:",
            user_action_menu(username)
        )
        return

    if data == "user_create":
        send_message(
            chat_id,
            "➕ BUAT USER\n\n"
            "Pilih protocol:",
            user_create_menu()
        )
    elif data == "create_vless":
        USER_STATES[chat_id] = {
            "protocol": "vless",
            "step": "username"
        }
        send_message(
            chat_id,
            "🟢 VLESS dipilih.\n\n"
            "Kirim username baru:"
        )

    elif data == "create_vmess":
        USER_STATES[chat_id] = {
            "protocol": "vmess",
            "step": "username"
        }
        send_message(
            chat_id,
            "🔵 VMess dipilih.\n\n"
            "Kirim username baru:"
        )
        
    elif data == "create_trojan":
        USER_STATES[chat_id] = {
            "protocol": "trojan",
            "step": "username"
        }
        send_message(
            chat_id,
            "🟠 Trojan dipilih.\n\n"
            "Kirim username baru:"
        )
    elif data == "ban_confirm":
        state = USER_STATES.get(chat_id)

        if not state or state.get("step") != "ban_confirm":
            send_message(
                chat_id,
                "❌ Sesi ban sudah tidak tersedia."
            )
            return

        username = state.get("username", "")

        try:
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    f"""
BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"
BACKUP="$BASE/backups/users-db-ban-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"
cp "$USER_FILE" "$BACKUP"

awk -F'|' -v OFS='|' -v u="{username}" '
$1 == u {{
    $7="BANNED"
}}
{{
    print
}}
' "$USER_FILE" > "$USER_FILE.tmp"

mv "$USER_FILE.tmp" "$USER_FILE"
chmod 600 "$USER_FILE"

if "$SYNC_SCRIPT"; then
    rm -f "$BACKUP"
    echo "BAN_SUCCESS"
else
    cp "$BACKUP" "$USER_FILE"
    chmod 600 "$USER_FILE"
    rm -f "$BACKUP"
    echo "BAN_FAILED"
    exit 1
fi
"""
                ],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode != 0 or "BAN_SUCCESS" not in result.stdout:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL BAN USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            send_message(
                chat_id,
                "╔══════════════════════════════╗\n"
                "║   🚫 USER BERHASIL DI-BAN   ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {username}\n"
                "📊 Status   : BANNED\n\n"
                "User sudah diblokir dari Xray."
            )

            USER_STATES.pop(chat_id, None)

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "ban_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Ban dibatalkan.",
            user_manager_menu()
        )

    elif data == "unban_confirm":
        state = USER_STATES.get(chat_id)

        if not state or state.get("step") != "unban_confirm":
            send_message(
                chat_id,
                "❌ Sesi unban sudah tidak tersedia."
            )
            return

        username = state.get("username", "")

        try:
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    f"""
BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"
BACKUP="$BASE/backups/users-db-unban-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"
cp "$USER_FILE" "$BACKUP"

awk -F'|' -v OFS='|' -v u="{username}" '
$1 == u {{
    $7="ACTIVE"
}}
{{
    print
}}
' "$USER_FILE" > "$USER_FILE.tmp"

mv "$USER_FILE.tmp" "$USER_FILE"
chmod 600 "$USER_FILE"

if "$SYNC_SCRIPT"; then
    rm -f "$BACKUP"
    echo "UNBAN_SUCCESS"
else
    cp "$BACKUP" "$USER_FILE"
    chmod 600 "$USER_FILE"
    rm -f "$BACKUP"
    echo "UNBAN_FAILED"
    exit 1
fi
"""
                ],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode != 0 or "UNBAN_SUCCESS" not in result.stdout:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL UNBAN USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            send_message(
                chat_id,
                "╔══════════════════════════════╗\n"
                "║  ▶️ USER BERHASIL DI-UNBAN  ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {username}\n"
                "📊 Status   : ACTIVE\n\n"
                "User sudah diaktifkan kembali ke Xray."
            )

            USER_STATES.pop(chat_id, None)

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "unban_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Unban dibatalkan.",
            user_manager_menu()
        )

    elif data == "freeze_confirm":
        state = USER_STATES.get(chat_id)

        if not state or state.get("step") != "freeze_confirm":
            send_message(
                chat_id,
                "❌ Sesi freeze sudah tidak tersedia."
            )
            return

        username = state.get("username", "")

        try:
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    f"""
BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"
BACKUP="$BASE/backups/users-db-freeze-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"
cp "$USER_FILE" "$BACKUP"

awk -F'|' -v OFS='|' -v u="{username}" '
$1 == u {{
    $7="FROZEN"
}}
{{
    print
}}
' "$USER_FILE" > "$USER_FILE.tmp"

mv "$USER_FILE.tmp" "$USER_FILE"
chmod 600 "$USER_FILE"

if "$SYNC_SCRIPT"; then
    rm -f "$BACKUP"
    echo "FREEZE_SUCCESS"
else
    cp "$BACKUP" "$USER_FILE"
    chmod 600 "$USER_FILE"
    rm -f "$BACKUP"
    echo "FREEZE_FAILED"
    exit 1
fi
"""
                ],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode != 0 or "FREEZE_SUCCESS" not in result.stdout:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL FREEZE USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            send_message(
                chat_id,
                "╔══════════════════════════════╗\n"
                "║   ❄️ USER BERHASIL FREEZE   ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {username}\n"
                "📊 Status   : FROZEN\n\n"
                "User sudah dinonaktifkan dari Xray."
            )

            USER_STATES.pop(chat_id, None)

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "freeze_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Freeze dibatalkan.",
            user_manager_menu()
        )

    elif data == "unfreeze_confirm":
        state = USER_STATES.get(chat_id)

        if not state or state.get("step") != "unfreeze_confirm":
            send_message(
                chat_id,
                "❌ Sesi unfreeze sudah tidak tersedia."
            )
            return

        username = state.get("username", "")

        try:
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    f"""
BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"
BACKUP="$BASE/backups/users-db-unfreeze-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"
cp "$USER_FILE" "$BACKUP"

awk -F'|' -v OFS='|' -v u="{username}" '
$1 == u {{
    $7="ACTIVE"
}}
{{
    print
}}
' "$USER_FILE" > "$USER_FILE.tmp"

mv "$USER_FILE.tmp" "$USER_FILE"
chmod 600 "$USER_FILE"

if "$SYNC_SCRIPT"; then
    rm -f "$BACKUP"
    echo "UNFREEZE_SUCCESS"
else
    cp "$BACKUP" "$USER_FILE"
    chmod 600 "$USER_FILE"
    rm -f "$BACKUP"
    echo "UNFREEZE_FAILED"
    exit 1
fi
"""
                ],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode != 0 or "UNFREEZE_SUCCESS" not in result.stdout:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL UNFREEZE USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            send_message(
                chat_id,
                "╔══════════════════════════════╗\n"
                "║  ▶️ USER BERHASIL UNFREEZE  ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {username}\n"
                "📊 Status   : ACTIVE\n\n"
                "User sudah diaktifkan kembali ke Xray."
            )

            USER_STATES.pop(chat_id, None)

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "unfreeze_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Unfreeze dibatalkan.",
            user_manager_menu()
        )

    elif data == "renew_confirm":
        state = USER_STATES.get(chat_id)

        if not state or state.get("step") != "renew_confirm":
            send_message(
                chat_id,
                "❌ Sesi perpanjangan sudah tidak tersedia."
            )
            return

        username = state.get("username", "")
        days = state.get("days", 0)

        try:
            result = subprocess.run(
                [
                    "bash",
                    "/opt/nagara-tunnel/bin/user-renew-core.sh",
                    username,
                    str(days)
                ],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode != 0:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL MEMPERPANJANG USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            info = {}

            for line in result.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    info[key.strip()] = value.strip()

            send_message(
                chat_id,
                "╔══════════════════════════════╗\n"
                "║  ✅ USER BERHASIL DIPERPANJANG ║\n"
                "╚══════════════════════════════╝\n\n"
                f"👤 Username : {info.get('USERNAME', username)}\n"
                f"🔌 Protocol : {info.get('PROTOCOL', '-').upper()}\n"
                f"📅 Sebelumnya : {info.get('OLD_EXPIRED', '-')}\n"
                f"➕ Tambah    : {info.get('DAYS', days)} hari\n"
                f"📅 Expired   : {info.get('EXPIRED', '-')}\n"
                f"📱 Device    : {info.get('MAX_DEVICE', '-')}\n"
                f"📊 Status    : {info.get('STATUS', 'ACTIVE')}\n\n"
                "Xray berhasil disinkronkan."
            )

            USER_STATES.pop(chat_id, None)

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "renew_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Perpanjangan dibatalkan.",
            user_manager_menu()
        )
    

    elif data == "create_confirm":
        state = USER_STATES.get(chat_id)

        if not state:
            send_message(
                chat_id,
                "❌ Sesi pembuatan user sudah tidak tersedia.\n\n"
                "Silakan mulai lagi dari User Manager."
            )
            return

        username = state.get("username", "")
        protocol = state.get("protocol", "")
        days = state.get("days", 0)
        max_device = state.get("max_device", 0)

        if not username or not protocol or not days or not max_device:
            send_message(
                chat_id,
                "❌ Data user belum lengkap.\n\n"
                "Silakan mulai pembuatan user dari awal."
            )
            USER_STATES.pop(chat_id, None)
            return

        try:
            result = subprocess.run(
                [
                    "bash",
                    "/opt/nagara-tunnel/bin/user-create-core.sh",
                    username,
                    protocol,
                    str(days),
                    str(max_device)
                ],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode != 0:
                error = result.stderr.strip() or result.stdout.strip()

                send_message(
                    chat_id,
                    "❌ GAGAL MEMBUAT USER\n\n"
                    f"{error}"
                )

                USER_STATES.pop(chat_id, None)
                return

            link_script = {
                "vless": "/opt/nagara-tunnel/bin/vless-link-core.sh",
                "vmess": "/opt/nagara-tunnel/bin/vmess-link-core.sh",
                "trojan": "/opt/nagara-tunnel/bin/trojan-link-core.sh"
            }.get(protocol)

            if not link_script:
                send_message(
                    chat_id,
                    "⚠️ User berhasil dibuat, tetapi generator link tidak ditemukan."
                )
                USER_STATES.pop(chat_id, None)
                return

            link_result = subprocess.run(
                [
                    "bash",
                    link_script,
                    username
                ],
                capture_output=True,
                text=True,
                timeout=60
            )

            if link_result.returncode != 0:
                send_message(
                    chat_id,
                    "✅ USER BERHASIL DIBUAT\n\n"
                    "⚠️ Tetapi konfigurasi/link gagal dibuat.\n\n"
                    f"{link_result.stderr.strip() or link_result.stdout.strip()}"
                )
                USER_STATES.pop(chat_id, None)
                return

            info = {}

            for line in link_result.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    info[key.strip()] = value.strip()

            if protocol == "vless":
                message = (
                    "╔══════════════════════════════╗\n"
                    "║   ✅ USER BERHASIL DIBUAT   ║\n"
                    "╚══════════════════════════════╝\n\n"
                    f"👤 Username : {info.get('USERNAME', username)}\n"
                    f"🔌 Protocol : VLESS\n"
                    f"📅 Expired  : {info.get('EXPIRED', '-')}\n"
                    f"📱 Device   : {info.get('MAX_DEVICE', max_device)}\n"
                    f"📊 Status   : {info.get('STATUS', 'ACTIVE')}\n\n"
                    "🔐 CONFIG\n\n"
                    "🟢 VLESS TLS 443\n"
                    f"{info.get('VLESS_WS_TLS', '-')}\n\n"
                    "🌐 VLESS HTTP 80\n"
                    f"{info.get('VLESS_WS_80', '-')}\n\n"
                    "━━━━━━━━━━━━━━━━━━━━\n"
                    "Nagara Tunnel"
                )

            elif protocol == "vmess":
                message = (
                    "╔══════════════════════════════╗\n"
                    "║   ✅ USER BERHASIL DIBUAT   ║\n"
                    "╚══════════════════════════════╝\n\n"
                    f"👤 Username : {info.get('USERNAME', username)}\n"
                    f"🔌 Protocol : VMESS\n"
                    f"📅 Expired  : {info.get('EXPIRED', '-')}\n"
                    f"📱 Device   : {info.get('MAX_DEVICE', max_device)}\n"
                    f"📊 Status   : {info.get('STATUS', 'ACTIVE')}\n\n"
                    "🔐 CONFIG\n\n"
                    "🔵 VMess WS TLS 443\n"
                    f"{info.get('VMESS_WS_TLS', '-')}\n\n"
                    "🌐 VMess WS 80\n"
                    f"{info.get('VMESS_WS_80', '-')}\n\n"
                    "🔵 VMess gRPC TLS 443\n"
                    f"{info.get('VMESS_GRPC_TLS', '-')}\n\n"
                    "━━━━━━━━━━━━━━━━━━━━\n"
                    "Nagara Tunnel"
                )

            elif protocol == "trojan":
                message = (
                    "╔══════════════════════════════╗\n"
                    "║   ✅ USER BERHASIL DIBUAT   ║\n"
                    "╚══════════════════════════════╝\n\n"
                    f"👤 Username : {info.get('USERNAME', username)}\n"
                    f"🔌 Protocol : TROJAN\n"
                    f"📅 Expired  : {info.get('EXPIRED', '-')}\n"
                    f"📱 Device   : {info.get('MAX_DEVICE', max_device)}\n"
                    f"📊 Status   : {info.get('STATUS', 'ACTIVE')}\n\n"
                    "🔐 CONFIG\n\n"
                    "🟠 Trojan TLS 443\n"
                    f"{info.get('TROJAN_TLS_443', '-')}\n\n"
                    "━━━━━━━━━━━━━━━━━━━━\n"
                    "Nagara Tunnel"
                )

            else:
                message = (
                    "✅ USER BERHASIL DIBUAT\n\n"
                    + link_result.stdout.strip()
                )

            send_message(chat_id, message)

            USER_STATES.pop(chat_id, None)

        except Exception as e:
            send_message(
                chat_id,
                f"❌ Terjadi error:\n{e}"
            )
            USER_STATES.pop(chat_id, None)

    elif data == "create_cancel":
        USER_STATES.pop(chat_id, None)

        send_message(
            chat_id,
            "❌ Pembuatan user dibatalkan.",
            user_manager_menu()
        )

    elif data == "user_manager":
        send_message(
            chat_id,
            "👤 USER MANAGER\n\n"
            "Pilih tindakan:",
            user_manager_menu()
	)
    elif data == "user_list":
        send_message(
            chat_id,
            get_user_list(),
            get_user_list_menu()
        )

    elif data == "vps_status":
        send_message(
            chat_id,
            get_vps_status(),
            {
                "inline_keyboard": [
                    [
                        {"text": "🔄 Refresh", "callback_data": "vps_status"}
                    ],
                    [
                        {"text": "⬅️ Menu Utama", "callback_data": "main_menu"}
                    ]
                ]
            }
        )

    elif data == "main_menu":
        send_message(
            chat_id,
            "╔══════════════════════════════╗\n"
            "║       NAGARA TUNNEL BOT      ║\n"
            "╚══════════════════════════════╝\n"
            "\n"
            "Pilih menu:",
            main_menu()
        )

    else:
        send_message(
            chat_id,
            "Fitur ini belum diaktifkan."
        )


def handle_message(message):
    chat = message.get("chat", {})
    sender = message.get("from", {})

    chat_id = chat.get("id")
    user_id = str(sender.get("id", ""))

    if not chat_id:
        return

    if user_id != OWNER_ID:
        send_message(
            chat_id,
            "⛔ Akses ditolak.\n\n"
            "Bot ini hanya dapat digunakan oleh owner."
        )
        return

    text = message.get("text", "").strip()

    state = USER_STATES.get(chat_id)

    if state and state.get("step") == "renew_days":
        if not text.isdigit() or int(text) < 1:
            send_message(
                chat_id,
                "❌ Jumlah hari tidak valid.\n\n"
                "Masukkan angka minimal 1 hari.\n"
                "Contoh: 30"
            )
            return

        days = int(text)
        username = state.get("username", "")

        user_data = get_user_data(username)

        if not user_data:
            USER_STATES.pop(chat_id, None)
            send_message(
                chat_id,
                "❌ User tidak ditemukan."
            )
            return

        USER_STATES[chat_id]["days"] = days
        USER_STATES[chat_id]["step"] = "renew_confirm"

        send_message(
            chat_id,
            "📋 KONFIRMASI PERPANJANGAN\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {user_data[1].upper()}\n"
            f"📅 Expired sekarang : {user_data[4]}\n"
            f"➕ Tambah masa aktif : {days} hari\n\n"
            "Lanjutkan perpanjangan?",
            {
                "inline_keyboard": [
                    [
                        {
                            "text": "✅ Ya, Perpanjang",
                            "callback_data": "renew_confirm"
                        },
                        {
                            "text": "❌ Batal",
                            "callback_data": "renew_cancel"
                        }
                    ]
                ]
            }
        )
        return

    if state and state.get("step") == "username":
        username = text

        if not username:
            send_message(
                chat_id,
                "❌ Username tidak boleh kosong.\n\n"
                "Kirim username baru:"
            )
            return

        USER_STATES[chat_id]["username"] = username
        USER_STATES[chat_id]["step"] = "days"

        send_message(
            chat_id,
            f"👤 Username: {username}\n"
            f"🔌 Protocol: {state.get('protocol', '').upper()}\n\n"
            "Masukkan masa aktif dalam hari.\n"
            "Contoh: 30"
        )
        return

    if state and state.get("step") == "days":
        if not text.isdigit() or int(text) < 1:
            send_message(
                chat_id,
                "❌ Masa aktif tidak valid.\n\n"
                "Masukkan angka minimal 1 hari.\n"
                "Contoh: 30"
            )
            return

        days = int(text)

        USER_STATES[chat_id]["days"] = days
        USER_STATES[chat_id]["step"] = "max_device"

        send_message(
            chat_id,
            f"⏳ Masa aktif: {days} hari\n\n"
            "Masukkan maksimal jumlah device.\n"
            "Contoh: 2"
        )
        return
    if state and state.get("step") == "max_device":
        if not text.isdigit() or int(text) < 1:
            send_message(
                chat_id,
                "❌ Max device tidak valid.\n\n"
                "Masukkan angka minimal 1.\n"
                "Contoh: 2"
            )
            return

        max_device = int(text)

        USER_STATES[chat_id]["max_device"] = max_device
        USER_STATES[chat_id]["step"] = "confirm"

        protocol = state.get("protocol", "").upper()
        username = state.get("username", "")
        days = state.get("days", 0)

        send_message(
            chat_id,
            f"📋 KONFIRMASI USER\n\n"
            f"👤 Username : {username}\n"
            f"🔌 Protocol : {protocol}\n"
            f"⏳ Aktif    : {days} hari\n"
            f"📱 Device   : {max_device}\n\n"
            "Buat user ini?",
            {
                "inline_keyboard": [
                    [
                        {"text": "✅ Ya, Buat User", "callback_data": "create_confirm"},
                        {"text": "❌ Batal", "callback_data": "create_cancel"}
                    ]
                ]
            }
        )
        return

    if text in ("/start", "/menu"):
        send_message(
            chat_id,
            "╔══════════════════════════════╗\n"
            "║       NAGARA TUNNEL BOT      ║\n"
            "╚══════════════════════════════╝\n"
            "\n"
            "Pilih menu:",
            main_menu()
        )
        return

    send_message(
        chat_id,
        "Gunakan tombol menu atau /menu."
    )


def main():
    print("Nagara Telegram Bot starting...")

    offset = None

    while True:
        try:
            params = {
                "timeout": 30
            }

            if offset is not None:
                params["offset"] = offset

            result = telegram("getUpdates", params)

            if not result.get("ok"):
                print("Telegram API error:", result)
                time.sleep(5)
                continue

            for update in result.get("result", []):
                offset = update["update_id"] + 1

                if "callback_query" in update:
                    handle_callback(update["callback_query"])

                elif "message" in update:
                    handle_message(update["message"])

        except Exception as e:
            print("Bot error:", e)
            time.sleep(5)


if __name__ == "__main__":
    main()
