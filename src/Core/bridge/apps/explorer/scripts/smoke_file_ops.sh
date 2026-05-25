#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="${EXPLORER_BACKEND_BIN:-${repo_dir}/target/debug/explorer_backend}"

if [[ ! -x "${bin}" ]]; then
    cargo build --manifest-path "${repo_dir}/Cargo.toml" >/dev/null
fi

tmp="$(mktemp -d -p "${TMPDIR:-/workspace}")"
chmod 755 "${tmp}"
cleanup() {
    if [[ -n "${src_parent:-}" && -d "${src_parent}" ]]; then
        chmod 755 "${src_parent}" 2>/dev/null || true
        rm -rf "${src_parent}" 2>/dev/null || true
    fi
    rm -rf "${tmp}"
}
trap cleanup EXIT

mkdir -p "${tmp}/list" "${tmp}/dest|pipe" "${tmp}/srcdir/sub"
printf 'alpha' > "${tmp}/list/alpha.txt"
printf 'beta' > "${tmp}/list/beta.txt"
printf 'new' > "${tmp}/source.txt"
printf 'nested' > "${tmp}/srcdir/sub/nested.txt"

"${bin}" list "${tmp}/list" 1 name 1 1 | grep -q 'alpha.txt'
"${bin}" search "${tmp}/list" beta 1 name 1 1 | grep -q 'beta.txt'

"${bin}" file-op copy "${tmp}/dest|pipe" overwrite '' "${tmp}/source.txt" | tee "${tmp}/copy_pipe.out"
awk -F'|' '/^START/ { if (NF != 4) exit 1 } /^PROGRESS/ { if (NF != 5) exit 1 } /^DONE/ { if (NF != 4) exit 1 }' "${tmp}/copy_pipe.out"
! grep -q 'dest|pipe' "${tmp}/copy_pipe.out"
test -f "${tmp}/dest|pipe/source.txt"

"${bin}" file-op copy "${tmp}/dest|pipe" keep-both '' "${tmp}/source.txt"
test -f "${tmp}/dest|pipe/source 2.txt"

"${bin}" file-op copy "${tmp}/dest|pipe" rename '' "${tmp}/source.txt" >"${tmp}/rename_empty.out" 2>"${tmp}/rename_empty.err" && exit 1 || true
grep -q 'rename conflict policy requires exactly one source' "${tmp}/rename_empty.err"
printf second > "${tmp}/source2.txt"
"${bin}" file-op copy "${tmp}/dest|pipe" rename renamed.txt "${tmp}/source.txt" "${tmp}/source2.txt" >"${tmp}/rename_multi.out" 2>"${tmp}/rename_multi.err" && exit 1 || true
grep -q 'rename conflict policy requires exactly one source' "${tmp}/rename_multi.err"

printf keep > "${tmp}/dest|pipe/missing.txt"
"${bin}" file-op copy "${tmp}/dest|pipe" overwrite '' "${tmp}/missing.txt" >"${tmp}/overwrite_missing.out" 2>"${tmp}/overwrite_missing.err" && exit 1 || true
test "$(cat "${tmp}/dest|pipe/missing.txt")" = keep

"${bin}" file-op copy "${tmp}/srcdir/sub" keep-both '' "${tmp}/srcdir" >"${tmp}/self.out" 2>"${tmp}/self.err" && exit 1 || true
grep -q 'ERROR|refusing to copy directory into itself' "${tmp}/self.out"

"${bin}" install-appimage "${tmp}/source.txt" >"${tmp}/appimage.out" 2>"${tmp}/appimage.err" && exit 1 || true
grep -q 'selected file is not an AppImage' "${tmp}/appimage.err"

src_parent="/dev/shm/astrea-move-src-$$"
mkdir -p "${src_parent}" "${tmp}/nobody-dest"
printf partial > "${src_parent}/source.txt"
chmod 555 "${src_parent}"
chmod 644 "${src_parent}/source.txt"
if chown -R root:root "${src_parent}" 2>/dev/null && chown nobody:nogroup "${tmp}/nobody-dest" 2>/dev/null; then
    runuser -u nobody -- "${bin}" file-op move "${tmp}/nobody-dest" keep-both '' "${src_parent}/source.txt" >"${tmp}/move_partial.out" 2>"${tmp}/move_partial.err" && exit 1 || true
    grep -Eq 'ERROR\\|move (partially completed|failed after copy)' "${tmp}/move_partial.out"
    test -f "${tmp}/nobody-dest/source.txt"
    test -f "${src_parent}/source.txt"
else
    echo "Skipping permission-owner partial-move check on this filesystem"
fi

echo "Explorer backend smoke tests passed"
