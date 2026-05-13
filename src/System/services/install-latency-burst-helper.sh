#!/usr/bin/env bash
set -euo pipefail

user_name="${SUDO_USER:-agony}"
astrea_root="${ASTREA_ROOT:-/home/${user_name}/.local/share/Astrea}"
source_helper="${astrea_root}/System/services/astrea-latency-burst-helper"
target_helper="/usr/local/libexec/astrea-latency-burst-helper"
sudoers_file="/etc/sudoers.d/astrea-latency-burst"

if [[ "${EUID}" -ne 0 ]]; then
    printf 'This installer must run as root.\n' >&2
    exit 1
fi

install -Dm755 "${source_helper}" "${target_helper}"
printf '%s ALL=(root) NOPASSWD: %s\n' "${user_name}" "${target_helper}" > "${sudoers_file}.tmp"
chmod 0440 "${sudoers_file}.tmp"
visudo -cf "${sudoers_file}.tmp" >/dev/null
install -Dm440 "${sudoers_file}.tmp" "${sudoers_file}"
rm -f "${sudoers_file}.tmp"

printf 'Installed %s\n' "${target_helper}"
printf 'Installed %s\n' "${sudoers_file}"
