#!/bin/bash
set -euo pipefail

apply_mode="${1:-full}"

conf_path="${HOME}/.local/share/Astrea/System/config/display/monitor-settings.conf"
[ -f "${conf_path}" ] || exit 0

source "${conf_path}"

vrr=${vrr:-0}
saturation=${saturation:-950}
night_shift=${night_shift:-0}
night_shift_strength=${night_shift_strength:-35}
monitor_id=${monitor_id:-0}
saturation=$(( saturation < 0 ? 0 : (saturation > 1023 ? 1023 : saturation) ))
monitor_rule="monitor=${monitor},${resolution}@${refreshrate},0x0,${scale},bitdepth,${bitdepth},vrr,${vrr}"

mkdir -p "${HOME}/.config/hypr/core"
printf '%s\n' "${monitor_rule}" > "${HOME}/.config/hypr/core/monitors.conf"

if [ "${apply_mode}" = "full" ]; then
    # Apply immediately for the current session, then reload so the persisted
    # file is re-read consistently by the active Hyprland config.
    hyprctl keyword monitor "${monitor},${resolution}@${refreshrate},0x0,${scale},bitdepth,${bitdepth},vrr,${vrr}"
    hyprctl reload
fi

if [ "${apply_mode}" = "full" ] || [ "${apply_mode}" = "colors-only" ] || [ "${apply_mode}" = "night-shift-only" ]; then
    if [ "${night_shift}" = "1" ] && [ "${night_shift_strength}" -gt 0 ]; then
        systemctl --user start hyprsunset.service >/dev/null 2>&1 || true
        sleep 0.15
        temperature=$(( 6000 - (night_shift_strength * 24) ))
        temperature=$(( temperature < 3600 ? 3600 : temperature ))
        hyprctl hyprsunset temperature "${temperature}" >/dev/null 2>&1 || true
    else
        if systemctl --user --quiet is-active hyprsunset.service; then
            hyprctl hyprsunset identity >/dev/null 2>&1 || true
            (
                sleep 5
                if [ -f "${conf_path}" ] && grep -q '^night_shift=0$' "${conf_path}"; then
                    systemctl --user stop hyprsunset.service >/dev/null 2>&1 || true
                fi
            ) >/dev/null 2>&1 &
        fi
    fi
fi

if [ "${apply_mode}" = "full" ] || [ "${apply_mode}" = "colors-only" ] || [ "${apply_mode}" = "saturation-only" ]; then
    nvibrant "${monitor}" "${saturation}" >/dev/null 2>&1 || true
fi
