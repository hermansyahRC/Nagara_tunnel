#!/bin/bash
BASE="/opt/nagara-tunnel"
SERVER="127.0.0.1:10085"
STATE="$BASE/runtime/traffic-history/state"
mkdir -p "$STATE"
xray api statsquery --server="$SERVER" 2>/dev/null | jq -r ".stat[] | select(.name | startswith(\"user>>>\")) | [.name, (.value // 0)] | @tsv" > "$STATE/xray-baseline.tsv"
