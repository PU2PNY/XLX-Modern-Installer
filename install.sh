#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# XLX Modern Installer
# Mantenedor da versão modificada: Dario — PU2PNY
# Base técnica: Daniel K. — PP5PK / PP5PK/XLX_Installer

readonly REPOSITORY="https://github.com/PP5PK/XLX_Installer.git"
readonly REVIEWED_COMMIT="865c0ea7abf736b89086fcd4684639f075a02d94"
readonly EXPECTED_INSTALLER_SHA256="b5fe63dc45f1732a539bc67d0c0b0cf97d41adb2b9be5354824cc58d74061cda"
readonly WORK_ROOT="/opt/xlx-modern-installer"
readonly SOURCE_DIR="${WORK_ROOT}/vendor/pp5pk-installer"
readonly BACKUP_ROOT="/var/backups/xlx-reflector"
readonly LOG_ROOT="/var/log/xlx-reflector/installer"
readonly CONFIRMATION="CONFIRMO_INSTALACAO_REAL_XLX"

MODE="install"
FORCE_CLEAN="no"
DASHBOARD_LANG=""
APRS_DPRS_MODE="ask"

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        --force-clean) FORCE_CLEAN="yes" ;;
        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;
        --with-aprs-dprs) APRS_DPRS_MODE="yes" ;;
        --without-aprs-dprs) APRS_DPRS_MODE="no" ;;
        -h|--help)
            cat <<'HELP'
XLX Modern Installer

Uso / Usage:
  sudo bash install.sh --check
  sudo bash install.sh
  sudo bash install.sh --lang=en
  sudo bash install.sh --with-aprs-dprs

Opções / Options:
  --check       Executa somente diagnóstico e validações.
                Runs diagnostics and validation only.
  --force-clean Permite continuar quando há vestígios não funcionais.
                Allows validation to continue with non-functional remnants.
                Nenhum arquivo é removido automaticamente.
                No file is removed automatically.
  --lang=CODE   Define o idioma do dashboard moderno.
                Sets the modern dashboard language.
                pt-BR | en | es | fr | de | it
  --with-aprs-dprs
                Instala também o módulo APRS/D-PRS independente e pinado.
                Also installs the pinned independent APRS/D-PRS module.
  --without-aprs-dprs
                Não oferece nem instala APRS/D-PRS nesta execução.
                Skips APRS/D-PRS in this run.

Sem uma dessas duas últimas opções, a instalação real pergunta se o módulo
APRS/D-PRS deve ser instalado. Ignorar o módulo não altera a instalação base.
HELP
            exit 0
            ;;
        *) echo "ERRO / ERROR: opção desconhecida / unknown option: $arg" >&2; exit 2 ;;
    esac
done

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
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
    [ "${ID:-}" = "debian" ] || fatal "Distribuição não homologada. Use Debian 12."
    [ "${VERSION_ID:-}" = "12" ] || fatal "Versão não homologada: Debian ${VERSION_ID:-desconhecida}. Use Debian 12."
    [ "$(uname -m)" = "x86_64" ] || fatal "Arquitetura não homologada: $(uname -m)."
    ok "Debian 12 x86_64 detectado."
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
    local missing=() command_name
    for command_name in bash awk sed grep find stat sha256sum tar systemctl curl getent df git tee; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done
    [ "${#missing[@]}" -eq 0 ] || fatal "Comandos ausentes: ${missing[*]}"
}

detect_existing_installation() {
    local detected=0
    if [ -x /xlxd/xlxd ]; then warn "Binário XLXD existente: /xlxd/xlxd"; detected=1; fi
    if systemctl is-active --quiet xlxd 2>/dev/null; then warn "Serviço xlxd está ativo."; detected=1; fi
    if [ -e /var/www/html/xlxd ] || [ -e /var/www/html/xlx-dashboard ]; then
        warn "Dashboard XLX existente detectado."; detected=1
    fi
    [ "$detected" -eq 0 ] || fatal "Instalação XLX existente detectada. O instalador não sobrescreve produção."

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
    mkdir -p "$backup"; chmod 700 "$backup"; : > "$manifest"

    for path in /etc/apache2 /etc/systemd/system /etc/ufw /etc/nftables.conf /var/www/html /xlxd /usr/src/xlxd /usr/src/XLXEcho /usr/src/XLX_Dark_Dashboard; do
        [ ! -e "$path" ] || printf '%s\n' "$path" >> "$manifest"
    done

    if [ -s "$manifest" ]; then
        info "Criando backup preventivo: $backup/pre-installation.tar.gz"
        tar --one-file-system --ignore-failed-read -czpf "$backup/pre-installation.tar.gz" -T "$manifest"
        sha256sum "$backup/pre-installation.tar.gz" > "$backup/pre-installation.tar.gz.sha256"
        sha256sum -c "$backup/pre-installation.tar.gz.sha256" >/dev/null
        ok "Backup preventivo criado e verificado."
    else
        info "Nenhum caminho existente exigiu backup preventivo."
    fi
}

prepare_source() {
    local actual_commit actual_hash
    mkdir -p "$(dirname "$SOURCE_DIR")"
    if [ -d "$SOURCE_DIR/.git" ]; then
        info "Atualizando fonte controlada do instalador original."
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
    [ "$actual_hash" = "$EXPECTED_INSTALLER_SHA256" ] || fatal "SHA-256 divergente. Esperado=$EXPECTED_INSTALLER_SHA256 Obtido=$actual_hash"
    find "$SOURCE_DIR" -type f -name '*.sh' -exec bash -n {} \;
    ok "Código-fonte original validado."
    info "Commit: $REVIEWED_COMMIT"
    info "SHA-256: $actual_hash"
}

show_plan() {
    cat <<PLAN

PLANO DA INSTALAÇÃO REAL
-------------------------
1. Coletar dados do refletor.
2. Instalar dependências Debian.
3. Compilar e instalar o núcleo XLXD.
4. Instalar serviços systemd.
5. Instalar XLX Echo, quando selecionado.
6. Instalar e configurar o dashboard.
7. Configurar Apache e HTTPS, quando selecionado.
8. Preparar as bases utilizadas pelo XLX.
9. Iniciar e validar os serviços.
10. APRS/D-PRS opcional: ${APRS_DPRS_MODE}.

Base técnica: PP5PK/XLX_Installer
Autor original: Daniel K. — PP5PK
Versão modificada: Dario — PU2PNY
PLAN

    if [ -n "$DASHBOARD_LANG" ]; then
        info "Idioma solicitado para o dashboard / requested dashboard language: $DASHBOARD_LANG"
    fi
}

run_check() {
    section "RESULTADO DA PRÉ-VALIDAÇÃO"
    ok "Sistema compatível."
    ok "Recursos mínimos disponíveis."
    ok "Rede funcional."
    ok "Nenhuma instalação ativa será sobrescrita."
    ok "Commit e SHA-256 confirmados."

    if [ "$APRS_DPRS_MODE" = "yes" ]; then
        section "PRÉ-VALIDAÇÃO APRS/D-PRS"
        bash "$ROOT_DIR/modules/67-aprs-dprs.sh" --check
    else
        info "APRS/D-PRS não solicitado no modo de pré-validação."
    fi

    info "Nenhuma instalação foi executada."
}

confirm_real_installation() {
    local typed
    warn "A próxima etapa executará uma instalação REAL / The next step performs a REAL installation."
    warn "Pacotes, Apache, PHP, systemd e firewall poderão ser alterados."
    warn "Packages, Apache, PHP, systemd and firewall may be changed."
    printf '\nCONFIRMAÇÃO FINAL / FINAL CONFIRMATION\n'
    printf 'Não digite o número XLX, indicativo ou qualquer outro dado do refletor.\n'
    printf 'Do not enter the XLX number, callsign, or any reflector information.\n\n'
    printf 'Digite/cop ie exatamente esta frase / Type or paste exactly this phrase:\n%s\n\n> ' "$CONFIRMATION"
    read -r typed
    [ "$typed" = "$CONFIRMATION" ] || fatal "Confirmação incorreta. Era esperada a frase de confirmação; instalação cancelada sem alterações."
}

resolve_aprs_choice() {
    local answer
    case "$APRS_DPRS_MODE" in
        yes) return 0 ;;
        no) return 1 ;;
        ask)
            printf '\n'
            read -r -p "Deseja instalar também o módulo opcional APRS/D-PRS? [s/N]: " answer
            case "${answer,,}" in
                s|sim|y|yes) APRS_DPRS_MODE="yes"; return 0 ;;
                *) APRS_DPRS_MODE="no"; return 1 ;;
            esac
            ;;
        *) fatal "Estado APRS/D-PRS inválido: $APRS_DPRS_MODE" ;;
    esac
}

execute_installer() {
    local stamp logfile installer_rc failures service dashboard_dest
    stamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_ROOT"; chmod 700 "$LOG_ROOT"
    logfile="${LOG_ROOT}/install_${stamp}.log"
    section "INICIANDO XLX MODERN INSTALLER"
    info "Log: $logfile"
    cd "$SOURCE_DIR"; chmod 700 installer.sh

    set +e
    bash ./installer.sh 2>&1 | tee -a "$logfile"
    installer_rc=${PIPESTATUS[0]}
    set -e
    [ "$installer_rc" -eq 0 ] || fatal "O instalador terminou com código $installer_rc. Consulte: $logfile"

    section "INSTALANDO XLX MODERN DASHBOARD"
    if [ -n "$DASHBOARD_LANG" ]; then
        bash "$ROOT_DIR/modules/60-dashboard-modern.sh" "--lang=$DASHBOARD_LANG"
    else
        bash "$ROOT_DIR/modules/60-dashboard-modern.sh"
    fi

    dashboard_dest="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
    if resolve_aprs_choice; then
        section "INSTALANDO APRS/D-PRS OPCIONAL"
        XLX_DASHBOARD_DIR="$dashboard_dest" \
            bash "$ROOT_DIR/modules/67-aprs-dprs.sh" "--dashboard-dir=$dashboard_dest"
    else
        info "APRS/D-PRS não instalado nesta execução. A instalação independente continua disponível posteriormente."
    fi

    section "VALIDAÇÃO PÓS-INSTALAÇÃO"
    failures=0
    for service in apache2 xlxd; do
        if systemctl is-active --quiet "$service"; then ok "$service ativo."; else warn "$service não está ativo."; failures=$((failures + 1)); fi
    done
    if systemctl list-unit-files xlxecho.service --no-legend 2>/dev/null | grep -q .; then
        if systemctl is-active --quiet xlxecho; then ok "xlxecho ativo."; else warn "xlxecho instalado, mas inativo."; failures=$((failures + 1)); fi
    fi
    apache2ctl configtest || failures=$((failures + 1))
    [ -x /xlxd/xlxd ] || { warn "Binário /xlxd/xlxd ausente."; failures=$((failures + 1)); }
    [ "$failures" -eq 0 ] || fatal "Instalação concluída com $failures falha(s). Consulte $logfile"
    section "INSTALAÇÃO CONCLUÍDA"
    ok "XLX instalado e validações essenciais aprovadas."
    info "Log: $logfile"
}

main() {
    clear
    section "XLX MODERN INSTALLER — PU2PNY"
    require_root
    validate_os
    validate_commands
    validate_resources
    validate_network
    detect_existing_installation
    prepare_source
    show_plan
    if [ "$MODE" = "check" ]; then run_check; exit 0; fi
    create_inventory_and_backup
    confirm_real_installation
    execute_installer
}

main "$@"
