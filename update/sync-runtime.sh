#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${ASTREA_REPO_URL:-git@github.com:agonyG4/AstreaOS.git}"
MODE="stable"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [--stable|--rolling]

  --stable   sync ~/GitHub/Astrea-Stable into ~/.local/share/Astrea-Stable and activate it
  --rolling  sync ~/GitHub/Astrea-Dev into ~/.local/share/Astrea-Rolling and activate it
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stable)
            MODE="stable"
            ;;
        --rolling)
            MODE="rolling"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "Unknown argument: $1"
            ;;
    esac
    shift
done

ACTIVE_ROOT="${HOME}/.local/share/Astrea"

case "${MODE}" in
    stable)
        REPO_DIR="${ASTREA_STABLE_DIR:-$HOME/GitHub/Astrea-Stable}"
        RUNTIME_ROOT="${HOME}/.local/share/Astrea-Stable"
        ;;
    rolling)
        REPO_DIR="${ASTREA_DEV_DIR:-$HOME/GitHub/Astrea-Dev}"
        RUNTIME_ROOT="${HOME}/.local/share/Astrea-Rolling"
        ;;
    *)
        die "Unsupported mode: ${MODE}"
        ;;
esac

repo_dirty() {
    [[ -n "$(git -C "${REPO_DIR}" status --porcelain)" ]]
}

ensure_repo() {
    case "${MODE}" in
        stable)
            if [[ ! -d "${REPO_DIR}" ]]; then
                info "Cloning Stable repo into ${REPO_DIR}"
                git clone --branch Stable "${REPO_URL}" "${REPO_DIR}"
            fi
            ;;
        rolling)
            [[ -d "${REPO_DIR}" ]] || die "Rolling repo does not exist: ${REPO_DIR}"
            ;;
    esac

    [[ -d "${REPO_DIR}" ]] || die "Repo does not exist: ${REPO_DIR}"
    [[ -d "${REPO_DIR}/.git" ]] || die "Repo does not contain .git: ${REPO_DIR}"
    [[ -d "${REPO_DIR}/src" ]] || die "Repo does not contain src/: ${REPO_DIR}/src"
}

update_repo() {
    case "${MODE}" in
        stable)
            if repo_dirty; then
                die "Stable repo is dirty. Refusing to pull: ${REPO_DIR}"
            fi
            info "Updating Stable with git pull --ff-only"
            git -C "${REPO_DIR}" checkout Stable
            git -C "${REPO_DIR}" pull --ff-only
            ;;
        rolling)
            if repo_dirty; then
                warn "Rolling repo is dirty; not checking out or pulling. Syncing current src/ as-is."
                return
            fi
            if git -C "${REPO_DIR}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
                info "Updating rolling branch with git pull --ff-only"
                git -C "${REPO_DIR}" pull --ff-only
            else
                warn "Rolling branch has no upstream; syncing current src/ as-is."
            fi
            ;;
    esac
}

migrate_legacy_active_dir() {
    if [[ -L "${ACTIVE_ROOT}" ]]; then
        return
    fi

    if [[ ! -e "${ACTIVE_ROOT}" ]]; then
        return
    fi

    [[ -d "${ACTIVE_ROOT}" ]] || die "Active runtime exists but is not a directory or symlink: ${ACTIVE_ROOT}"

    if [[ ! -e "${RUNTIME_ROOT}" ]]; then
        info "Migrating existing ${ACTIVE_ROOT} directory to ${RUNTIME_ROOT}"
        mv "${ACTIVE_ROOT}" "${RUNTIME_ROOT}"
        return
    fi

    if [[ -z "$(find "${RUNTIME_ROOT}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        info "Replacing empty ${RUNTIME_ROOT} with existing ${ACTIVE_ROOT}"
        rmdir "${RUNTIME_ROOT}"
        mv "${ACTIVE_ROOT}" "${RUNTIME_ROOT}"
        return
    fi

    local backup
    backup="${ACTIVE_ROOT}.pre-channel-migration.$(date +%Y%m%d-%H%M%S)"
    warn "Moving legacy active runtime aside: ${backup}"
    mv "${ACTIVE_ROOT}" "${backup}"
}

ensure_safe_target() {
    local resolved_root resolved_home stable_root rolling_root
    resolved_root="$(realpath -m "${RUNTIME_ROOT}")"
    resolved_home="$(realpath -m "${HOME}")"
    stable_root="$(realpath -m "${HOME}/.local/share/Astrea-Stable")"
    rolling_root="$(realpath -m "${HOME}/.local/share/Astrea-Rolling")"

    if [[ "${resolved_root}" == "/" || "${resolved_root}" == "${resolved_home}" ]]; then
        die "Refusing to sync into unsafe runtime target: ${resolved_root}"
    fi

    if [[ "${resolved_root}" != "${stable_root}" && "${resolved_root}" != "${rolling_root}" ]]; then
        die "Refusing to sync into non-channel runtime target: ${resolved_root}"
    fi

    mkdir -p "${RUNTIME_ROOT}"

    if [[ -z "$(find "${RUNTIME_ROOT}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        printf 'Astrea runtime channel: %s\n' "${MODE}" > "${RUNTIME_ROOT}/.astrea-runtime-channel"
    fi

    [[ -n "$(find "${RUNTIME_ROOT}" -mindepth 1 -maxdepth 1 -print -quit)" ]] || die "Target runtime dir is empty: ${RUNTIME_ROOT}"
}

activate_runtime() {
    [[ -d "${RUNTIME_ROOT}" ]] || die "Cannot activate missing runtime: ${RUNTIME_ROOT}"
    ln -sfn "${RUNTIME_ROOT}" "${ACTIVE_ROOT}"
    [[ -L "${ACTIVE_ROOT}" ]] || die "Failed to make active runtime a symlink: ${ACTIVE_ROOT}"
    info "Active runtime: ${ACTIVE_ROOT} -> $(readlink "${ACTIVE_ROOT}")"
}

install_weather_binaries() {
    local weather_backend_dir weather_bin_dir cargo_target_dir
    weather_backend_dir="${RUNTIME_ROOT}/Apps/Weather/backend"
    weather_bin_dir="${RUNTIME_ROOT}/bin"
    cargo_target_dir="${HOME}/.cache/AstreaOS/weather-${MODE}-target"

    if [[ ! -f "${weather_backend_dir}/Cargo.toml" ]]; then
        warn "Weather backend manifest not found; skipping weather binary install: ${weather_backend_dir}/Cargo.toml"
        return 0
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        warn "cargo not found; skipping weather binary install"
        return 0
    fi

    info "Building weather binaries for ${MODE}"
    CARGO_TARGET_DIR="${cargo_target_dir}" cargo build --manifest-path "${weather_backend_dir}/Cargo.toml" --workspace --release

    [[ -x "${cargo_target_dir}/release/weather-cli" ]] || die "weather-cli build output is missing"
    [[ -x "${cargo_target_dir}/release/astrea-weatherd" ]] || die "astrea-weatherd build output is missing"

    install -Dm755 "${cargo_target_dir}/release/weather-cli" "${weather_bin_dir}/weather-cli"
    install -Dm755 "${cargo_target_dir}/release/astrea-weatherd" "${weather_bin_dir}/astrea-weatherd"
}

ensure_runtime_dirs() {
    mkdir -p "${RUNTIME_ROOT}/Wallpapers"
}

mkdir -p "${HOME}/.local/share"

ensure_repo
update_repo
migrate_legacy_active_dir
ensure_safe_target

mkdir -p \
    "${HOME}/.config/AstreaOS" \
    "${HOME}/.cache/AstreaOS" \
    "${HOME}/.local/state/AstreaOS"

info "Syncing ${MODE}: ${REPO_DIR}/src/ -> ${RUNTIME_ROOT}/"
rsync -a --delete "${REPO_DIR}/src/" "${RUNTIME_ROOT}/"
ensure_runtime_dirs
install_weather_binaries
activate_runtime
info "Runtime sync complete: ${RUNTIME_ROOT}"
