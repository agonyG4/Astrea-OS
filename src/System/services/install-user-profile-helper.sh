#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_path="$(realpath -- "$script_dir/../../Core/bridge/system/user_profile.py")"
helper_path="/usr/local/libexec/astrea-user-profile-helper"

sudo install -o root -g root -m 755 -D -- "$source_path" "$helper_path"
printf 'Installed %s\n' "$helper_path"
