#!/bin/bash
set -euo pipefail

action="${1:-apply}"
ASTREA_ROOT="${ASTREA_ROOT:-$HOME/.local/share/Astrea}"
conf_path="${ASTREA_ROOT}/System/config/display/monitor-settings.conf"
unit_dir="${HOME}/.config/systemd/user"
service_path="${unit_dir}/astrea-night-shift.service"
timer_path="${unit_dir}/astrea-night-shift.timer"
night_shift_color="${ASTREA_ROOT}/System/services/display_night_shift_color.sh"
state_dir="${HOME}/.local/state/Astrea/display"
state_path="${state_dir}/night-shift-state"
lock_path="${state_dir}/night-shift.lock"

read_conf_value() {
	local key="$1"
	local fallback="${2:-}"
	awk -F= -v key="${key}" -v fallback="${fallback}" '
        /^[[:space:]]*#/ { next }
        $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
            value = substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^[A-Za-z0-9_.:@+,% -]+$/) { print value; found=1; exit }
        }
        END { if (!found) print fallback }
    ' "${conf_path}"
}

write_units() {
	mkdir -p "${unit_dir}"
	local tmp_service tmp_timer start_time end_time calendar_lines
	tmp_service="$(mktemp "${service_path}.XXXXXX")"
	tmp_timer="$(mktemp "${timer_path}.XXXXXX")"
	start_time="$(minutes_to_time "$(time_to_minutes "$(read_conf_value night_shift_start 20:00)")")"
	end_time="$(minutes_to_time "$(time_to_minutes "$(read_conf_value night_shift_end 07:00)")")"
	if [ "${start_time}" = "${end_time}" ]; then
		calendar_lines="OnCalendar=*-*-* 00:00:00"
	else
		calendar_lines="OnCalendar=*-*-* ${start_time}:00
OnCalendar=*-*-* ${end_time}:00"
	fi

	cat >"${tmp_service}" <<EOF
[Unit]
Description=Apply Astrea Night Shift schedule
Documentation=file://${ASTREA_ROOT}/System/services/display_night_shift_schedule.sh
ConditionPathExists=${ASTREA_ROOT}/System/config/display/monitor-settings.conf

[Service]
Type=oneshot
ExecStart=${ASTREA_ROOT}/System/services/display_night_shift_schedule.sh apply
TimeoutStartSec=8s
Nice=5
EOF

	cat >"${tmp_timer}" <<EOF
[Unit]
Description=Apply Astrea Night Shift at scheduled transitions

[Timer]
OnBootSec=20s
${calendar_lines}
AccuracySec=30s
Persistent=true

[Install]
WantedBy=timers.target
EOF
	mv -f "${tmp_service}" "${service_path}"
	mv -f "${tmp_timer}" "${timer_path}"
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
	((hour = hour < 0 ? 0 : (hour > 23 ? 23 : hour)))
	((minute = minute < 0 ? 0 : (minute > 59 ? 59 : minute)))
	echo $((hour * 60 + minute))
}

minutes_to_time() {
	local value="${1:-0}"
	if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
		value=0
	fi
	((value = value % 1440))
	printf '%02d:%02d\n' $((value / 60)) $((value % 60))
}

apply_identity() {
	"${night_shift_color}" off >/dev/null 2>&1 || true
}

temperature_for_strength() {
	local value="${1:-35}"
	if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
		value=35
	fi
	((value = value < 0 ? 0 : (value > 100 ? 100 : value)))
	local temperature=$((6000 - (value * 24)))
	((temperature = temperature < 3600 ? 3600 : temperature))
	echo "${temperature}"
}

apply_if_changed() {
	local state="$1"
	local strength="${2:-0}"
	local temperature="identity"
	local boot_id=""
	if [ "${state}" = "on" ]; then
		temperature="$(temperature_for_strength "${strength}")"
		boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)"
	fi

	local desired="${state}:${temperature}"
	if [ -n "${boot_id}" ]; then
		desired="${desired}:boot=${boot_id}"
	fi
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
	printf '%s\n' "${desired}" >"${tmp}"
	mv -f "${tmp}" "${state_path}"
}

apply_schedule() {
	mkdir -p "${state_dir}"
	exec 9>"${lock_path}"
	flock -n 9 || exit 0

	[ -f "${conf_path}" ] || exit 0

	night_shift_schedule="$(read_conf_value night_shift_schedule 0)"
	night_shift_strength="$(read_conf_value night_shift_strength 35)"
	night_shift_start="$(read_conf_value night_shift_start 20:00)"
	night_shift_end="$(read_conf_value night_shift_end 07:00)"

	if ! [[ "${night_shift_strength}" =~ ^[0-9]+$ ]]; then
		night_shift_strength=35
	fi
	((night_shift_strength = night_shift_strength < 0 ? 0 : (night_shift_strength > 100 ? 100 : night_shift_strength)))

	if [ "${night_shift_schedule}" != "1" ]; then
		apply_if_changed off
		exit 0
	fi

	local start end now active
	start="$(time_to_minutes "${night_shift_start}")"
	end="$(time_to_minutes "${night_shift_end}")"
	now=$((10#$(date +%H) * 60 + 10#$(date +%M)))
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
