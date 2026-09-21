#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"

usage() {
    echo "Usage:"
    echo "  $0 USERNAME DAYS"
}

USERNAME="${1:-}"
DAYS="${2:-}"

if [ -z "$USERNAME" ] || [ -z "$DAYS" ]; then
    usage
    exit 1
fi

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Username tidak valid." >&2
    exit 1
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [ "$DAYS" -lt 1 ]; then
    echo "ERROR: Jumlah hari harus minimal 1." >&2
    exit 1
fi

if [ ! -f "$USER_FILE" ]; then
    echo "ERROR: Database user tidak ditemukan." >&2
    exit 1
fi

LINE="$(awk -F'|' -v u="$USERNAME" '$1 == u {print; exit}' "$USER_FILE")"

if [ -z "$LINE" ]; then
    echo "ERROR: User tidak ditemukan: $USERNAME" >&2
    exit 1
fi

IFS='|' read -r USER PROTOCOL CREDENTIAL CREATED OLD_EXPIRED MAX_DEVICE STATUS <<< "$LINE"

TODAY="$(date '+%Y-%m-%d')"

if [ -z "$OLD_EXPIRED" ]; then
    BASE_DATE="$TODAY"
elif [[ "$OLD_EXPIRED" < "$TODAY" ]]; then
    BASE_DATE="$TODAY"
else
    BASE_DATE="$OLD_EXPIRED"
fi

NEW_EXPIRED="$(date -d "$BASE_DATE + ${DAYS} days" '+%Y-%m-%d')"

BACKUP="$BASE/backups/users-db-renew-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"

cp "$USER_FILE" "$BACKUP"

awk -F'|' -v OFS='|' \
    -v u="$USERNAME" \
    -v e="$NEW_EXPIRED" \
    '$1 == u {
        $5=e
        $7="ACTIVE"
    }
    {
        print
    }' "$USER_FILE" > "$USER_FILE.tmp"

mv "$USER_FILE.tmp" "$USER_FILE"
chmod 600 "$USER_FILE"

echo "USER_RENEWED"
echo "USERNAME=$USERNAME"
echo "PROTOCOL=$PROTOCOL"
echo "OLD_EXPIRED=$OLD_EXPIRED"
echo "DAYS=$DAYS"
echo "EXPIRED=$NEW_EXPIRED"
echo "MAX_DEVICE=$MAX_DEVICE"
echo "STATUS=ACTIVE"

echo
echo "SYNC_XRAY"

if "$SYNC_SCRIPT"; then

    rm -f "$BACKUP"

    echo
    echo "RENEW_USER_SUCCESS"

else

    echo
    echo "SYNC_XRAY_FAILED"
    echo "ROLLBACK_DATABASE"

    cp "$BACKUP" "$USER_FILE"
    chmod 600 "$USER_FILE"
    rm -f "$BACKUP"

    echo "RENEW_USER_FAILED"
    exit 1

fi
