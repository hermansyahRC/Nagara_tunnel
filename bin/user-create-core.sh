#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_password() {
    openssl rand -hex 16
}

usage() {
    echo "Usage:"
    echo "  $0 USERNAME PROTOCOL DAYS MAX_DEVICE"
    echo
    echo "Protocol: vless | vmess | trojan"
}

USERNAME="${1:-}"
PROTOCOL="${2:-}"
DAYS="${3:-}"
MAX_DEVICE="${4:-}"

if [ -z "$USERNAME" ] || [ -z "$PROTOCOL" ] || \
   [ -z "$DAYS" ] || [ -z "$MAX_DEVICE" ]; then
    usage
    exit 1
fi

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Username tidak valid." >&2
    exit 1
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [ "$DAYS" -lt 1 ]; then
    echo "ERROR: Masa aktif harus minimal 1 hari." >&2
    exit 1
fi

if ! [[ "$MAX_DEVICE" =~ ^[0-9]+$ ]] || [ "$MAX_DEVICE" -lt 1 ]; then
    echo "ERROR: Max device harus minimal 1." >&2
    exit 1
fi

case "$PROTOCOL" in
    vless|vmess)
        CREDENTIAL=$(generate_uuid)
        ;;
    trojan)
        CREDENTIAL=$(generate_password)
        ;;
    *)
        echo "ERROR: Protocol tidak valid: $PROTOCOL" >&2
        exit 1
        ;;
esac

if grep -q "^${USERNAME}|" "$USER_FILE"; then
    echo "ERROR: User sudah ada." >&2
    exit 1
fi

CREATED=$(date '+%Y-%m-%d')
EXPIRED=$(date -d "+${DAYS} days" '+%Y-%m-%d')
STATUS="ACTIVE"

BACKUP="$BASE/backups/users-db-create-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"

cp "$USER_FILE" "$BACKUP"

echo "${USERNAME}|${PROTOCOL}|${CREDENTIAL}|${CREATED}|${EXPIRED}|${MAX_DEVICE}|${STATUS}" >> "$USER_FILE"

echo "USER_CREATED"
echo "USERNAME=$USERNAME"
echo "PROTOCOL=$PROTOCOL"
echo "CREDENTIAL=$CREDENTIAL"
echo "CREATED=$CREATED"
echo "EXPIRED=$EXPIRED"
echo "MAX_DEVICE=$MAX_DEVICE"
echo "STATUS=$STATUS"

echo
echo "SYNC_XRAY"

if "$SYNC_SCRIPT"; then

    rm -f "$BACKUP"

    echo
    echo "CREATE_USER_SUCCESS"

else

    echo
    echo "SYNC_XRAY_FAILED"
    echo "ROLLBACK_DATABASE"

    cp "$BACKUP" "$USER_FILE"
    rm -f "$BACKUP"

    echo "CREATE_USER_FAILED"
    exit 1

fi
