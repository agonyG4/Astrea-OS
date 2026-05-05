#!/bin/bash
set -euo pipefail

action="${1:-apply}"
conf_path="${HOME}/.local/share/Astrea/System/config/display/monitor-settings.conf"
unit_dir="${HOME}/.config/systemd/user"
service_path="${unit_dir}/astrea-night-shift.service"
timer_path="${unit_dir}/astrea-night-shift.timer"
night_shift_color="${HOME}/.local/share/Astrea/System/services/display_night_shift_color.sh"
state_dir="${HOME}/.local/state/Astrea/display"
state_path="${state_dir}/night-shift-state"
lock_path="${state_dir}/night-shift.lock"

write_units() {
    mkdir -p "${unit_dir}"
    cat > "${service_path}" <<EOF
[Unit]
Description=Apply Astrea Night Shift schedule
Documentation=file://${HOME}/.local/share/Astrea/System/services/display_night_shift_schedule.sh
ConditionPathExists=${HOME}/.local/share/Astrea/System/config/display/monitor-settings.conf

[Service]
Type=oneshot
ExecStart=${HOME}/.local/share/Astrea/System/services/display_night_shift_schedule.sh apply
TimeoutStartSec=8s
Nice=5
EOF

    cat > "${timer_path}" <<EOF
[Unit]
Description=Check Astrea Night Shift schedule

[Timer]
OnBootSec=20s
OnUnitActiveSec=60s
OnCalendar=*-*-* *:*:00
AccuracySec=15s
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

disable_units() {
    systemctl --user disable --now astrea-night-shift.timer >/dev/null 2>&1 || true
}

enable_units() {
    write_units
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable --now astrea-night-shift.timer >/dev/null 2>&1 || true
}

time_to_minutes() {
    local value="${1:-00:00}"
    local hour="${value%%:*}"
    local minute="${value##*:}"
    hour="${hour:-0}"
    minute="${minute:-0}"
    if ! [[ "${hour}" =~ ^[0-9]+$ && "${minute}" =~ ^[0-9]+$ ]]; then
        echo 0
        return
    fi
    hour=$((10#${hour}))
    minute=$((10#${minute}))
    (( hour = hour < 0 ? 0 : (hour > 23 ? 23 : hour) ))
    (( minute = minute < 0 ? 0 : (minute > 59 ? 59 : minute) ))
    echo $(( hour * 60 + minute ))
}

apply_identity() {
    "${night_shift_color}" off >/dev/null 2>&1 || true
}

temperature_for_strength() {
    local value="${1:-35}"
    if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
        value=35
    fi
    (( value = value < 0 ? 0 : (value > 100 ? 100 : value) ))
    local temperature=$(( 6000 - (value * 24) ))
    (( temperature = temperature < 3600 ? 3600 : temperature ))
    echo "${temperature}"
}

apply_if_changed() {
    local state="$1"
    local strength="${2:-0}"
    local temperature="identity"
    if [ "${state}" = "on" ]; then
        temperature="$(temperature_for_strength "${strength}")"
    fi

    local desired="${state}:${temperature}"
    if [ -f "${state_path}" ] && [ "$(cat "${state_path}" 2>/dev/null)" = "${desired}" ]; then
        return 0
    fi

    if [ "${state}" = "on" ]; then
        "${night_shift_color}" on "${strength}" >/dev/null 2>&1 || true
    else
        apply_identity
    fi

    mkdir -p "${state_dir}"
    local tmp
    tmp="$(mktemp "${state_dir}/night-shift-state.XXXXXX")"
    printf '%s\n' "${desired}" > "${tmp}"
    mv -f "${tmp}" "${state_path}"
}

apply_schedule() {
    mkdir -p "${state_dir}"
    exec 9>"${lock_path}"
    flock -n 9 || exit 0

    [ -f "${conf_path}" ] || exit 0
    # shellcheck source=/dev/null
    source "${conf_path}"

    night_shift_schedule=${night_shift_schedule:-0}
    night_shift_strength=${night_shift_strength:-35}
    night_shift_start=${night_shift_start:-20:00}
    night_shift_end=${night_shift_end:-07:00}

    if ! [[ "${night_shift_strength}" =~ ^[0-9]+$ ]]; then
        night_shift_strength=35
    fi
    (( night_shift_strength = night_shift_strength < 0 ? 0 : (night_shift_strength > 100 ? 100 : night_shift_strength) ))

    if [ "${night_shift_schedule}" != "1" ]; then
        apply_if_changed off
        exit 0
    fi

    local start end now active
    start="$(time_to_minutes "${night_shift_start}")"
    end="$(time_to_minutes "${night_shift_end}")"
    now=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))
    active=0

    if [ "${start}" -eq "${end}" ]; then
        active=1
    elif [ "${start}" -lt "${end}" ]; then
        [ "${now}" -ge "${start}" ] && [ "${now}" -lt "${end}" ] && active=1
    else
        { [ "${now}" -ge "${start}" ] || [ "${now}" -lt "${end}" ]; } && active=1
    fi

    if [ "${active}" = "1" ] && [ "${night_shift_strength}" -gt 0 ]; then
        apply_if_changed on "${night_shift_strength}"
    else
        apply_if_changed off
    fi
}

case "${action}" in
    install)
        enable_units
        apply_schedule
        ;;
    disable-timer)
        disable_units
        ;;
    uninstall)
        disable_units
        apply_identity
        ;;
    apply)
        apply_schedule
        ;;
    *)
        echo "Usage: $0 [install|disable-timer|uninstall|apply]" >&2
        exit 2
        ;;
esac
