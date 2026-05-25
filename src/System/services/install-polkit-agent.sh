#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
service_src="$script_dir/astrea-polkit-agent.service"
service_dst="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/astrea-polkit-agent.service"

install -Dm644 -- "$service_src" "$service_dst"
systemctl --user daemon-reload
systemctl --user disable --now hyprpolkitagent.service >/dev/null 2>&1 || true
systemctl --user enable astrea-polkit-agent.service >/dev/null
systemctl --user restart astrea-polkit-agent.service
printf 'Astrea polkit agent installed and started.\n'
