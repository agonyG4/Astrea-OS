#!/bin/bash
set -euo pipefail

action="${1:-}"
strength="${2:-35}"

clamp_strength() {
	local value="${1:-35}"
	if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
		value=35
	fi
	((value = value < 0 ? 0 : (value > 100 ? 100 : value)))
	echo "${value}"
}

temperature_for_strength() {
	local value
	value="$(clamp_strength "$1")"
	local temperature=$((6000 - (value * 24)))
	((temperature = temperature < 3600 ? 3600 : temperature))
	echo "${temperature}"
}

send_hyprsunset() {
	if ! command -v hyprctl >/dev/null 2>&1; then
		return 0
	fi

	if hyprctl hyprsunset "$@" >/dev/null 2>&1; then
		return 0
	fi

	if command -v systemctl >/dev/null 2>&1; then
		systemctl --user start hyprsunset.service >/dev/null 2>&1 || true
	fi

	local delay
	for delay in 0.08 0.16 0.28; do
		sleep "${delay}"
		if hyprctl hyprsunset "$@" >/dev/null 2>&1; then
			return 0
		fi
	done

	return 0
}

case "${action}" in
on | temperature)
	send_hyprsunset temperature "$(temperature_for_strength "${strength}")"
	;;
off | identity)
	send_hyprsunset identity
	;;
*)
	echo "Usage: $0 on [strength]|off" >&2
	exit 2
	;;
esac
