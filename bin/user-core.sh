#!/usr/bin/env bash

BASE="/opt/nagara-tunnel"
USER_FILE="$BASE/users/users.db"

get_user() {
    local username="$1"

    if [ -z "$username" ]; then
        echo "ERROR: username kosong." >&2
        return 1
    fi

    if [ ! -f "$USER_FILE" ]; then
        echo "ERROR: database user tidak ditemukan." >&2
        return 1
    fi

    awk -F'|' -v u="$username" '
        $1 == u {
            print
            exit
        }
    ' "$USER_FILE"
}

user_exists() {
    local username="$1"

    [ -n "$(get_user "$username")" ]
}

get_credential() {
    local username="$1"
    local record

    record=$(get_user "$username") || return 1

    [ -n "$record" ] || return 1

    printf '%s\n' "$record" | cut -d'|' -f3
}

get_protocol() {
    local username="$1"
    local record

    record=$(get_user "$username") || return 1

    [ -n "$record" ] || return 1

    printf '%s\n' "$record" | cut -d'|' -f2
}

get_expired() {
    local username="$1"
    local record

    record=$(get_user "$username") || return 1

    [ -n "$record" ] || return 1

    printf '%s\n' "$record" | cut -d'|' -f5
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then

    case "${1:-}" in

        get)
            get_user "${2:-}"
            ;;

        exists)
            if user_exists "${2:-}"; then
                echo "YES"
            else
                echo "NO"
                exit 1
            fi
            ;;

        credential)
            get_credential "${2:-}"
            ;;

        protocol)
            get_protocol "${2:-}"
            ;;

        expired)
            get_expired "${2:-}"
            ;;

        *)
            echo "Usage:"
            echo "  $0 get USERNAME"
            echo "  $0 exists USERNAME"
            echo "  $0 credential USERNAME"
            echo "  $0 protocol USERNAME"
            echo "  $0 expired USERNAME"
            exit 1
            ;;

    esac
fi
