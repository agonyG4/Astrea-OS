#!/usr/bin/env bash
set -euo pipefail

pictures_dir="${XDG_PICTURES_DIR:-$HOME/Imagens}"
output_dir="$pictures_dir/Capturas de tela"
runtime_base="${XDG_RUNTIME_DIR:-/tmp}/astrea-screenshot"
stamp="$(date +'%Y-%m-%d_%H-%M-%S')"
full_frame="$runtime_base/frozen-$stamp.png"
output_file="$output_dir/Captura de tela $stamp.png"

mkdir -p "$output_dir" "$runtime_base"
grim "$full_frame"

ASTREA_SCREENSHOT_FULL="$full_frame" \
ASTREA_SCREENSHOT_OUTPUT="$output_file" \
    exec quickshell -p "/home/agony/GitHub/Bench/Screenshot/Main.qml"
