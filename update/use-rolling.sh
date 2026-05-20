#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.local/share/Astrea-Rolling"
active="$HOME/.local/share/Astrea"

[[ -d "$target" ]] || { printf '[ERROR] Missing Rolling runtime: %s\n' "$target" >&2; exit 1; }
ln -sfn "$target" "$active"
printf '[INFO] Active runtime: %s -> %s\n' "$active" "$(readlink "$active")"
