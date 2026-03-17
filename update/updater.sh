#!/bin/bash
# =============================================================
# updater.sh — Auto-updater Astrea-OS via GitHub
# Uso: sudo bash ./updater.sh
#      sudo bash ./updater.sh --dry-run
#      sudo bash ./updater.sh --no-post
#      sudo bash ./updater.sh --fix-perms
# =============================================================

set -euo pipefail

# ─── Configuração ────────────────────────────────────────────
GITHUB_REPO="https://github.com/aritsuyu/Astrea-OS.git"
BRANCH="Alpha"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
MANIFEST="$SCRIPT_DIR/update-manifest.conf"
POST_INSTALL="$SCRIPT_DIR/post-install.sh"
TMPDIR_BASE="/root/astrea-updater-tmp"
LOG_FILE="/root/astrea-updater.log"
BACKUP_DIR="/root/astrea-backup-$(date +%Y%m%d_%H%M%S)"
VERSION_FILE="/opt/Astrea/.version"
# ─────────────────────────────────────────────────────────────

DRY_RUN=false
SKIP_POST=false
FIX_PERMS=false

for arg in "$@"; do
    case $arg in
        --dry-run)   DRY_RUN=true ;;
        --no-post)   SKIP_POST=true ;;
        --fix-perms) FIX_PERMS=true ;;
    esac
done

# ─── Cores e helpers ─────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()   { echo -e "${BLUE}[INFO]${RESET}    $*" | tee -a "$LOG_FILE"; }
ok()     { echo -e "${GREEN}[OK]${RESET}      $*" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET}    $*" | tee -a "$LOG_FILE"; }
error()  { echo -e "${RED}[ERRO]${RESET}    $*" | tee -a "$LOG_FILE"; }
dryrun() { echo -e "${YELLOW}[DRY-RUN]${RESET} $*"; }
sep()    { echo -e "${BOLD}────────────────────────────────${RESET}" | tee -a "$LOG_FILE"; }

# ─── Cleanup ao sair ─────────────────────────────────────────
cleanup() {
    [[ -d "$TMPDIR_BASE" ]] && rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

# ─── Verificar root ──────────────────────────────────────────
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED}[ERRO]${RESET} Execute com: sudo bash $0"
        exit 1
    fi
}

# ─── Verificar dependências ──────────────────────────────────
check_deps() {
    local missing=()
    for cmd in git curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Dependências faltando: ${missing[*]}"
        error "Instale com: sudo pacman -S ${missing[*]}"
        exit 1
    fi
}

# ─── Clonar repositório ──────────────────────────────────────
clone_repo() {
    info "Clonando $GITHUB_REPO (branch: $BRANCH)..."
    rm -rf "$TMPDIR_BASE"
    mkdir -p "$TMPDIR_BASE"

    if ! GIT_TERMINAL_PROMPT=0 git clone --depth=1 --branch "$BRANCH" \
        "$GITHUB_REPO" "$TMPDIR_BASE/repo" >> "$LOG_FILE" 2>&1; then
        error "Falha ao clonar o repositório."
        error "Verifique a URL e sua conexão com a internet."
        exit 1
    fi
    ok "Repositório clonado."
}

# ─── Verificar versão ────────────────────────────────────────
check_version() {
    local new_commit
    new_commit=$(git -C "$TMPDIR_BASE/repo" rev-parse --short HEAD)
    info "Commit mais recente: $new_commit"

    if [[ -f "$VERSION_FILE" ]]; then
        local current
        current=$(cat "$VERSION_FILE")
        if [[ "$current" == "$new_commit" ]]; then
            ok "Já está na versão mais recente ($current). Nada a fazer."
            exit 0
        fi
        info "Versão atual: $current → nova: $new_commit"
    else
        info "Primeira instalação detectada."
    fi

    echo "$new_commit" > "$TMPDIR_BASE/new_version"
}

# ─── Expandir variáveis de forma segura ──────────────────────
expand_vars() {
    local str="$1"
    str="${str//\$HOME/$REAL_HOME}"
    str="${str//\$USER/$REAL_USER}"
    echo "$str"
}

# ─── Aplicar permissões corretas num destino ─────────────────
apply_perms() {
    local dest="$1"
    local perm="$2"

    if [[ ! -e "$dest" ]]; then return; fi

    # Diretórios sempre 755
    find "$dest" -type d -exec chmod 755 {} \; 2>/dev/null || true

    # Arquivos com a permissão do manifesto
    if [[ "$perm" == "755" ]]; then
        find "$dest" -type f -exec chmod 755 {} \; 2>/dev/null || true
    else
        find "$dest" -type f -exec chmod 644 {} \; 2>/dev/null || true
        # Restaura +x em scripts e binários
        find "$dest" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod 755 {} \; 2>/dev/null || true
        find "$dest" -type f ! -name "*.*" -exec chmod 755 {} \; 2>/dev/null || true
    fi

    # Corrige dono se for home do usuário
    if [[ "$dest" == "$REAL_HOME"* ]]; then
        chown -R "$REAL_USER:$REAL_USER" "$dest" 2>/dev/null || true
    fi
}

# ─── Backup ──────────────────────────────────────────────────
backup_existing() {
    $DRY_RUN && return
    info "Criando backup em $BACKUP_DIR..."

    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        line=$(expand_vars "$line")
        read -r _src dest _rest <<< "$line"
        [[ -z "$dest" ]] && continue
        dest="${dest%/}"
        if [[ -e "$dest" ]]; then
            local bpath="$BACKUP_DIR$dest"
            mkdir -p "$(dirname "$bpath")"
            cp -a "$dest" "$bpath" 2>/dev/null || true
        fi
    done < "$MANIFEST"

    ok "Backup criado em $BACKUP_DIR"
}

# ─── Corrigir permissões de tudo no manifesto ────────────────
fix_perms() {
    sep
    info "Corrigindo permissões de todos os destinos do manifesto..."
    local count=0

    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        line=$(expand_vars "$line")
        read -r _src dest perm <<< "$line"
        [[ -z "$dest" ]] && continue
        perm="${perm:-644}"
        dest="${dest%/}"

        if [[ ! -e "$dest" ]]; then
            warn "Não existe no sistema, pulando: $dest"
            continue
        fi

        apply_perms "$dest" "$perm"
        ok "Permissões corrigidas: $dest"
        count=$((count + 1))
    done < "$MANIFEST"

    sep
    ok "Total corrigido: $count destinos."
}

# ─── Aplicar manifesto ───────────────────────────────────────
apply_manifest() {
    sep
    info "Aplicando arquivos..."

    local count=0
    local errors=0

    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        line=$(expand_vars "$line")
        read -r src dest perm <<< "$line"
        [[ -z "$src" || -z "$dest" ]] && continue
        perm="${perm:-644}"

        local full_src="$TMPDIR_BASE/repo/$src"

        if [[ ! -e "$full_src" ]]; then
            warn "Não encontrado, pulando: $src"
            continue
        fi

        if $DRY_RUN; then
            dryrun "Copiaria: $src → $dest  [perm: $perm]"
            count=$((count + 1))
            continue
        fi

        # Cria diretório de destino
        if [[ -d "$full_src" ]]; then
            mkdir -p "$dest"
        else
            mkdir -p "$(dirname "$dest")"
        fi

        # Copia
        if [[ -d "$full_src" ]]; then
            if cp -a "$full_src/." "$dest/"; then
                ok "Diretório: $src/ → $dest/"
            else
                error "Falha: $src"
                errors=$((errors + 1))
                continue
            fi
        else
            if cp -a "$full_src" "$dest"; then
                ok "Arquivo: $src → $dest"
            else
                error "Falha: $src"
                errors=$((errors + 1))
                continue
            fi
        fi

        apply_perms "$dest" "$perm"
        count=$((count + 1))

    done < "$MANIFEST"

    sep
    if $DRY_RUN; then
        dryrun "Total: $count item(s) seriam copiados."
    else
        ok "Copiados: $count | Erros: $errors"
        [[ $errors -gt 0 ]] && warn "Verifique $LOG_FILE para detalhes."
    fi
}

# ─── Salvar versão ───────────────────────────────────────────
save_version() {
    $DRY_RUN && return
    [[ ! -f "$TMPDIR_BASE/new_version" ]] && return
    mkdir -p "$(dirname "$VERSION_FILE")"
    cp "$TMPDIR_BASE/new_version" "$VERSION_FILE"
}

# ─── Post-install ────────────────────────────────────────────
run_post_install() {
    if $SKIP_POST; then
        info "Post-install pulado (--no-post)."
        return
    fi
    if [[ ! -f "$POST_INSTALL" ]]; then
        warn "post-install.sh não encontrado, pulando."
        return
    fi

    sep
    info "Rodando post-install..."
    if $DRY_RUN; then
        dryrun "Executaria: $POST_INSTALL"
        return
    fi

    if bash "$POST_INSTALL" 2>&1 | tee -a "$LOG_FILE"; then
        ok "Post-install concluído."
    else
        error "Post-install falhou! Verifique $LOG_FILE"
        exit 1
    fi
}

# ─── Main ────────────────────────────────────────────────────
main() {
    touch "$LOG_FILE"

    sep
    echo -e "${BOLD}  Astrea-OS Updater — $(date '+%d/%m/%Y %H:%M')${RESET}" | tee -a "$LOG_FILE"
    info "Usuário: $REAL_USER | Home: $REAL_HOME"
    $DRY_RUN    && echo -e "${YELLOW}  MODO DRY-RUN — nada será alterado${RESET}"
    $FIX_PERMS  && echo -e "${YELLOW}  MODO FIX-PERMS — só corrige permissões${RESET}"
    sep

    check_root

    if [[ ! -f "$MANIFEST" ]]; then
        error "Manifesto não encontrado: $MANIFEST"
        exit 1
    fi

    # Modo --fix-perms: só corrige permissões, sem clonar
    if $FIX_PERMS; then
        fix_perms
        sep
        ok "Permissões corrigidas! Log em: $LOG_FILE"
        sep
        exit 0
    fi

    check_deps
    clone_repo
    check_version
    backup_existing
    apply_manifest
    save_version
    run_post_install

    sep
    ok "Concluído! Log em: $LOG_FILE"
    $DRY_RUN && warn "Nenhuma alteração foi feita (dry-run)."
    sep
}

main "$@"