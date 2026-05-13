#!/usr/bin/env bash
set -euo pipefail

ASTREA_ROOT="${ASTREA_ROOT:-$HOME/.local/share/Astrea}"
exec "${ASTREA_ROOT}/System/services/theme/apply_decoration_style.sh" "$@"
