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
readonly CONFIRMATION="INSTALL"
readonly DEFAULT_DASHBOARD_DIR="/var/www/html/xlx-dashboard"

MODE="install"
ALLOW_REMNANTS="no"
DASHBOARD_LANG=""
UI_LANG="pt-BR"
APRS_DPRS_MODE="ask"

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        --allow-remnants|--force-clean) ALLOW_REMNANTS="yes" ;;
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
  --check
      Apenas verifica o servidor. Não instala nem altera o XLX.
      Checks the server only. Does not install or change XLX.

  --lang=CODE
      Define o idioma do dashboard. Com --lang=en, a interface deste
      instalador também usa inglês.
      Sets the dashboard language. With --lang=en, this installer UI
      also uses English.
      pt-BR | en | es | fr | de | it

  --with-aprs-dprs
      Instala também o módulo opcional APRS/D-PRS.
      Also installs the optional APRS/D-PRS module.

  --without-aprs-dprs
      Não instala nem pergunta sobre APRS/D-PRS nesta execução.
      Skips APRS/D-PRS and does not ask about it in this run.

  --allow-remnants
      Permite continuar quando existem apenas vestígios de instalação antiga.
      Não apaga arquivos automaticamente.
      Allows continuing when only old installation remnants exist.
      It never deletes files automatically.

  --force-clean
      Alias legado de --allow-remnants. Não executa limpeza automática.
      Legacy alias for --allow-remnants. It does not clean files automatically.
HELP
            exit 0
            ;;
        *) printf 'ERRO / ERROR: opção desconhecida / unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

case "$DASHBOARD_LANG" in
    en) UI_LANG="en" ;;
    *) UI_LANG="pt-BR" ;;
esac
export XLX_UI_LANG="$UI_LANG"

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'

msg() {
    local pt="$1" en="$2"
    if [ "$UI_LANG" = "en" ]; then printf '%s' "$en"; else printf '%s' "$pt"; fi
}
info()  { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()    { printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { if [ "$UI_LANG" = "en" ]; then printf '%s[WARNING]%s %s\n' "$YELLOW" "$RESET" "$*"; else printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; fi; }
fatal() { if [ "$UI_LANG" = "en" ]; then printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2; else printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; fi; exit 1; }
section() { printf '\n============================================================\n%s\n============================================================\n' "$*"; }

validate_options() {
    case "$DASHBOARD_LANG" in
        ""|pt-BR|en|es|fr|de|it) ;;
        *) fatal "$(msg "Idioma inválido: $DASHBOARD_LANG. Use pt-BR, en, es, fr, de ou it." "Invalid language: $DASHBOARD_LANG. Use pt-BR, en, es, fr, de, or it.")" ;;
    esac
}

require_root() {
    [ "$(id -u)" -eq 0 ] || fatal "$(msg "Execute como root: sudo bash $0" "Run as root: sudo bash $0")"
}

select_ui_language() {
    # --lang=CODE is explicit and must never be overridden interactively.
    [ -n "$DASHBOARD_LANG" ] && return 0
    [ -t 0 ] || return 0

    section "XLX MODERN INSTALLER — PU2PNY"
    printf '%s\n' "Selecione o idioma / Select language:"
    printf '%s\n' "  1) Português (Brasil) [padrão]"
    printf '%s\n' "  2) English"
    printf '%s' "Opção / Option [1]: "
    local choice=""
    read -r choice || choice=""
    case "${choice,,}" in
        2|e|en|english) UI_LANG="en"; DASHBOARD_LANG="en" ;;
        ""|1|p|pt|pt-br|portugues|português) UI_LANG="pt-BR"; DASHBOARD_LANG="pt-BR" ;;
        *) warn "Opção inválida; Português (Brasil) será usado. / Invalid option; Portuguese (Brazil) will be used."
           UI_LANG="pt-BR"; DASHBOARD_LANG="pt-BR" ;;
    esac
    export XLX_UI_LANG="$UI_LANG"
}

bootstrap_install_prerequisites() {
    # A clean supported Debian host should not fail merely because curl or
    # certificates have not yet been installed. --check remains read-only.
    local package
    local needed=()
    for package in ca-certificates curl git; do
        case "$package" in
            ca-certificates) [ -f /etc/ssl/certs/ca-certificates.crt ] || needed+=("$package") ;;
            curl|git) command -v "$package" >/dev/null 2>&1 || needed+=("$package") ;;
        esac
    done
    [ "${#needed[@]}" -eq 0 ] && return 0

    if [ "$MODE" = "check" ]; then
        warn "$(msg "Pré-requisitos ainda não instalados: ${needed[*]}. O modo --check não altera o servidor." "Prerequisites are not installed yet: ${needed[*]}. --check does not change the server.")"
        return 0
    fi

    command -v apt-get >/dev/null 2>&1 || fatal "$(msg "apt-get não foi encontrado; não é possível instalar os pré-requisitos." "apt-get was not found; cannot install prerequisites.")"
    info "$(msg "Instalando pré-requisitos automaticamente: ${needed[*]}" "Installing prerequisites automatically: ${needed[*]}")"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y "${needed[@]}"
    ok "$(msg "Pré-requisitos instalados." "Prerequisites installed.")"
}

validate_os() {
    [ -r /etc/os-release ] || fatal "$(msg "/etc/os-release não encontrado." "/etc/os-release was not found.")"
    # shellcheck disable=SC1091
    source /etc/os-release
    [ "${ID:-}" = "debian" ] || fatal "$(msg "Distribuição não homologada. Use Debian 12." "Unsupported distribution. Use Debian 12.")"
    [ "${VERSION_ID:-}" = "12" ] || fatal "$(msg "Versão não homologada: Debian ${VERSION_ID:-desconhecida}. Use Debian 12." "Unsupported version: Debian ${VERSION_ID:-unknown}. Use Debian 12.")"
    [ "$(uname -m)" = "x86_64" ] || fatal "$(msg "Arquitetura não homologada: $(uname -m). Use x86_64." "Unsupported architecture: $(uname -m). Use x86_64.")"
    ok "$(msg "Debian 12 x86_64 detectado." "Debian 12 x86_64 detected.")"
}

validate_resources() {
    local mem_mb disk_mb
    mem_mb="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
    disk_mb="$(df -Pm / | awk 'NR==2 {print $4}')"
    info "$(msg "Memória RAM: ${mem_mb} MB" "RAM: ${mem_mb} MB")"
    info "$(msg "Espaço livre em /: ${disk_mb} MB" "Free space on /: ${disk_mb} MB")"
    [ "$mem_mb" -ge 768 ] || fatal "$(msg "RAM insuficiente. Mínimo: 768 MB." "Not enough RAM. Minimum: 768 MB.")"
    [ "$disk_mb" -ge 4096 ] || fatal "$(msg "Espaço insuficiente. Mínimo: 4 GB livres em /." "Not enough disk space. Minimum: 4 GB free on /.")"
}

validate_network() {
    getent hosts github.com >/dev/null 2>&1 || fatal "$(msg "Falha de DNS: github.com não foi resolvido." "DNS failure: github.com could not be resolved.")"
    curl -fsSI --connect-timeout 10 https://github.com/ >/dev/null || fatal "$(msg "Sem acesso HTTPS ao GitHub." "Cannot reach GitHub over HTTPS.")"
    ok "$(msg "Rede, DNS e HTTPS validados." "Network, DNS, and HTTPS validated.")"
}

validate_commands() {
    local missing=() command_name
    for command_name in bash awk sed grep find stat sha256sum tar systemctl curl getent df git tee; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done
    [ "${#missing[@]}" -eq 0 ] || fatal "$(msg "Comandos obrigatórios ausentes: ${missing[*]}. Execute a instalação real para instalar os pré-requisitos automaticamente." "Required commands missing: ${missing[*]}. Run the real installation to install prerequisites automatically.")"
}

detect_existing_installation() {
    local detected=0
    if [ -x /xlxd/xlxd ]; then warn "$(msg "Binário XLXD existente: /xlxd/xlxd" "Existing XLXD binary: /xlxd/xlxd")"; detected=1; fi
    if systemctl is-active --quiet xlxd 2>/dev/null; then warn "$(msg "Serviço xlxd está ativo." "xlxd service is active.")"; detected=1; fi
    if [ -e /var/www/html/xlxd ] || [ -e /var/www/html/xlx-dashboard ]; then
        warn "$(msg "Dashboard XLX existente detectado." "Existing XLX dashboard detected.")"; detected=1
    fi
    [ "$detected" -eq 0 ] || fatal "$(msg "Instalação XLX ativa detectada. Por segurança, este instalador não sobrescreve produção." "Active XLX installation detected. For safety, this installer will not overwrite production.")"

    if [ -d /xlxd ] || [ -d /usr/src/xlxd ]; then
        warn "$(msg "Foram encontrados vestígios de uma instalação anterior." "Old installation remnants were found.")"
        [ "$ALLOW_REMNANTS" = "yes" ] || fatal "$(msg "Revise os vestígios. Se souber que são inativos, execute novamente com --allow-remnants. Essa opção NÃO apaga arquivos." "Review the remnants. If you know they are inactive, run again with --allow-remnants. This option does NOT delete files.")"
    fi
    ok "$(msg "Nenhuma instalação XLX ativa foi detectada." "No active XLX installation detected.")"
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
        info "$(msg "Criando backup preventivo: $backup/pre-installation.tar.gz" "Creating safety backup: $backup/pre-installation.tar.gz")"
        tar --one-file-system --ignore-failed-read -czpf "$backup/pre-installation.tar.gz" -T "$manifest"
        sha256sum "$backup/pre-installation.tar.gz" > "$backup/pre-installation.tar.gz.sha256"
        sha256sum -c "$backup/pre-installation.tar.gz.sha256" >/dev/null
        ok "$(msg "Backup preventivo criado e verificado." "Safety backup created and verified.")"
    else
        info "$(msg "Nenhum caminho existente exigiu backup preventivo." "No existing paths required a safety backup.")"
    fi
}

prepare_source() {
    local actual_commit actual_hash
    mkdir -p "$(dirname "$SOURCE_DIR")"
    if [ -d "$SOURCE_DIR/.git" ]; then
        info "$(msg "Atualizando a cópia controlada do instalador base." "Refreshing the controlled copy of the base installer.")"
        git -C "$SOURCE_DIR" fetch --prune origin
    else
        rm -rf "$SOURCE_DIR"
        git clone --no-checkout "$REPOSITORY" "$SOURCE_DIR"
    fi
    git -C "$SOURCE_DIR" checkout --detach "$REVIEWED_COMMIT"
    actual_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
    [ "$actual_commit" = "$REVIEWED_COMMIT" ] || fatal "$(msg "Commit inesperado: $actual_commit" "Unexpected commit: $actual_commit")"
    [ -f "$SOURCE_DIR/installer.sh" ] || fatal "$(msg "installer.sh não encontrado no projeto base." "installer.sh was not found in the base project.")"
    actual_hash="$(sha256sum "$SOURCE_DIR/installer.sh" | awk '{print $1}')"
    [ "$actual_hash" = "$EXPECTED_INSTALLER_SHA256" ] || fatal "$(msg "SHA-256 divergente. Esperado=$EXPECTED_INSTALLER_SHA256 Obtido=$actual_hash" "SHA-256 mismatch. Expected=$EXPECTED_INSTALLER_SHA256 Got=$actual_hash")"
    find "$SOURCE_DIR" -type f -name '*.sh' -exec bash -n {} \;
    ok "$(msg "Código-fonte base validado." "Base source code validated.")"
    info "Commit: $REVIEWED_COMMIT"
    info "SHA-256: $actual_hash"
}

show_plan() {
    local dash_lang="${DASHBOARD_LANG:-$(msg "padrão (pt-BR)" "default (pt-BR)")}"
    if [ "$UI_LANG" = "en" ]; then
        cat <<PLAN

REAL INSTALLATION PLAN
----------------------
Before starting, have these details ready:
- XLX reflector ID (3 characters, e.g. 139)
- dashboard domain/FQDN
- sysop e-mail address
- sysop callsign
- country and timezone

The installer will then:
1. Collect reflector information.
2. Install Debian dependencies.
3. Build and install XLXD.
4. Install systemd services.
5. Install XLX Echo when selected.
6. Install the modern dashboard.
7. Configure Apache and HTTPS when selected.
8. Prepare XLX databases.
9. Start and validate services.
10. Offer APRS/D-PRS when configured to ask.

Current choices:
- Mode: $MODE
- Dashboard language: $dash_lang
- Dashboard directory: $DEFAULT_DASHBOARD_DIR
- APRS/D-PRS: $APRS_DPRS_MODE

Technical base: PP5PK/XLX_Installer
Original author: Daniel K. — PP5PK
Modified version: Dario — PU2PNY
PLAN
    else
        cat <<PLAN

PLANO DA INSTALAÇÃO REAL
-------------------------
Antes de começar, tenha estes dados em mãos:
- ID do refletor XLX (3 caracteres, ex.: 026)
- domínio/FQDN do dashboard
- e-mail do sysop
- indicativo do sysop
- país e fuso horário

Depois o instalador irá:
1. Coletar os dados do refletor.
2. Instalar dependências Debian.
3. Compilar e instalar o XLXD.
4. Instalar serviços systemd.
5. Instalar XLX Echo quando selecionado.
6. Instalar o dashboard moderno.
7. Configurar Apache e HTTPS quando selecionado.
8. Preparar as bases do XLX.
9. Iniciar e validar os serviços.
10. Oferecer APRS/D-PRS quando configurado para perguntar.

Escolhas atuais:
- Modo: $MODE
- Idioma do dashboard: $dash_lang
- Diretório do dashboard: $DEFAULT_DASHBOARD_DIR
- APRS/D-PRS: $APRS_DPRS_MODE

Base técnica: PP5PK/XLX_Installer
Autor original: Daniel K. — PP5PK
Versão modificada: Dario — PU2PNY
PLAN
    fi

    if [ -n "$DASHBOARD_LANG" ] && [ "$DASHBOARD_LANG" != "en" ] && [ "$DASHBOARD_LANG" != "pt-BR" ]; then
        info "$(msg "O dashboard usará $DASHBOARD_LANG. As mensagens do instalador permanecem em português; use --lang=en para interface do instalador em inglês." "The dashboard will use $DASHBOARD_LANG. Installer messages remain in Portuguese; use --lang=en for English installer UI.")"
    fi
}

run_check() {
    section "$(msg "RESULTADO DA PRÉ-VALIDAÇÃO" "PRE-INSTALLATION CHECK RESULT")"
    ok "$(msg "Sistema compatível." "Compatible system.")"
    ok "$(msg "Recursos mínimos disponíveis." "Minimum resources available.")"
    ok "$(msg "Rede funcional." "Network is working.")"
    ok "$(msg "Nenhuma instalação ativa será sobrescrita." "No active installation will be overwritten.")"
    ok "$(msg "Commit e SHA-256 confirmados." "Commit and SHA-256 verified.")"

    if [ "$APRS_DPRS_MODE" = "yes" ]; then
        section "$(msg "PRÉ-VALIDAÇÃO APRS/D-PRS" "APRS/D-PRS PRE-CHECK")"
        bash "$ROOT_DIR/modules/67-aprs-dprs.sh" --check
    else
        info "$(msg "APRS/D-PRS não solicitado no modo de pré-validação." "APRS/D-PRS was not requested for this pre-check.")"
    fi

    info "$(msg "Nenhuma instalação foi executada." "No installation was performed.")"
}

confirm_real_installation() {
    local typed
    section "$(msg "CONFIRMAÇÃO FINAL" "FINAL CONFIRMATION")"
    warn "$(msg "A próxima etapa inicia uma instalação REAL." "The next step starts a REAL installation.")"
    warn "$(msg "Pacotes, Apache, PHP, systemd e firewall poderão ser alterados." "Packages, Apache, PHP, systemd, and firewall may be changed.")"
    printf '\n%s\n' "$(msg "Para continuar, digite exatamente a palavra: $CONFIRMATION" "To continue, type exactly the word: $CONFIRMATION")"
    printf '%s\n' "$(msg "Para cancelar com segurança, pressione Ctrl+C ou digite qualquer outra coisa." "To cancel safely, press Ctrl+C or type anything else.")"
    printf '\n%s' "$(msg "Confirmação [digite INSTALL]: " "Confirmation [type INSTALL]: ")"
    read -r typed
    [ "$typed" = "$CONFIRMATION" ] || fatal "$(msg "Confirmação não reconhecida. Instalação cancelada antes da etapa real." "Confirmation not recognized. Installation cancelled before the real installation step.")"
    ok "$(msg "Confirmação aceita. Iniciando instalação real." "Confirmation accepted. Starting real installation.")"
}

resolve_aprs_choice() {
    local answer
    case "$APRS_DPRS_MODE" in
        yes) return 0 ;;
        no) return 1 ;;
        ask)
            printf '\n%s' "$(msg "Instalar também o módulo opcional APRS/D-PRS? [s/N]: " "Install the optional APRS/D-PRS module too? [y/N]: ")"
            read -r answer
            case "${answer,,}" in
                s|sim|y|yes) APRS_DPRS_MODE="yes"; return 0 ;;
                *) APRS_DPRS_MODE="no"; return 1 ;;
            esac
            ;;
        *) fatal "$(msg "Estado APRS/D-PRS inválido: $APRS_DPRS_MODE" "Invalid APRS/D-PRS state: $APRS_DPRS_MODE")" ;;
    esac
}

execute_installer() {
    local stamp logfile installer_rc failures service dashboard_dest
    stamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_ROOT"; chmod 700 "$LOG_ROOT"
    logfile="${LOG_ROOT}/install_${stamp}.log"
    section "$(msg "INICIANDO XLX MODERN INSTALLER" "STARTING XLX MODERN INSTALLER")"
    info "$(msg "Log da instalação: $logfile" "Installation log: $logfile")"
    info "$(msg "A próxima tela pertence ao instalador base e solicitará os dados do refletor." "The next screen is the base installer and will ask for reflector information.")"
    cd "$SOURCE_DIR"; chmod 700 installer.sh

    set +e
    bash ./installer.sh 2>&1 | tee -a "$logfile"
    installer_rc=${PIPESTATUS[0]}
    set -e
    [ "$installer_rc" -eq 0 ] || fatal "$(msg "O instalador base terminou com código $installer_rc. Consulte o log: $logfile" "The base installer exited with code $installer_rc. Check the log: $logfile")"

    section "$(msg "INSTALANDO XLX MODERN DASHBOARD" "INSTALLING XLX MODERN DASHBOARD")"
    if [ -n "$DASHBOARD_LANG" ]; then
        bash "$ROOT_DIR/modules/60-dashboard-modern.sh" "--lang=$DASHBOARD_LANG"
    else
        bash "$ROOT_DIR/modules/60-dashboard-modern.sh"
    fi

    dashboard_dest="${INSTALL_DIR:-$DEFAULT_DASHBOARD_DIR}"
    if resolve_aprs_choice; then
        section "$(msg "INSTALANDO APRS/D-PRS OPCIONAL" "INSTALLING OPTIONAL APRS/D-PRS")"
        XLX_DASHBOARD_DIR="$dashboard_dest" bash "$ROOT_DIR/modules/67-aprs-dprs.sh" "--dashboard-dir=$dashboard_dest"
    else
        info "$(msg "APRS/D-PRS não instalado. Ele poderá ser instalado separadamente depois." "APRS/D-PRS was not installed. It can be installed separately later.")"
    fi

    section "$(msg "VALIDAÇÃO PÓS-INSTALAÇÃO" "POST-INSTALLATION VALIDATION")"
    failures=0
    for service in apache2 xlxd; do
        if systemctl is-active --quiet "$service"; then
            ok "$(msg "Serviço $service ativo." "$service service is active.")"
        else
            warn "$(msg "Serviço $service não está ativo." "$service service is not active.")"
            failures=$((failures + 1))
        fi
    done
    if systemctl list-unit-files xlxecho.service --no-legend 2>/dev/null | grep -q .; then
        if systemctl is-active --quiet xlxecho; then
            ok "$(msg "Serviço xlxecho ativo." "xlxecho service is active.")"
        else
            warn "$(msg "XLX Echo foi instalado, mas o serviço está inativo." "XLX Echo is installed, but its service is inactive.")"
            failures=$((failures + 1))
        fi
    fi
    if apache2ctl configtest >/dev/null 2>&1; then
        ok "$(msg "Configuração do Apache válida." "Apache configuration is valid.")"
    else
        warn "$(msg "A validação da configuração do Apache falhou." "Apache configuration validation failed.")"
        failures=$((failures + 1))
    fi
    [ -x /xlxd/xlxd ] || { warn "$(msg "Binário /xlxd/xlxd ausente." "Binary /xlxd/xlxd is missing.")"; failures=$((failures + 1)); }

    if [ "$failures" -ne 0 ]; then
        fatal "$(msg "A instalação terminou, mas $failures validação(ões) falharam. Não considere o servidor pronto. Consulte: $logfile" "Installation finished, but $failures validation check(s) failed. Do not consider the server ready. Check: $logfile")"
    fi

    section "$(msg "INSTALAÇÃO CONCLUÍDA" "INSTALLATION COMPLETE")"
    ok "$(msg "XLX instalado e validações essenciais aprovadas." "XLX installed and essential validation checks passed.")"
    info "$(msg "Dashboard: $dashboard_dest" "Dashboard: $dashboard_dest")"
    info "$(msg "Log: $logfile" "Log: $logfile")"
}

main() {
    clear
    section "XLX MODERN INSTALLER — PU2PNY"
    validate_options
    require_root
    select_ui_language
    validate_os
    bootstrap_install_prerequisites
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
