#!/usr/bin/env bash

set -euo pipefail

helper_path="/usr/local/bin/astrea-set-profile-image"
sudoers_path="/etc/sudoers.d/astrea-profile-image"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_helper="$(realpath -- "$script_dir/astrea-set-profile-image-helper")"
tmp_sudoers="$(mktemp)"
trap 'rm -f "$tmp_sudoers"' EXIT

target_user="${SUDO_USER:-${USER:-}}"
if [[ -z "$target_user" || "$target_user" == "root" ]]; then
	target_user="$(logname 2>/dev/null || true)"
fi
if [[ -z "$target_user" || "$target_user" == "root" ]]; then
	printf 'Could not determine the desktop user for the sudoers rule.\n' >&2
	exit 1
fi

cat >"$tmp_sudoers" <<EOF
$target_user ALL=(root) NOPASSWD: $helper_path
EOF

chmod 440 "$tmp_sudoers"

sudo install -o root -g root -m 755 "$source_helper" "$helper_path"
sudo install -o root -g root -m 440 "$tmp_sudoers" "$sudoers_path"
sudo visudo -cf "$sudoers_path"

printf 'Installed %s and %s\n' "$helper_path" "$sudoers_path"
printf 'Granted passwordless access to %s for %s\n' "$target_user" "$helper_path"
