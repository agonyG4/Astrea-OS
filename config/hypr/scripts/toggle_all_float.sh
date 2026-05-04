#!/bin/bash

STATE_FILE="/tmp/hypr_float_state"

if [[ -f "$STATE_FILE" ]]; then
    # Reverter: só as janelas que a gente flotou
    while IFS= read -r addr; do
        hyprctl dispatch togglefloating "address:$addr"
    done < "$STATE_FILE"
    rm "$STATE_FILE"
else
    # Flotar todas as janelas tiled de todos os workspaces
    hyprctl clients -j | jq -r '.[] | select(.floating == false) | .address' > "$STATE_FILE"
    
    while IFS= read -r addr; do
        hyprctl dispatch togglefloating "address:$addr"
    done < "$STATE_FILE"
fi