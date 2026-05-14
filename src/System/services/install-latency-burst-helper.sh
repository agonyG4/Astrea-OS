#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
	user_name="${SUDO_USER}"
else
	user_name="$(id -un "${SUDO_UID:-${UID}}" 2>/dev/null || id -un)"
fi
user_home="$(getent passwd "${user_name}" | cut -d: -f6)"
if [[ -z "${user_home}" ]]; then
	printf 'Unable to determine home directory for %s. Set ASTREA_ROOT explicitly.\n' "${user_name}" >&2
	exit 1
fi
astrea_root="${ASTREA_ROOT:-${user_home}/.local/share/Astrea}"
source_helper="${astrea_root}/System/services/astrea-latency-burst-helper"
target_helper="/usr/local/libexec/astrea-latency-burst-helper"
sudoers_file="/etc/sudoers.d/astrea-latency-burst"

if [[ "${EUID}" -ne 0 ]]; then
	printf 'This installer must run as root.\n' >&2
	exit 1
fi

if [[ ! -f "${source_helper}" ]]; then
	printf 'Missing latency helper source: %s\n' "${source_helper}" >&2
	exit 1
fi
if [[ ! -x "${source_helper}" ]]; then
	printf 'Latency helper source is not executable: %s\n' "${source_helper}" >&2
	exit 1
fi

install -Dm755 "${source_helper}" "${target_helper}"
printf '%s ALL=(root) NOPASSWD: %s\n' "${user_name}" "${target_helper}" >"${sudoers_file}.tmp"
chmod 0440 "${sudoers_file}.tmp"
if ! visudo -cf "${sudoers_file}.tmp" >/dev/null; then
	rm -f "${sudoers_file}.tmp"
	printf 'Refusing to install invalid sudoers file for %s.\n' "${target_helper}" >&2
	exit 1
fi
install -Dm440 "${sudoers_file}.tmp" "${sudoers_file}"
rm -f "${sudoers_file}.tmp"

printf 'Installed %s\n' "${target_helper}"
printf 'Installed %s\n' "${sudoers_file}"
