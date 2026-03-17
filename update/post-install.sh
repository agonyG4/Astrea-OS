#!/bin/bash
# =============================================================
# post-install.sh — Rodado após cada update
# Adapte as seções abaixo para o seu caso
# =============================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[POST]${RESET} $*"; }
info() { echo -e "${YELLOW}[POST]${RESET} $*"; }

# ─── 1. Recarregar serviços systemd ──────────────────────────
# Descomente se você instalou/atualizou um .service
#
# info "Recarregando systemd..."
# sudo systemctl daemon-reload
# sudo systemctl restart meuapp.service
# ok "Serviço reiniciado."

# ─── 2. Recarregar configurações sem reiniciar ────────────────
# Se seu app suporta SIGHUP para reload:
#
# info "Enviando SIGHUP para meuapp..."
# sudo pkill -HUP meuapp || true
# ok "Configurações recarregadas."

# ─── 3. Ajustar permissões específicas ───────────────────────
# Exemplo: garantir que um diretório de dados tem dono correto
#
# info "Ajustando permissões..."
# sudo chown -R "$USER:$USER" /opt/meuapp/data/
# sudo chmod 755 /usr/local/bin/meuapp
# ok "Permissões ajustadas."

# ─── 4. Criar diretórios que o app precisa ───────────────────
# Pastas de cache, logs, etc.
#
# info "Criando diretórios de runtime..."
# mkdir -p "$HOME/.cache/meuapp"
# mkdir -p "$HOME/.local/share/meuapp"
# ok "Diretórios criados."

# ─── 5. Migração de configuração (versões diferentes) ────────
# Se o formato de config mudou entre versões:
#
# CONFIG="$HOME/.config/meuapp/config.toml"
# if [[ -f "$CONFIG" ]] && ! grep -q "nova_chave" "$CONFIG"; then
#     info "Migrando configuração antiga..."
#     echo 'nova_chave = "valor_padrão"' >> "$CONFIG"
#     ok "Migração concluída."
# fi

# ─── 6. Atualizar symlinks ────────────────────────────────────
# Se quiser manter /usr/local/bin apontando para /opt:
#
# info "Atualizando symlink..."
# sudo ln -sf /opt/meuapp/bin/meuapp /usr/local/bin/meuapp
# ok "Symlink atualizado."

# ─── 7. Rodar comando pós-instalação do próprio app ──────────
# Alguns apps têm um comando de setup/migrate:
#
# info "Rodando migrações do app..."
# /opt/meuapp/meuapp --migrate
# ok "Migrações concluídas."

# ─── 8. Notificação desktop ───────────────────────────────────
# Notifica o usuário (requer libnotify)
#
# DISPLAY="${DISPLAY:-:0}" notify-send \
#     "App atualizado!" \
#     "Nova versão instalada com sucesso." \
#     --icon=software-update-available 2>/dev/null || true

info "Recarregando units do systemd..."
sudo systemctl daemon-reload
ok "systemd recarregado."

info "Ajustando permissões dos scripts..."
sudo chmod 755 /usr/local/bin/monitor_apply.sh 2>/dev/null || true
ok "Permissões ajustadas."

info "Ajustando permissões do tema SDDM..."
sudo chmod -R 644 /usr/share/sddm/themes/Borealis/
sudo chmod 755 /usr/share/sddm/themes/Borealis/
ok "Tema Borealis pronto."

echo ""
ok "Astrea-OS atualizado com sucesso!"
echo ""