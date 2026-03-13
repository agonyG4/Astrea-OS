#!/bin/bash
# Astrea Shell — instalador de dependências e dotfiles
# Rode: bash install.sh

set -euo pipefail

# ── Cores ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN} ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW} !${RESET} $*"; }
die()     { echo -e "${RED}ERRO:${RESET} $*" >&2; exit 1; }

# ── Sanidade ─────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Não rode como root. O script usa sudo quando precisa."
[[ -z "${USER:-}" ]] && die "Variável \$USER não definida."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$HOME"

info "Usuário detectado: $USER"
info "Diretório base:    $SCRIPT_DIR"
echo

# ── Dependências de build ─────────────────────────────────
info "Instalando dependências de build..."
sudo pacman -S --needed --noconfirm git base-devel
success "git + base-devel prontos"

# ── yay ──────────────────────────────────────────────────
if command -v yay &>/dev/null; then
    warn "yay já instalado ($(yay --version | head -1)), pulando..."
else
    info "Instalando yay..."
    mkdir -p "$SCRIPT_DIR/aur"
    pushd "$SCRIPT_DIR/aur" > /dev/null

    if [[ ! -d "yay" ]]; then
        git clone https://aur.archlinux.org/yay.git
    else
        warn "Pasta yay já existe, pulando clone."
    fi

    cd yay
    makepkg -si --noconfirm
    popd > /dev/null
    success "yay instalado"
fi

# ── Pacotes do sistema ────────────────────────────────────
info "Instalando pacotes do sistema via pacman..."

PACMAN_PKGS=(
    # Python
    python python-pip python-numpy python-pillow
    # Shell utils
    bash curl grep sed gawk coreutils
    # Rede / BT / Áudio
    iproute2 networkmanager bluez bluez-utils wireplumber
    # Wayland / DE
    rofi-wayland wlogout hyprlock gamemode swaync
    # Fontes
    inter-font ttf-jetbrains-mono-nerd
    # Dolphin + extras
    dolphin ark kde-cli-tools ffmpegthumbs kdegraphics-thumbnailers
)

sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
success "Pacotes do sistema instalados"

# ── Pacotes do AUR ────────────────────────────────────────
info "Instalando pacotes do AUR via yay..."

AUR_PKGS=(
    quickshell-git
    hyprpolkitagent
    swww
)

yay -S --needed --noconfirm "${AUR_PKGS[@]}"
success "Pacotes AUR instalados"

# ── Função auxiliar de deploy ─────────────────────────────
# Uso: deploy_dir <origem> <destino> [sudo]
deploy_dir() {
    local src="$1"
    local dst="$2"
    local use_sudo="${3:-}"

    if [[ ! -d "$src" ]]; then
        warn "Pasta '$src' não encontrada, pulando."
        return
    fi

    if [[ -n "$use_sudo" ]]; then
        sudo mkdir -p "$dst"
        sudo cp -r "$src/." "$dst/"
        sudo chown -R "$USER":"$USER" "$dst"
    else
        mkdir -p "$dst"
        # rsync-style: não sobrescreve configs existentes sem avisar
        cp -rn "$src/." "$dst/" 2>/dev/null || true
        # arquivos que já existem ficam intactos; use --force se quiser sobrescrever
    fi

    success "$(basename "$src") → $dst"
}

# ── Deploy ────────────────────────────────────────────────
info "Copiando arquivos..."

deploy_dir "$SCRIPT_DIR/Astrea"   "/opt/Astrea"         sudo
deploy_dir "$SCRIPT_DIR/config"   "$USER_HOME/.config"
deploy_dir "$SCRIPT_DIR/scripts"  "$USER_HOME/.local/bin"  # bônus, se existir

# ── Serviços do usuário ───────────────────────────────────
if [[ -d "$SCRIPT_DIR/services" ]]; then
    mkdir -p "$USER_HOME/.config/systemd/user"
    cp -r "$SCRIPT_DIR/services/." "$USER_HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    success "services → $USER_HOME/.config/systemd/user (daemon recarregado)"
fi

# ── Fim ───────────────────────────────────────────────────
echo
echo -e "${GREEN}${BOLD}  AstreaOS v1.2 instalado com sucesso!${RESET}"
echo -e "  Reinicia o Hyprland ou faz logout/login pra aplicar tudo."
echo