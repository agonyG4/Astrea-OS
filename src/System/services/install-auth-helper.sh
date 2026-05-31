#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
astrea_root="$(realpath -- "$script_dir/../..")"
source_path="$astrea_root/System/auth/auth_helper.c"
target_path="/usr/local/libexec/astrea-auth-helper"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

cc -Wall -Wextra -Werror -O2 -o "$build_dir/astrea-auth-helper" "$source_path" -lpam
sudo install -o root -g root -m 755 -D -- "$build_dir/astrea-auth-helper" "$target_path"

printf 'Installed %s\n' "$target_path"
