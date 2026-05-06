#!/usr/bin/env bash
set -euo pipefail

FORMAT='{{status}}|||{{title}}|||{{artist}}|||{{mpris:artUrl}}|||{{position}}|||{{mpris:length}}|||{{shuffle}}'

while read -r pid args; do
    case "$args" in
        *"playerctl --player=spotify metadata --format {{status}}|||{{title}}"*"--follow"*)
            if [[ "$pid" != "$$" ]]; then
                kill "$pid" 2>/dev/null || true
            fi
            ;;
    esac
done < <(ps -eo pid=,args=)

exec playerctl --player=spotify metadata --format "$FORMAT" --follow
