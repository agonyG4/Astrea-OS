#!/usr/bin/env bash
set -euo pipefail

home="${HOME:-/home/agony}"
astrea_root="${home}/.local/share/Astrea"
unit_dir="${home}/.config/systemd/user"
dbus_dir="${home}/.local/share/dbus-1/services"
portal_dir="${home}/.local/share/xdg-desktop-portal/portals"
xdg_portal_conf_dir="${home}/.config/xdg-desktop-portal"

write_file_if_changed() {
    local path="$1"
    local mode="$2"
    local tmp
    tmp="$(mktemp)"
    cat > "${tmp}"
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

    write_file_if_changed "${unit_dir}/bench-filechooser-portal.service" 0644 <<EOF
[Unit]
Description=Bench Explorer FileChooser Portal Backend
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=5

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
Environment=XDG_CURRENT_DESKTOP=Hyprland
ExecStart=/usr/bin/python3 /home/agony/GitHub/Bench/portal/bench_filechooser_portal.py
Restart=on-failure
RestartSec=2
TimeoutStopSec=3
KillMode=mixed

[Install]
WantedBy=default.target
EOF

    write_file_if_changed "${dbus_dir}/org.freedesktop.impl.portal.desktop.bench.service" 0644 <<EOF
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.bench
Exec=/usr/bin/python3 /home/agony/GitHub/Bench/portal/bench_filechooser_portal.py
EOF

    write_file_if_changed "${portal_dir}/bench.portal" 0644 <<EOF
[portal]
DBusName=org.freedesktop.impl.portal.desktop.bench
Interfaces=org.freedesktop.impl.portal.FileChooser;
UseIn=Hyprland;wlroots;sway;Wayfire;river;
EOF

    write_file_if_changed "${xdg_portal_conf_dir}/portals.conf" 0644 <<EOF
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=bench;gtk
EOF

    write_file_if_changed "${xdg_portal_conf_dir}/hyprland-portals.conf" 0644 <<EOF
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=bench;gtk
EOF
}

reload_user_systemd() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
}

install_services() {
    write_portal_files
    write_night_shift_units
    reload_user_systemd
}

verify_services() {
    local failed=0
    local paths=(
        "${unit_dir}/bench-filechooser-portal.service"
        "${unit_dir}/astrea-night-shift.service"
        "${unit_dir}/astrea-night-shift.timer"
        "${dbus_dir}/org.freedesktop.impl.portal.desktop.bench.service"
        "${portal_dir}/bench.portal"
        "${xdg_portal_conf_dir}/portals.conf"
    )

    for path in "${paths[@]}"; do
        if [[ ! -f "${path}" ]]; then
            printf 'missing: %s\n' "${path}" >&2
            failed=1
        fi
    done

    if command -v systemd-analyze >/dev/null 2>&1; then
        local verify_output
        if ! verify_output="$(systemd-analyze --user verify \
            "${unit_dir}/bench-filechooser-portal.service" \
            "${unit_dir}/astrea-night-shift.service" \
            "${unit_dir}/astrea-night-shift.timer" 2>&1)"; then
            if grep -Eq 'Operation not permitted|Failed to connect to (user|system) scope bus|SO_PASS' <<<"${verify_output}"; then
                printf 'systemd unit syntax check skipped: user manager unavailable in this context\n' >&2
            else
                printf '%s\n' "${verify_output}" >&2
                failed=1
            fi
        fi
    fi

    bash -n "${astrea_root}/System/services/display_apply.sh" || failed=1
    bash -n "${astrea_root}/System/services/display_night_shift_color.sh" || failed=1
    bash -n "${astrea_root}/System/services/display_night_shift_schedule.sh" || failed=1
    python3 -m py_compile /home/agony/GitHub/Bench/portal/bench_filechooser_portal.py || failed=1

    if [[ "${failed}" -eq 0 ]]; then
        printf 'Astrea services verified\n'
    fi
    return "${failed}"
}

case "${1:-verify}" in
    install)
        install_services
        ;;
    verify|doctor)
        verify_services
        ;;
    reload)
        reload_user_systemd
        ;;
    *)
        printf 'Usage: %s [install|verify|doctor|reload]\n' "$0" >&2
        exit 2
        ;;
esac
