#!/usr/bin/env bash
set -euo pipefail

config="${HOME}/.config/AstreaOS/ui/theme.json"
signal="${HOME}/.config/AstreaOS/state/theme.changed"

mkdir -p "$(dirname "${config}")" "$(dirname "${signal}")"

if [[ ! -f "${config}" ]]; then
    cat > "${config}" <<'JSON'
{
    "theme": "dark",
    "theme_mode": 0,
    "shell_style": 0,
    "accent": "#0a84ff",
    "icon_style": 0,
    "icon_theme": "dark"
}
JSON
fi

theme="dark"
theme_mode="0"

if command -v jq >/dev/null 2>&1; then
    theme="$(jq -r '.theme // empty' "${config}" 2>/dev/null || true)"
    theme_mode="$(jq -r '.theme_mode // 0' "${config}" 2>/dev/null || true)"
else
    theme="$(python3 - "${config}" <<'PY' 2>/dev/null || true
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("theme", ""))
PY
)"
    theme_mode="$(python3 - "${config}" <<'PY' 2>/dev/null || true
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("theme_mode", 0))
PY
)"
fi

if [[ -z "${theme}" || "${theme}" == "null" ]]; then
    if [[ "${theme_mode}" == "1" ]]; then
        theme="light"
    else
        theme="dark"
    fi
fi

if [[ "${theme}" != "light" ]]; then
    theme="dark"
    theme_mode="0"
else
    theme_mode="1"
fi

apply_desktop_preference() {
    if ! command -v gsettings >/dev/null 2>&1; then
        return 0
    fi

    local schema="org.gnome.desktop.interface"
    local color_scheme="prefer-dark"
    local prefer_dark="true"

    if [[ "${theme}" == "light" ]]; then
        prefer_dark="false"
        if gsettings range "${schema}" color-scheme 2>/dev/null | grep -q "'prefer-light'"; then
            color_scheme="prefer-light"
        else
            color_scheme="default"
        fi
    fi

    if gsettings writable "${schema}" color-scheme >/dev/null 2>&1; then
        gsettings set "${schema}" color-scheme "${color_scheme}" >/dev/null 2>&1 || true
    fi

    if gsettings writable "${schema}" gtk-application-prefer-dark-theme >/dev/null 2>&1; then
        gsettings set "${schema}" gtk-application-prefer-dark-theme "${prefer_dark}" >/dev/null 2>&1 || true
    fi
}

apply_desktop_preference

printf '%s %s %s\n' "$(date +%s%N)" "${theme}" "${theme_mode}" > "${signal}"
