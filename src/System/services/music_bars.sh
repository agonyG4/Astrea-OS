#!/usr/bin/env bash
set -euo pipefail

ASTREA_ROOT="${ASTREA_ROOT:-$HOME/.local/share/Astrea}"
exec "${ASTREA_ROOT}/Core/bridge/audio/music_bars_backend" "$@"
