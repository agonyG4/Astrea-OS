#!/bin/bash
# =============================================================
# install.sh — Astrea-OS
# Inspirado em: macOS + Fedora + CachyOS + Windows
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { echo -e "${BLUE}[INFO]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
sep()   { echo -e "${BOLD}────────────────────────────────${RESET}"; }
ask()   { echo -e "${YELLOW}[?]${RESET}     $*"; }

sep
echo -e "${BOLD}  Astrea-OS — Instalador${RESET}"
sep

# ─── Verificar root ──────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}[ERRO]${RESET} Não rode como root. Use seu usuário normal."
    exit 1
fi

# ─── Pacman parallel downloads ───────────────────────────────
sudo sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# ─── Instalar paru se não tiver ──────────────────────────────
if ! command -v paru &>/dev/null; then
    info "Instalando paru (AUR helper)..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru && makepkg -si --noconfirm
    cd ~ && rm -rf /tmp/paru
fi

# ─── Core do sistema ─────────────────────────────────────────
sep; info "Instalando core do sistema..."
paru -S --needed --noconfirm \
    base base-devel \
    linux-firmware \
    networkmanager iwd \
    bluez bluez-utils \
    pipewire pipewire-alsa pipewire-jack pipewire-pulse \
    wireplumber \
    sddm \
    uwsm \
    polkit \
    dbus-broker \
    sudo \
    systemd \
    efibootmgr \
    zram-generator
ok "Core instalado."

# ─── Hyprland + Wayland ──────────────────────────────────────
sep; info "Instalando Hyprland..."
paru -S --needed --noconfirm \
    hyprland \
    hyprlock \
    hyprpolkitagent \
    hyprsunset \
    hyprshot \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    xorg-xwayland \
    qt5-wayland \
    qt6-wayland \
    layer-shell-qt \
    gtk4-layer-shell
ok "Hyprland instalado."

# ─── Shell + Terminal ─────────────────────────────────────────
sep; info "Instalando shell e terminal..."
paru -S --needed --noconfirm \
    kitty \
    nano \
    less \
    wget \
    git \
    rsync \
    unzip \
    7zip \
    btop \
    fastfetch \
    ripgrep
ok "Shell e terminal instalados."

# ─── UI / Bar / Launcher ─────────────────────────────────────
sep; info "Instalando UI..."
paru -S --needed --noconfirm \
    quickshell-git \
    rofi \
    swaync \
    swww \
    cava \
    pavucontrol \
    playerctl \
    ddcutil \
    wl-clipboard \
    grim \
    grimblast-git \
    slurp \
    satty \
    imagemagick \
    python-pillow \
    python-numpy
ok "UI instalada."

# ─── Tema visual ─────────────────────────────────────────────
sep; info "Instalando tema visual..."
paru -S --needed --noconfirm \
    adw-gtk-theme \
    kvantum \
    nwg-look \
    qt6ct-kde \
    inter-font \
    ttf-jetbrains-mono-nerd \
    ttf-nerd-fonts-symbols \
    ttf-apple-emoji \
    ttf-google-fonts-typewolf \
    ttf-liberation \
    noto-fonts \
    noto-fonts-cjk
ok "Tema visual instalado."

# ─── Apps essenciais ─────────────────────────────────────────
sep; info "Instalando apps essenciais..."
paru -S --needed --noconfirm \
    firefox \
    dolphin \
    ark \
    loupe \
    vlc \
    easyeffects \
    flatpak \
    pacman-contrib \
    openssh \
    xdg-utils \
    xdg-user-dirs
ok "Apps essenciais instalados."

# ─── Opcional: Gaming ────────────────────────────────────────
sep
ask "Instalar pacotes de gaming? (steam, lutris, wine, gamemode) [s/N]"
read -r resp
if [[ "$resp" =~ ^[sS]$ ]]; then
    paru -S --needed --noconfirm \
        steam \
        lutris \
        wine-staging \
        winetricks \
        gamemode \
        lib32-gamemode \
        gamescope \
        protontricks \
        mangohud
    ok "Gaming instalado."
fi

# ─── Ativar serviços ─────────────────────────────────────────
sep; info "Ativando serviços..."
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sddm
sudo systemctl enable iwd
ok "Serviços ativados."

# ─── Rodar updater do Astrea-OS ──────────────────────────────
sep
ask "Rodar o updater do Astrea-OS agora? [s/N]"
read -r resp
if [[ "$resp" =~ ^[sS]$ ]]; then
    SCRIPT_DIR="$(dirname "$(realpath "$0")")"
    if [[ -f "$SCRIPT_DIR/updater.sh" ]]; then
        sudo bash "$SCRIPT_DIR/updater.sh"
    else
        warn "updater.sh não encontrado na mesma pasta."
    fi
fi

sep
ok "Astrea-OS instalado! Reinicie o sistema."
sep