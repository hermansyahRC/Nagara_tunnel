#!/usr/bin/env bash

set -euo pipefail

BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"
SYNC_SCRIPT="$BASE/bin/sync-users.sh"

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 USERNAME"
    exit 1
fi

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Username tidak valid." >&2
    exit 1
fi

if ! grep -q "^${USERNAME}|" "$USER_FILE"; then
    echo "ERROR: User tidak ditemukan." >&2
    exit 1
fi

BACKUP="$BASE/backups/users-db-delete-$(date +%Y%m%d-%H%M%S).db"

mkdir -p "$BASE/backups"

cp "$USER_FILE" "$BACKUP"

echo "USER_FOUND"
echo "USERNAME=$USERNAME"

grep "^${USERNAME}|" "$USER_FILE"

echo
echo "DELETE_USER"

awk -F'|' -v user="$USERNAME" '$1 != user' "$USER_FILE" > "${USER_FILE}.tmp"
mv "${USER_FILE}.tmp" "$USER_FILE"

echo "USER_REMOVED_FROM_DATABASE"
echo
echo "SYNC_XRAY"

if "$SYNC_SCRIPT"; then

    rm -f "$BACKUP"

    echo
    echo "DELETE_USER_SUCCESS"

else

    echo
    echo "SYNC_XRAY_FAILED"
    echo "ROLLBACK_DATABASE"

    cp "$BACKUP" "$USER_FILE"
    rm -f "$BACKUP"

    echo "DELETE_USER_FAILED"
    exit 1
fi
