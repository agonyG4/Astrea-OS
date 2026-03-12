#!/bin/bash
# Astrea Shell — instalador de dependências e dotfiles
# Rode: bash install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="/home/$USER"

echo "==> Usuário detectado: $USER"
echo "==> Diretório base: $SCRIPT_DIR"

# ── Dependências de build ─────────────────────────────────
echo "==> Instalando dependências de build..."
sudo pacman -S --needed --noconfirm git base-devel

# ── yay ───────────────────────────────────────────────────
echo "==> Clonando o yay em ./aur/yay..."
mkdir -p "$SCRIPT_DIR/aur"
cd "$SCRIPT_DIR/aur"

if [ ! -d "yay" ]; then
  git clone https://aur.archlinux.org/yay.git
else
  echo "    Pasta yay já existe, pulando clone."
fi

cd yay
makepkg -si --noconfirm
cd "$SCRIPT_DIR"

# ── Pacotes do sistema ────────────────────────────────────
echo "==> Instalando dependências do sistema..."
sudo pacman -S --needed --noconfirm \
  python \
  python-pip \
  python-numpy \
  python-pillow \
  bash \
  curl \
  grep \
  sed \
  gawk \
  coreutils \
  iproute2 \
  networkmanager \
  bluez \
  bluez-utils \
  wireplumber \
  rofi-wayland \
  wlogout \
  hyprlock \
  gamemode \
  inter-font \
  ttf-jetbrains-mono-nerd \
  swaync \
  dolphin \
  ark \
  kde-cli-tools \
  ffmpegthumbs \
  kdegraphics-thumbnailers

# ── Pacotes do AUR ────────────────────────────────────────
echo "==> Instalando pacotes do AUR..."
yay -S --needed --noconfirm \
  quickshell-git \
  hyprpolkitagent \
  swww

# ── Deploy das pastas ─────────────────────────────────────
echo "==> Copiando arquivos..."

# Astrea → /opt/Astrea
if [ -d "$SCRIPT_DIR/Astrea" ]; then
  sudo mkdir -p /opt/Astrea
  sudo cp -r "$SCRIPT_DIR/Astrea/." /opt/Astrea/
  sudo chown -R "$USER":"$USER" /opt/Astrea
  echo "    Astrea → /opt/Astrea"
fi

# config → ~/.config
if [ -d "$SCRIPT_DIR/config" ]; then
  mkdir -p "$USER_HOME/.config"
  cp -r "$SCRIPT_DIR/config/." "$USER_HOME/.config/"
  echo "    config → $USER_HOME/.config"
fi

# services → ~/.config/systemd/user (serviços do usuário)
#           + reload do systemd
if [ -d "$SCRIPT_DIR/services" ]; then
  mkdir -p "$USER_HOME/.config/systemd/user"
  cp -r "$SCRIPT_DIR/services/." "$USER_HOME/.config/systemd/user/"
  systemctl --user daemon-reload
  echo "    services → $USER_HOME/.config/systemd/user"
fi

echo ""
echo "==> AstreaOS v1.2 Instalado."
echo "    Reinicia o Hyprland ou loga de novo pra aplicar tudo."