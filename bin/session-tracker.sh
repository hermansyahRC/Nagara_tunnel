#!/bin/bash

BASE="/opt/nagara-tunnel"
ACCESS_LOG="$BASE/logs/xray-access.log"
SESSION_DIR="$BASE/runtime/sessions"
SESSION_FILE="$SESSION_DIR/sessions.db"

mkdir -p "$SESSION_DIR"
touch "$SESSION_FILE"

DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')

echo "=============================================="
echo "        NAGARA TUNNEL SESSION SCAN"
echo "=============================================="
echo "Waktu : $DATE_NOW"
echo

if [ ! -f "$ACCESS_LOG" ]; then
    echo "Access log tidak ditemukan."
    exit 1
fi

echo "Aktivitas user terbaru:"
echo "----------------------------------------------"

tail -50 "$ACCESS_LOG" |
awk '
/email:/ {
    user=$0
    sub(/^.*email: /, "", user)
    print user
}
' |
sort | uniq -c |
sort -nr

echo
echo "Aktivitas terakhir:"
echo "----------------------------------------------"
tail -10 "$ACCESS_LOG"

echo
echo "Scan selesai."
echo "=============================================="

{
    echo "[$DATE_NOW]"
    tail -50 "$ACCESS_LOG" |
    awk '
    /email:/ {
        user=$0
        sub(/^.*email: /, "", user)
        print user
    }' |
    sort | uniq -c |
    sort -nr
    echo
} >> "$SESSION_FILE"
