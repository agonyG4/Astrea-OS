#!/bin/bash
set -euo pipefail

apply_mode="${1:-full}"

conf_path="${HOME}/.local/share/Astrea/System/config/display/monitor-settings.conf"
[ -f "${conf_path}" ] || exit 0

source "${conf_path}"

monitor=${monitor:-}
resolution=${resolution:-preferred}
refreshrate=${refreshrate:-60}
scale=${scale:-1}
bitdepth=${bitdepth:-8}
vrr=${vrr:-0}
saturation=${saturation:-950}
night_shift=${night_shift:-0}
night_shift_strength=${night_shift_strength:-35}
night_shift_schedule=${night_shift_schedule:-0}
night_shift_start=${night_shift_start:-20:00}
night_shift_end=${night_shift_end:-07:00}
monitor_id=${monitor_id:-0}
if [ -z "${monitor}" ]; then
    monitor="$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data[0].get("name","")) if data else None' 2>/dev/null || true)"
fi
[ -n "${monitor}" ] || exit 0

saturation=$(( saturation < 0 ? 0 : (saturation > 1023 ? 1023 : saturation) ))
monitor_rule="monitor=${monitor},${resolution}@${refreshrate},0x0,${scale},bitdepth,${bitdepth},vrr,${vrr}"
night_shift_color="${HOME}/.local/share/Astrea/System/services/display_night_shift_color.sh"

mkdir -p "${HOME}/.config/hypr/core"
printf '%s\n' "${monitor_rule}" > "${HOME}/.config/hypr/core/monitors.conf"

if [ "${apply_mode}" = "full" ]; then
    # Apply immediately for the current session, then reload so the persisted
    # file is re-read consistently by the active Hyprland config.
    hyprctl keyword monitor "${monitor},${resolution}@${refreshrate},0x0,${scale},bitdepth,${bitdepth},vrr,${vrr}" >/dev/null 2>&1 || true
    hyprctl reload >/dev/null 2>&1 || true
fi

if [ "${apply_mode}" = "full" ] || [ "${apply_mode}" = "colors-only" ] || [ "${apply_mode}" = "night-shift-only" ]; then
    if [ "${night_shift_schedule}" = "1" ]; then
        "${HOME}/.local/share/Astrea/System/services/display_night_shift_schedule.sh" install >/dev/null 2>&1 || true
    else
        "${HOME}/.local/share/Astrea/System/services/display_night_shift_schedule.sh" disable-timer >/dev/null 2>&1 || true
    fi

    if [ "${night_shift_schedule}" = "1" ]; then
        :
    elif [ "${night_shift}" = "1" ] && [ "${night_shift_strength}" -gt 0 ]; then
        "${night_shift_color}" on "${night_shift_strength}" >/dev/null 2>&1 || true
    else
        "${night_shift_color}" off >/dev/null 2>&1 || true
    fi
fi

if [ "${apply_mode}" = "full" ] || [ "${apply_mode}" = "colors-only" ] || [ "${apply_mode}" = "saturation-only" ]; then
    nvibrant "${monitor}" "${saturation}" >/dev/null 2>&1 || true
fi
