#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# XLX Production Bootstrap
# Modified launcher maintained by Dario — PU2PNY.
# Installation engine: Daniel K. — PP5PK / PP5PK/XLX_Installer.
#
# This launcher prepares, validates, backs up and starts the upstream installer
# at a reviewed, pinned commit. It does not silently overwrite an existing XLX.

readonly REPOSITORY="https://github.com/PP5PK/XLX_Installer.git"
readonly REVIEWED_COMMIT="865c0ea7abf736b89086fcd4684639f075a02d94"
readonly EXPECTED_INSTALLER_SHA256="b5fe63dc45f1732a539bc67d0c0b0cf97d41adb2b9be5354824cc58d74061cda"
readonly WORK_ROOT="/opt/xlx-production-installer"
readonly SOURCE_DIR="${WORK_ROOT}/source"
readonly BACKUP_ROOT="/root/xlx-production-backups"
readonly LOG_ROOT="/var/log/xlx-production-installer"
readonly CONFIRMATION="CONFIRMO_INSTALACAO_REAL_XLX"

MODE="install"
FORCE_CLEAN="no"

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run)
            MODE="check"
            ;;
        --force-clean)
            FORCE_CLEAN="yes"
            ;;
        -h|--help)
            cat <<'HELP'
Uso:
  sudo bash production-installer.sh --check
  sudo bash production-installer.sh

Opções:
  --check       Executa somente diagnóstico e validações.
  --force-clean Permite continuar quando há vestígios não funcionais de instalação.
                Não remove nada automaticamente.
HELP
            exit 0
            ;;
        *)
            echo "ERRO: opção desconhecida: $arg" >&2
            exit 2
            ;;
    esac
done

RED=$'\033[31m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

info()    { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()      { printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal()   { printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
section() { printf '\n============================================================\n%s\n============================================================\n' "$*"; }

require_root() {
    [ "$(id -u)" -eq 0 ] || fatal "Execute como root: sudo bash $0"
}

validate_os() {
    [ -r /etc/os-release ] || fatal "/etc/os-release não encontrado."
    # shellcheck disable=SC1091
    source /etc/os-release

    [ "${ID:-}" = "debian" ] || fatal "Este bootstrap aceita somente Debian."
    case "${VERSION_ID:-}" in
        12) ok "Debian 12 detectado." ;;
        *) fatal "Versão não homologada: Debian ${VERSION_ID:-desconhecida}. Use Debian 12." ;;
    esac

    [ "$(uname -m)" = "x86_64" ] || fatal "Arquitetura não homologada: $(uname -m)."
}

validate_resources() {
    local mem_mb disk_mb
    mem_mb="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
    disk_mb="$(df -Pm / | awk 'NR==2 {print $4}')"

    info "Memória disponível: ${mem_mb} MB"
    info "Espaço livre em /: ${disk_mb} MB"

    [ "$mem_mb" -ge 768 ] || fatal "É necessário pelo menos 768 MB de RAM."
    [ "$disk_mb" -ge 4096 ] || fatal "É necessário pelo menos 4 GB livres."
}

validate_network() {
    getent hosts github.com >/dev/null 2>&1 || fatal "DNS não resolve github.com."
    curl -fsSI --connect-timeout 10 https://github.com/ >/dev/null || fatal "Sem acesso HTTPS ao GitHub."
    ok "Rede, DNS e HTTPS validados."
}

validate_commands() {
    local missing=()
    local command_name

    for command_name in bash awk sed grep find stat sha256sum tar systemctl curl getent df git tee; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        fatal "Comandos ausentes: ${missing[*]}"
    fi
}

detect_existing_installation() {
    local detected=0

    if [ -x /xlxd/xlxd ]; then
        warn "Binário XLXD existente: /xlxd/xlxd"
        detected=1
    fi

    if systemctl is-active --quiet xlxd 2>/dev/null; then
        warn "Serviço xlxd está ativo."
        detected=1
    fi

    if [ -e /var/www/html/xlxd ]; then
        warn "Dashboard existente: /var/www/html/xlxd"
        detected=1
    fi

    if [ "$detected" -eq 1 ]; then
        fatal "Instalação XLX existente detectada. Este instalador não sobrescreve produção."
    fi

    if [ -d /xlxd ] || [ -d /usr/src/xlxd ]; then
        warn "Foram encontrados vestígios de instalação anterior."
        [ "$FORCE_CLEAN" = "yes" ] || fatal "Revise os vestígios ou execute novamente com --force-clean. Nada será removido automaticamente."
    fi

    ok "Nenhuma instalação XLX ativa foi detectada."
}

create_inventory_and_backup() {
    local stamp backup manifest path
    stamp="$(date +%Y%m%d_%H%M%S)"
    backup="${BACKUP_ROOT}/${stamp}"
    manifest="${backup}/manifest.txt"

    mkdir -p "$backup"
    chmod 700 "$backup"
    : > "$manifest"

    for path in /etc/apache2 /etc/systemd/system /etc/ufw /etc/nftables.conf /var/www/html /xlxd /usr/src/xlxd /usr/src/XLXEcho /usr/src/XLX_Dark_Dashboard; do
        if [ -e "$path" ]; then
            printf '%s\n' "$path" >> "$manifest"
        fi
    done

    if [ -s "$manifest" ]; then
        info "Criando backup preventivo: $backup/pre-installation.tar.gz"
        tar --one-file-system --ignore-failed-read -czpf "$backup/pre-installation.tar.gz" -T "$manifest"
        sha256sum "$backup/pre-installation.tar.gz" > "$backup/pre-installation.tar.gz.sha256"
        ok "Backup preventivo criado e verificado."
    else
        info "Nenhum caminho existente exigiu backup preventivo."
    fi

    printf '%s\n' "$backup"
}

prepare_source() {
    local actual_commit actual_hash

    mkdir -p "$WORK_ROOT"

    if [ -d "$SOURCE_DIR/.git" ]; then
        info "Atualizando cópia controlada do instalador."
        git -C "$SOURCE_DIR" fetch --prune origin
    else
        rm -rf "$SOURCE_DIR"
        git clone --no-checkout "$REPOSITORY" "$SOURCE_DIR"
    fi

    git -C "$SOURCE_DIR" checkout --detach "$REVIEWED_COMMIT"

    actual_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
    [ "$actual_commit" = "$REVIEWED_COMMIT" ] || fatal "Commit inesperado: $actual_commit"

    [ -f "$SOURCE_DIR/installer.sh" ] || fatal "installer.sh não encontrado no projeto original."

    actual_hash="$(sha256sum "$SOURCE_DIR/installer.sh" | awk '{print $1}')"
    [ "$actual_hash" = "$EXPECTED_INSTALLER_SHA256" ] || fatal "SHA-256 do installer.sh divergiu. Esperado=$EXPECTED_INSTALLER_SHA256 Obtido=$actual_hash"

    find "$SOURCE_DIR" -type f -name '*.sh' -exec bash -n {} \;

    ok "Código-fonte validado."
    info "Repositório: $REPOSITORY"
    info "Commit fixado: $REVIEWED_COMMIT"
    info "SHA-256: $actual_hash"
}

show_plan() {
    cat <<PLAN

PLANO DA INSTALAÇÃO REAL
-------------------------
1. Coletar dados do refletor.
2. Atualizar e instalar dependências Debian.
3. Clonar e compilar o núcleo XLXD.
4. Criar /xlxd e instalar os componentes.
5. Instalar dashboard Apache/PHP.
6. Configurar serviços systemd.
7. Instalar XLX Echo, quando selecionado.
8. Configurar HTTPS, quando selecionado.
9. Baixar e preparar as bases utilizadas pelo XLX.
10. Iniciar e validar os serviços.

Origem técnica:
  $REPOSITORY
Commit revisado:
  $REVIEWED_COMMIT

O instalador original é de Daniel K. — PP5PK.
Este bootstrap adiciona validação, commit fixado, hash, inventário,
backup preventivo e bloqueio contra sobrescrita de XLX existente.
PLAN
}

run_check() {
    section "RESULTADO DA PRÉ-VALIDAÇÃO"
    ok "Sistema compatível."
    ok "Recursos mínimos disponíveis."
    ok "Rede funcional."
    ok "Nenhuma instalação ativa será sobrescrita."
    ok "Commit e SHA-256 do instalador confirmados."
    info "Nenhuma alteração de instalação foi executada."
}

confirm_real_installation() {
    local typed

    warn "A próxima etapa executará uma instalação REAL."
    warn "Pacotes, Apache, PHP, systemd e firewall poderão ser alterados."
    printf '\nDigite exatamente:\n%s\n\n> ' "$CONFIRMATION"
    read -r typed

    [ "$typed" = "$CONFIRMATION" ] || fatal "Confirmação incorreta. Instalação cancelada."
}

execute_installer() {
    local stamp logfile installer_rc
    stamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_ROOT"
    chmod 700 "$LOG_ROOT"
    logfile="${LOG_ROOT}/install_${stamp}.log"

    section "INICIANDO INSTALADOR OFICIAL"
    info "Log adicional: $logfile"

    cd "$SOURCE_DIR"
    chmod 700 installer.sh

    set +e
    bash ./installer.sh 2>&1 | tee -a "$logfile"
    installer_rc=${PIPESTATUS[0]}
    set -e

    if [ "$installer_rc" -ne 0 ]; then
        fatal "O instalador terminou com código $installer_rc. Consulte: $logfile"
    fi

    section "VALIDAÇÃO PÓS-INSTALAÇÃO"

    local failures=0 service
    for service in apache2 xlxd; do
        if systemctl is-active --quiet "$service"; then
            ok "$service ativo."
        else
            warn "$service não está ativo."
            failures=$((failures + 1))
        fi
    done

    if systemctl list-unit-files xlxecho.service --no-legend 2>/dev/null | grep -q .; then
        if systemctl is-active --quiet xlxecho; then
            ok "xlxecho ativo."
        else
            warn "xlxecho instalado, mas não está ativo."
            failures=$((failures + 1))
        fi
    fi

    if apache2ctl configtest; then
        ok "Configuração Apache válida."
    else
        failures=$((failures + 1))
    fi

    if [ -x /xlxd/xlxd ]; then
        ok "Binário /xlxd/xlxd presente."
    else
        warn "Binário /xlxd/xlxd ausente."
        failures=$((failures + 1))
    fi

    if [ "$failures" -ne 0 ]; then
        fatal "Instalação concluída com $failures falha(s) de validação. Consulte $logfile"
    fi

    section "INSTALAÇÃO CONCLUÍDA"
    ok "XLX instalado e validações essenciais aprovadas."
    info "Log: $logfile"
}

main() {
    clear
    section "XLX PRODUCTION BOOTSTRAP — PU2PNY"

    require_root
    validate_os
    validate_commands
    validate_resources
    validate_network
    detect_existing_installation
    prepare_source
    show_plan

    if [ "$MODE" = "check" ]; then
        run_check
        exit 0
    fi

    create_inventory_and_backup >/dev/null
    confirm_real_installation
    execute_installer
}

main "$@"
