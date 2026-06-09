#!/usr/bin/env bash
set -euo pipefail

home="${HOME:-}"
if [[ -z "${home}" ]]; then
	home="$(getent passwd "$(id -un)" | cut -d: -f6)"
fi
astrea_root="${ASTREA_ROOT:-${home}/.local/share/Astrea}"
unit_dir="${home}/.config/systemd/user"
dbus_dir="${home}/.local/share/dbus-1/services"
portal_dir="${home}/.local/share/xdg-desktop-portal/portals"
xdg_portal_conf_dir="${home}/.config/xdg-desktop-portal"
astrea_bin_dir="${astrea_root}/bin"
weather_backend_dir="${astrea_root}/Apps/Weather/backend"
launch_backend_dir="${astrea_root}/System/launch"
portal_backend_dir="${astrea_root}/System/portal"
status_backend_dir="${astrea_root}/System/statusd"
latency_backend_dir="${astrea_root}/System/latencyd"

info() { printf '[astrea-services] %s\n' "$*"; }
warn() { printf '[astrea-services][warn] %s\n' "$*" >&2; }

write_file_if_changed() {
	local path="$1"
	local mode="$2"
	local tmp
	tmp="$(mktemp)"
	cat >"${tmp}"
	if [[ -f "${path}" ]] && cmp -s "${tmp}" "${path}"; then
		rm -f "${tmp}"
		return 0
	fi
	install -Dm"${mode}" "${tmp}" "${path}"
	rm -f "${tmp}"
}

write_night_shift_units() {
	"${astrea_root}/System/services/display_night_shift_schedule.sh" install
}

write_portal_files() {
	mkdir -p "${unit_dir}" "${dbus_dir}" "${portal_dir}" "${xdg_portal_conf_dir}"

	write_file_if_changed "${unit_dir}/astrea-filechooser-portal.service" 0644 <<EOF
[Unit]
Description=Astrea Explorer FileChooser Portal Backend
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=5

[Service]
Type=simple
Environment=XDG_CURRENT_DESKTOP=Hyprland
ExecStart=${astrea_bin_dir}/astrea-filechooser-portal
Restart=on-failure
RestartSec=2
TimeoutStopSec=3
KillMode=process

[Install]
WantedBy=default.target
EOF

	write_file_if_changed "${dbus_dir}/org.freedesktop.impl.portal.desktop.astrea.service" 0644 <<EOF
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.astrea
Exec=${astrea_bin_dir}/astrea-filechooser-portal
EOF

	write_file_if_changed "${portal_dir}/astrea.portal" 0644 <<EOF
[portal]
DBusName=org.freedesktop.impl.portal.desktop.astrea
Interfaces=org.freedesktop.impl.portal.FileChooser;
UseIn=Hyprland;wlroots;sway;Wayfire;river;
EOF

	write_file_if_changed "${xdg_portal_conf_dir}/portals.conf" 0644 <<EOF
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=astrea;gtk
EOF

	write_file_if_changed "${xdg_portal_conf_dir}/hyprland-portals.conf" 0644 <<EOF
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=astrea;gtk
EOF
}

write_status_unit() {
	mkdir -p "${unit_dir}"
	write_file_if_changed "${unit_dir}/astrea-status.service" 0644 <<EOF
[Unit]
Description=Astrea status cache service
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=5

[Service]
Type=simple
ExecStart=${astrea_bin_dir}/astrea-statusd
Restart=on-failure
RestartSec=2
TimeoutStopSec=3
KillMode=process

[Install]
WantedBy=graphical-session.target
EOF
}

write_latency_unit() {
	mkdir -p "${unit_dir}"
	write_file_if_changed "${unit_dir}/astrea-latencyd.service" 0644 <<EOF
[Unit]
Description=Astrea temporary latency boost daemon
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=5

[Service]
Type=simple
ExecStart=${astrea_bin_dir}/astrea-latencyd serve
Restart=on-failure
RestartSec=2
TimeoutStopSec=3
KillMode=mixed

[Install]
WantedBy=graphical-session.target
EOF
}

write_launch_unit() {
	mkdir -p "${unit_dir}"
	write_file_if_changed "${unit_dir}/astrea-launchd.service" 0644 <<EOF
[Unit]
Description=Astrea app launch service
After=graphical-session.target astrea-latencyd.service
PartOf=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=5

[Service]
Type=simple
ExecStart=${astrea_bin_dir}/astrea-launch daemon
Restart=on-failure
RestartSec=2
TimeoutStopSec=3
KillMode=process

[Install]
WantedBy=graphical-session.target
EOF
}

install_status_binary() {
	if [[ ! -f "${status_backend_dir}/Cargo.toml" ]]; then
		warn "status backend manifest not found; leaving existing astrea-statusd binary in place: ${status_backend_dir}/Cargo.toml"
		return 1
	fi
	if ! command -v cargo >/dev/null 2>&1; then
		warn 'cargo not found; leaving existing astrea-statusd binary in place'
		return 1
	fi

	if ! cargo build --manifest-path "${status_backend_dir}/Cargo.toml" --release; then
		warn 'failed to build astrea-statusd; leaving existing binary in place'
		return 1
	fi

	if [[ ! -x "${status_backend_dir}/target/release/astrea-statusd" ]]; then
		warn 'astrea-statusd build completed but expected binary is missing'
		return 1
	fi

	install -Dm755 "${status_backend_dir}/target/release/astrea-statusd" "${astrea_bin_dir}/astrea-statusd"
}

install_latency_binary() {
	if [[ ! -f "${latency_backend_dir}/Cargo.toml" ]]; then
		warn "latency backend manifest not found; leaving existing astrea-latencyd binary in place: ${latency_backend_dir}/Cargo.toml"
		return 1
	fi
	if ! command -v cargo >/dev/null 2>&1; then
		warn 'cargo not found; leaving existing astrea-latencyd binary in place'
		return 1
	fi

	if ! cargo build --manifest-path "${latency_backend_dir}/Cargo.toml" --release; then
		warn 'failed to build astrea-latencyd; leaving existing binary in place'
		return 1
	fi

	if [[ ! -x "${latency_backend_dir}/target/release/astrea-latencyd" ]]; then
		warn 'astrea-latencyd build completed but expected binary is missing'
		return 1
	fi

	install -Dm755 "${latency_backend_dir}/target/release/astrea-latencyd" "${astrea_bin_dir}/astrea-latencyd"
}

install_weather_binaries() {
	if [[ ! -f "${weather_backend_dir}/Cargo.toml" ]]; then
		warn "weather backend manifest not found; leaving existing weather binaries in place: ${weather_backend_dir}/Cargo.toml"
		return 1
	fi
	if ! command -v cargo >/dev/null 2>&1; then
		warn 'cargo not found; leaving existing Astrea weather binaries in place'
		return 1
	fi

	if ! cargo build --manifest-path "${weather_backend_dir}/Cargo.toml" --workspace --release; then
		warn 'failed to build Astrea weather binaries; leaving existing binaries in place'
		return 1
	fi

	if [[ ! -x "${weather_backend_dir}/target/release/weather-cli" || ! -x "${weather_backend_dir}/target/release/astrea-weatherd" ]]; then
		warn 'weather build completed but expected binaries are missing'
		return 1
	fi

	install -Dm755 "${weather_backend_dir}/target/release/weather-cli" "${astrea_bin_dir}/weather-cli"
	install -Dm755 "${weather_backend_dir}/target/release/astrea-weatherd" "${astrea_bin_dir}/astrea-weatherd"
}

install_launch_binary() {
	if [[ ! -f "${launch_backend_dir}/Cargo.toml" ]]; then
		warn "launch backend manifest not found; leaving existing astrea-launch in place: ${launch_backend_dir}/Cargo.toml"
		return 1
	fi
	if ! command -v cargo >/dev/null 2>&1; then
		warn 'cargo not found; leaving existing astrea-launch binary in place'
		return 1
	fi

	if ! cargo build --manifest-path "${launch_backend_dir}/Cargo.toml" --release; then
		warn 'failed to build astrea-launch; leaving existing binary in place'
		return 1
	fi

	if [[ ! -x "${launch_backend_dir}/target/release/astrea-launch" ]]; then
		warn 'astrea-launch build completed but expected binary is missing'
		return 1
	fi

	install -Dm755 "${launch_backend_dir}/target/release/astrea-launch" "${astrea_bin_dir}/astrea-launch"
}

weather_binaries_available() {
	[[ -x "${astrea_bin_dir}/weather-cli" && -x "${astrea_bin_dir}/astrea-weatherd" ]]
}

write_weather_unit() {
	mkdir -p "${unit_dir}"
	write_file_if_changed "${unit_dir}/astrea-weatherd.service" 0644 <<EOF
[Unit]
Description=Astrea weather monitor service
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
ExecStart=${astrea_bin_dir}/astrea-weatherd
Restart=on-failure
RestartSec=10
TimeoutStopSec=3
KillMode=mixed

[Install]
WantedBy=default.target
EOF
}

reload_user_systemd() {
	if command -v systemctl >/dev/null 2>&1; then
		systemctl --user daemon-reload >/dev/null 2>&1 || true
	fi
}

install_services() {
	write_portal_files
	if ! install_status_binary; then
		warn 'astrea-statusd was not rebuilt during install.'
	fi
	write_status_unit
	if ! install_latency_binary; then
		warn 'astrea-latencyd was not rebuilt during install.'
	fi
	write_latency_unit
	if ! install_launch_binary; then
		warn 'astrea-launch was not rebuilt during install.'
	fi
	write_launch_unit
	if ! install_weather_binaries; then
		warn 'Astrea weather binaries were not rebuilt during install.'
	fi
	if weather_binaries_available; then
		write_weather_unit
	else
		warn 'Astrea weather service not installed/enabled because weather binaries are missing.'
	fi
	write_night_shift_units
	reload_user_systemd
	if command -v systemctl >/dev/null 2>&1; then
		systemctl --user enable --now astrea-latencyd.service >/dev/null 2>&1 || true
		systemctl --user enable --now astrea-launchd.service >/dev/null 2>&1 || true
		if weather_binaries_available; then
			systemctl --user enable --now astrea-weatherd.service >/dev/null 2>&1 || true
		else
			systemctl --user disable --now astrea-weatherd.service >/dev/null 2>&1 || true
		fi
	fi
}

verify_paths() {
	local failed=0
	local path
	for path in "$@"; do
		if [[ ! -f "${path}" ]]; then
			printf 'missing: %s\n' "${path}" >&2
			failed=1
		fi
	done
	return "${failed}"
}

verify_systemd_units() {
	if ! command -v systemd-analyze >/dev/null 2>&1; then
		return 0
	fi

	local verify_output
	if ! verify_output="$(systemd-analyze --user verify "$@" 2>&1)"; then
		if grep -Eq 'Operation not permitted|Failed to connect to (user|system) scope bus|SO_PASS' <<<"${verify_output}"; then
			printf 'systemd unit syntax check skipped: user manager unavailable in this context\n' >&2
			return 0
		fi
		printf '%s\n' "${verify_output}" >&2
		return 1
	fi
	return 0
}

verify_core_services() {
	local failed=0
	local units=(
		"${unit_dir}/astrea-status.service"
		"${unit_dir}/astrea-latencyd.service"
		"${unit_dir}/astrea-launchd.service"
		"${unit_dir}/astrea-night-shift.service"
		"${unit_dir}/astrea-night-shift.timer"
	)

	verify_paths "${units[@]}" || failed=1
	verify_systemd_units "${units[@]}" || failed=1

	bash -n "${astrea_root}/System/services/display_apply.sh" || failed=1
	bash -n "${astrea_root}/System/services/display_night_shift_color.sh" || failed=1
	bash -n "${astrea_root}/System/services/display_night_shift_schedule.sh" || failed=1
	python3 -m py_compile "${astrea_root}/System/services/astrea_notify.py" || failed=1

	if [[ -f "${status_backend_dir}/Cargo.toml" ]]; then
		if command -v cargo >/dev/null 2>&1; then
			cargo check --manifest-path "${status_backend_dir}/Cargo.toml" --offline || failed=1
		else
			warn 'missing dependency for status backend verification: cargo'
			failed=1
		fi
	else
		warn "missing status backend manifest: ${status_backend_dir}/Cargo.toml"
		failed=1
	fi

	if [[ ! -x "${astrea_bin_dir}/astrea-statusd" ]]; then
		printf 'missing executable: %s\n' "${astrea_bin_dir}/astrea-statusd" >&2
		failed=1
	fi

	if [[ -f "${latency_backend_dir}/Cargo.toml" ]]; then
		if command -v cargo >/dev/null 2>&1; then
			cargo check --manifest-path "${latency_backend_dir}/Cargo.toml" --offline || failed=1
		else
			warn 'missing dependency for latency backend verification: cargo'
			failed=1
		fi
	else
		warn "missing latency backend manifest: ${latency_backend_dir}/Cargo.toml"
		failed=1
	fi

	if [[ ! -x "${astrea_bin_dir}/astrea-latencyd" ]]; then
		printf 'missing executable: %s\n' "${astrea_bin_dir}/astrea-latencyd" >&2
		failed=1
	fi

	if [[ -f "${launch_backend_dir}/Cargo.toml" ]]; then
		if command -v cargo >/dev/null 2>&1; then
			cargo check --manifest-path "${launch_backend_dir}/Cargo.toml" --offline || failed=1
		else
			warn 'missing dependency for launch backend verification: cargo'
			failed=1
		fi
	else
		warn "missing launch backend manifest: ${launch_backend_dir}/Cargo.toml"
		failed=1
	fi

	if [[ ! -x "${astrea_bin_dir}/astrea-launch" ]]; then
		printf 'missing executable: %s\n' "${astrea_bin_dir}/astrea-launch" >&2
		failed=1
	fi

	if [[ "${failed}" -eq 0 ]]; then
		info 'Astrea core services verified'
	fi
	return "${failed}"
}

verify_weather_services() {
	local failed=0
	local units=("${unit_dir}/astrea-weatherd.service")

	verify_paths "${units[@]}" || failed=1
	verify_systemd_units "${units[@]}" || failed=1

	if [[ -f "${weather_backend_dir}/Cargo.toml" ]]; then
		if command -v cargo >/dev/null 2>&1; then
			cargo check --manifest-path "${weather_backend_dir}/Cargo.toml" --workspace --offline || failed=1
		else
			warn 'missing dependency for weather backend verification: cargo'
			failed=1
		fi
	else
		warn "missing weather backend manifest: ${weather_backend_dir}/Cargo.toml"
		failed=1
	fi

	if [[ ! -x "${astrea_bin_dir}/weather-cli" ]]; then
		printf 'missing executable: %s\n' "${astrea_bin_dir}/weather-cli" >&2
		failed=1
	fi
	if [[ ! -x "${astrea_bin_dir}/astrea-weatherd" ]]; then
		printf 'missing executable: %s\n' "${astrea_bin_dir}/astrea-weatherd" >&2
		failed=1
	fi

	if [[ "${failed}" -eq 0 ]]; then
		info 'Astrea weather services verified'
	fi
	return "${failed}"
}

verify_portal_services() {
	local failed=0
	local units=("${unit_dir}/astrea-filechooser-portal.service")
	local files=(
		"${unit_dir}/astrea-filechooser-portal.service"
		"${dbus_dir}/org.freedesktop.impl.portal.desktop.astrea.service"
		"${portal_dir}/astrea.portal"
		"${xdg_portal_conf_dir}/portals.conf"
	)

	verify_paths "${files[@]}" || failed=1
	verify_systemd_units "${units[@]}" || failed=1
	if [[ -f "${portal_backend_dir}/Cargo.toml" ]]; then
		if command -v cargo >/dev/null 2>&1; then
			cargo check --manifest-path "${portal_backend_dir}/Cargo.toml" --offline || failed=1
		else
			warn 'missing dependency for portal backend verification: cargo'
			failed=1
		fi
	else
		warn "missing portal backend manifest: ${portal_backend_dir}/Cargo.toml"
		failed=1
	fi
	if [[ ! -x "${astrea_bin_dir}/astrea-filechooser-portal" ]]; then
		printf 'missing executable: %s\n' "${astrea_bin_dir}/astrea-filechooser-portal" >&2
		failed=1
	fi

	if [[ "${failed}" -eq 0 ]]; then
		info 'Astrea portal services verified'
	fi
	return "${failed}"
}

verify_services() {
	local scope="${1:-core}"
	case "${scope}" in
	core)
		verify_core_services
		;;
	weather)
		verify_weather_services
		;;
	portal)
		verify_portal_services
		;;
	all)
		local failed=0
		verify_core_services || failed=1
		verify_weather_services || failed=1
		verify_portal_services || failed=1
		return "${failed}"
		;;
	*)
		printf 'Usage: %s verify [core|weather|portal|all]\n' "$0" >&2
		return 2
		;;
	esac
}

case "${1:-verify}" in
install)
	install_services
	;;
verify | doctor)
	verify_services "${2:-core}"
	;;
reload)
	reload_user_systemd
	;;
*)
	printf 'Usage: %s [install|verify [core|weather|portal|all]|doctor [core|weather|portal|all]|reload]\n' "$0" >&2
	exit 2
	;;
esac
