#!/bin/bash
set -euo pipefail

if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    STATE_DIR="${XDG_RUNTIME_DIR}/Astrea/hypr"
else
    STATE_DIR="${HOME}/.local/state/Astrea/hypr"
fi
STATE_FILE="${STATE_DIR}/float_state"
mkdir -p "${STATE_DIR}"

if [[ -f "$STATE_FILE" ]]; then
    while IFS= read -r addr; do
        [[ -n "$addr" ]] || continue
        hyprctl dispatch togglefloating "address:$addr"
    done < "$STATE_FILE"
    rm -f "$STATE_FILE"
else
    tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
    hyprctl clients -j | jq -r '.[] | select(.floating == false) | .address' > "$tmp"
    mv -f "$tmp" "$STATE_FILE"

    while IFS= read -r addr; do
        [[ -n "$addr" ]] || continue
        hyprctl dispatch togglefloating "address:$addr"
    done < "$STATE_FILE"
fi
