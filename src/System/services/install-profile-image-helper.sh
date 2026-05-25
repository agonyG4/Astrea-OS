#!/usr/bin/env bash

set -euo pipefail

helper_path="/usr/local/bin/astrea-set-profile-image"
sudoers_path="/etc/sudoers.d/astrea-profile-image"
tmp_helper="$(mktemp)"
tmp_sudoers="$(mktemp)"
trap 'rm -f "$tmp_helper" "$tmp_sudoers"' EXIT

target_user="${SUDO_USER:-${USER:-}}"
if [[ -z "$target_user" || "$target_user" == "root" ]]; then
	target_user="$(logname 2>/dev/null || true)"
fi
if [[ -z "$target_user" || "$target_user" == "root" ]]; then
	printf 'Could not determine the desktop user for the sudoers rule.\n' >&2
	exit 1
fi

cat >"$tmp_helper" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

fail_usage() {
    printf 'Invalid profile image helper request: %s\n' "${1:-validation failed}" >&2
    exit 64
}

src="${1:?missing source image}"
user_name="${2:?missing username}"
user_id="${3:?missing user id}"
home_dir="${4:?missing home dir}"

case "$user_name" in
    ""|*/*|*[!A-Za-z0-9_.-]*)
        fail_usage "invalid username"
        ;;
esac

case "$user_id" in
    ""|*[!0-9]*)
        fail_usage "invalid user id"
        ;;
esac

passwd_entry="$(getent passwd "$user_name" || true)"
[[ -n "$passwd_entry" ]] || fail_usage "unknown user"
IFS=: read -r _ _ passwd_uid _ _ passwd_home _ <<<"$passwd_entry"
[[ "$passwd_uid" == "$user_id" ]] || fail_usage "user id mismatch"

home_real="$(realpath -m -- "$home_dir")"
passwd_home_real="$(realpath -m -- "$passwd_home")"
[[ "$home_real" == "$passwd_home_real" ]] || fail_usage "home mismatch"

src_real="$(realpath -- "$src" 2>/dev/null || true)"
[[ -n "$src_real" && -f "$src_real" && ! -L "$src" ]] || fail_usage "invalid source image"
case "$src_real" in
    "$home_real"/*)
        ;;
    *)
        fail_usage "source outside user home"
        ;;
esac

dest="/var/lib/AccountsService/icons/${user_name}"
face_icon="${home_real}/.face.icon"
user_obj="/org/freedesktop/Accounts/User${user_id}"

install -Dm644 -- "$src_real" "$dest"
install -Dm644 -- "$src_real" "$face_icon"
chown "$user_id:$user_id" "$face_icon"

if command -v dbus-send >/dev/null 2>&1; then
    dbus-send --system --dest=org.freedesktop.Accounts --type=method_call \
        "$user_obj" org.freedesktop.Accounts.User.SetIconFile \
        string:"$dest" >/dev/null 2>&1 || true
fi
EOF

cat >"$tmp_sudoers" <<EOF
$target_user ALL=(root) NOPASSWD: $helper_path
EOF

chmod 755 "$tmp_helper"
chmod 440 "$tmp_sudoers"

sudo install -o root -g root -m 755 "$tmp_helper" "$helper_path"
sudo install -o root -g root -m 440 "$tmp_sudoers" "$sudoers_path"
sudo visudo -cf "$sudoers_path"

printf 'Installed %s and %s\n' "$helper_path" "$sudoers_path"
printf 'Granted passwordless access to %s for %s\n' "$target_user" "$helper_path"
