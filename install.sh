#!/usr/bin/env bash
set -Eeuo pipefail
# XLX_ERROR_TRACE_V1 — never return silently to the shell on an unexpected failure.
_xlx_error_trace(){
  local rc=$?
  printf '\n[ERROR] file=%s line=%s rc=%s command=%q\n' \
    "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" \
    "${BASH_LINENO[0]:-$LINENO}" "$rc" "$BASH_COMMAND" >&2
  return "$rc"
}
trap _xlx_error_trace ERR
IFS=$'\n\t'
umask 077

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# XLX Modern Installer
# Mantenedor da versão modificada: Dario — PU2PNY
# Base técnica: Daniel K. — PP5PK / PP5PK/XLX_Installer

readonly REPOSITORY="local:vendor/pp5pk-installer"
readonly REVIEWED_COMMIT="vendor-pinned-PP5PK-20b4893"
readonly EXPECTED_INSTALLER_SHA256="8e252dfb0ffcee76c65f189d84ffd503951dfb1d2aca32a1265d1dc746b7027b"
readonly WORK_ROOT="/opt/xlx-modern-installer"
readonly SOURCE_DIR="${WORK_ROOT}/vendor/pp5pk-installer"
readonly BACKUP_ROOT="/var/backups/xlx-reflector"
readonly LOG_ROOT="/var/log/xlx-reflector/installer"
readonly DEFAULT_DASHBOARD_DIR="/var/www/html/xlxd"

MODE="install"
ALLOW_REMNANTS="no"
DASHBOARD_ONLY="no"
DASHBOARD_LANG=""
UI_LANG="pt-BR"
CHECK_READY="yes"

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        --dashboard-only) DASHBOARD_ONLY="yes" ;;
        --allow-remnants|--force-clean) ALLOW_REMNANTS="yes" ;;
        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;
        -h|--help)
            cat <<'HELP'
XLX Modern Installer

Uso / Usage:
  sudo bash install.sh --check
  sudo bash install.sh
  sudo bash install.sh --lang=en
  sudo bash install.sh --dashboard-only

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

  --dashboard-only
      Atualiza ou reinstala somente o painel moderno em um XLXD existente.
      Preserva o núcleo XLXD, cria backup preventivo e não executa a
      instalação completa do refletor.
      Updates or reinstalls only the modern dashboard on an existing XLXD.
      It preserves the XLXD core, creates a preventive backup, and does not
      run a full reflector installation.

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
    [ -n "$DASHBOARD_LANG" ] && return 0
    [ -t 0 ] || return 0

    section "XLX MODERN INSTALLER — PU2PNY"
    printf '%s\n' "Selecione o idioma / Select language:"
    printf '%s\n' "  1) Português (Brasil) [padrão]"
    printf '%s\n' "  2) English"
    local choice=""
    while :; do
        printf '%s' "Opção / Option [1]: "
        read -r choice || choice=""
        case "${choice,,}" in
            2|e|en|english) UI_LANG="en"; break ;;
            ""|1|p|pt|pt-br|portugues|português) UI_LANG="pt-BR"; break ;;
            *) warn "Opção inválida. Digite 1 para Português ou 2 para English. / Invalid option. Type 1 for Portuguese or 2 for English." ;;
        esac
    done
    export XLX_UI_LANG="$UI_LANG"
    ok "$(msg "Idioma selecionado: Português (Brasil)." "Selected language: English.")"
}

dashboard_language_name() {
    case "$1" in
        pt-BR) printf '%s' 'Português (Brasil)' ;;
        en) printf '%s' 'English' ;;
        es) printf '%s' 'Español' ;;
        fr) printf '%s' 'Français' ;;
        de) printf '%s' 'Deutsch' ;;
        it) printf '%s' 'Italiano' ;;
        *) printf '%s' "$1" ;;
    esac
}

select_dashboard_language() {
    [ -n "$DASHBOARD_LANG" ] && return 0

    if [ ! -t 0 ]; then
        DASHBOARD_LANG="$UI_LANG"
        return 0
    fi

    local choice="" default_choice="1"
    [ "$UI_LANG" = "en" ] && default_choice="2"
    section "$(msg "IDIOMA DO PAINEL" "DASHBOARD LANGUAGE")"
    printf '%s\n' "  1) Português (Brasil)"
    printf '%s\n' "  2) English"
    printf '%s\n' "  3) Español"
    printf '%s\n' "  4) Français"
    printf '%s\n' "  5) Deutsch"
    printf '%s\n' "  6) Italiano"

    while :; do
        printf '%s' "$(msg "Escolha o idioma exibido no painel [$default_choice]: " "Choose the language displayed on the dashboard [$default_choice]: ")"
        read -r choice || choice=""
        choice="${choice:-$default_choice}"
        case "$choice" in
            1) DASHBOARD_LANG="pt-BR"; break ;;
            2) DASHBOARD_LANG="en"; break ;;
            3) DASHBOARD_LANG="es"; break ;;
            4) DASHBOARD_LANG="fr"; break ;;
            5) DASHBOARD_LANG="de"; break ;;
            6) DASHBOARD_LANG="it"; break ;;
            *) warn "$(msg "Opção inválida. Digite um número de 1 a 6." "Invalid option. Type a number from 1 to 6.")" ;;
        esac
    done
    ok "$(msg "Idioma do painel selecionado: $(dashboard_language_name "$DASHBOARD_LANG")." "Selected dashboard language: $(dashboard_language_name "$DASHBOARD_LANG").")"
}

bootstrap_install_prerequisites() {
    local package
    local needed=()
    for package in ca-certificates curl git rsync sqlite3; do
        case "$package" in
            ca-certificates) [ -f /etc/ssl/certs/ca-certificates.crt ] || needed+=("$package") ;;
            curl|git|rsync|sqlite3) command -v "$package" >/dev/null 2>&1 || needed+=("$package") ;;
        esac
    done
    [ "${#needed[@]}" -eq 0 ] && return 0

    if [ "$MODE" = "check" ]; then
        info "$(msg "Pré-requisitos pendentes: ${needed[*]}. Eles serão instalados automaticamente na instalação real; o modo --check não altera o servidor." "Prerequisites pending: ${needed[*]}. They will be installed automatically during the real installation; --check does not change the server.")"
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
    if ! command -v curl >/dev/null 2>&1; then
        CHECK_READY="no"
        info "$(msg "DNS validado. curl será instalado automaticamente na instalação real; a verificação HTTPS foi adiada." "DNS validated. curl will be installed automatically during the real installation; the HTTPS check was deferred.")"
        return 0
    fi
    curl -fsSI --connect-timeout 10 https://github.com/ >/dev/null || fatal "$(msg "Sem acesso HTTPS ao GitHub." "Cannot reach GitHub over HTTPS.")"
    ok "$(msg "Rede, DNS e HTTPS validados." "Network, DNS, and HTTPS validated.")"
}

validate_commands() {
    local missing=() command_name
    for command_name in bash awk sed grep find stat sha256sum tar systemctl curl getent df git tee; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done
    if [ "${#missing[@]}" -ne 0 ]; then
        if [ "$MODE" = "check" ]; then
            CHECK_READY="no"
            info "$(msg "Comandos pendentes: ${missing[*]}. A instalação real instalará os pré-requisitos automaticamente." "Commands pending: ${missing[*]}. The real installation will install the prerequisites automatically.")"
            return 0
        fi
        fatal "$(msg "Comandos obrigatórios ausentes: ${missing[*]}. Execute a instalação real para instalar os pré-requisitos automaticamente." "Required commands missing: ${missing[*]}. Run the real installation to install prerequisites automatically.")"
    fi
}

detect_existing_installation() {
    local detected=0
    if [ -x /xlxd/xlxd ]; then warn "$(msg "Binário XLXD existente: /xlxd/xlxd" "Existing XLXD binary: /xlxd/xlxd")"; detected=1; fi
    if systemctl is-active --quiet xlxd 2>/dev/null; then warn "$(msg "Serviço xlxd está ativo." "xlxd service is active.")"; detected=1; fi
    if [ -e /var/www/html/xlxd ] || [ -e /var/www/html/xlx-dashboard ]; then
        warn "$(msg "Dashboard XLX existente detectado." "Existing XLX dashboard detected.")"; detected=1
    fi
    if [ "$detected" -ne 0 ]; then
        if [ "$DASHBOARD_ONLY" = "yes" ]; then
            [ -x /xlxd/xlxd ] || fatal "$(msg "Atualização somente do painel exige um XLXD existente em /xlxd/xlxd." "Dashboard-only update requires an existing XLXD at /xlxd/xlxd.")"
            ok "$(msg "XLXD existente confirmado. O modo somente painel preservará o núcleo do refletor." "Existing XLXD confirmed. Dashboard-only mode will preserve the reflector core.")"
            return 0
        fi
        fatal "$(msg "Instalação XLX ativa detectada. Para atualizar somente o painel, execute: sudo bash install.sh --dashboard-only" "Active XLX installation detected. To update only the dashboard, run: sudo bash install.sh --dashboard-only")"
    fi

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
    local source_installer="$ROOT_DIR/vendor/pp5pk-installer/installer.sh"
    local actual_hash
    [ -f "$source_installer" ] || fatal "$(msg "Instalador-base versionado não encontrado no repositório." "Versioned base installer was not found in this repository.")"
    mkdir -p "$SOURCE_DIR/templates"
    install -m 0700 "$source_installer" "$SOURCE_DIR/installer.sh"
    for template in xlx_log.service xlx_log.sh xlx_logrotate.conf apache.tbd.conf uninstaller.sh; do
        [ -f "$ROOT_DIR/vendor/pp5pk-installer/templates/$template" ] || fatal "$(msg "Template-base ausente: $template" "Base template is missing: $template")"
        install -m 0644 "$ROOT_DIR/vendor/pp5pk-installer/templates/$template" "$SOURCE_DIR/templates/$template"
    done
    actual_hash="$(sha256sum "$SOURCE_DIR/installer.sh" | awk '{print $1}')"
    [ "$actual_hash" = "$EXPECTED_INSTALLER_SHA256" ] || fatal "$(msg "SHA-256 do instalador-base divergente. Esperado=$EXPECTED_INSTALLER_SHA256 Obtido=$actual_hash" "Base installer SHA-256 mismatch. Expected=$EXPECTED_INSTALLER_SHA256 Got=$actual_hash")"
    bash -n "$SOURCE_DIR/installer.sh"
    find "$SOURCE_DIR/templates" -type f -name '*.sh' -exec bash -n {} \;
    ok "$(msg "Instalador-base local versionado e validado." "Versioned local base installer validated.")"
    info "$(msg "Fonte local: vendor/pp5pk-installer" "Local source: vendor/pp5pk-installer")"
    info "SHA-256: $actual_hash"
}

localize_base_installer() {
    local source="$SOURCE_DIR/installer.sh"
    local translated="$SOURCE_DIR/installer.runtime.sh"

    cp -- "$source" "$translated"
    local state_hook="$SOURCE_DIR/.xlx-modern-state-hook"
    cat > "$state_hook" <<'HOOK'
if [ -n "${XLX_MODERN_STATE_FILE:-}" ]; then
    {
        printf "REFLECTOR_NAME=%q\\n" "$XRFNUM"
        printf "REFLECTOR_TITLE=%q\\n" "$HEADER"
        printf "REFLECTOR_DESCRIPTION=%q\\n" "$COMMENT"
        printf "SYSOP_CALLSIGN=%q\\n" "$CALLSIGN"
        printf "COUNTRY=%q\\n" "$COUNTRY"
        printf "TIMEZONE=%q\\n" "$TIMEZONE"
        printf "DOMAIN=%q\\n" "$XLXDOMAIN"
        printf "CONTACT_EMAIL=%q\\n" "$EMAIL"
        printf "LOCATION=%q\\n" "${MODERN_LOCATION:-}"
        printf "YSF_ID=%q\\n" "${MODERN_YSF_ID:-}"
        printf "MODULE_COUNT=%q\\n" "$MODQTD"
        printf "ENABLE_HTTPS=%q\\n" "$INSTALL_SSL"
        printf "XLX_CONTROL_USERNAME=%q\\n" "${CONTROL_USERNAME:-}"
        printf "XLX_CONTROL_PASSWORD=%q\\n" "${CONTROL_PASSWORD:-}"
        printf "XLX_ADMIN_SLUG=%q\\n" "${ADMIN_SLUG:-admin}"
    } > "$XLX_MODERN_STATE_FILE"
    chmod 0600 "$XLX_MODERN_STATE_FILE"
fi
HOOK

    sed -i \
        -e '/center_wrap_color \$BLUE_BRIGHT "\$ICON_INFO UPDATING OS\.\.\."/r '"$state_hook" \
        -e '/center_wrap_color \$BLUE_BRIGHT "\$ICON_INFO INSTALLING DASHBOARD\.\.\."/,/^# SSL install$/ { /^# SSL install$/! s/^/# XLX_MODERN_SKIPPED: /; }' \
        -e 's|if \[ "\$INSTALL_SSL" == "Y" \]; then|if false; then # XLX Modern Dashboard configures TLS|' \
        -e '/^#  Starting users_db timer$/,/^#  Starting xlx_log service$/ { /^#  Starting xlx_log service$/! s/^/# XLX_MODERN_SKIPPED: /; }' \
        -e '/^# Check if update_db.sh file exist$/,/^# Check if echo service is running/ { /^# Check if echo service is running/! s/^/# XLX_MODERN_SKIPPED: /; }' \
        -e 's|\$XLXCONFIG|/xlxd/xlxd.cfg|g' \
        "$translated"
    rm -f "$state_hook"

    [ "$UI_LANG" = "pt-BR" ] || { chmod 700 "$translated"; printf '%s\n' "$translated"; return 0; }

    sed -i \
        -e 's|XLX MULTIPROTOCOL AMATEUR RADIO REFLECTOR INSTALLER PROGRAM|INSTALADOR DO REFLETOR XLX MULTIPROTOCOLO PARA RADIOAMADOR|' \
        -e 's|Next, you will be asked some questions\. Answer with the requested information or, if applicable, to accept the suggested value, press \[ENTER\]|A seguir, responda às perguntas. Quando houver um valor sugerido, pressione [ENTER] para aceitá-lo.|' \
        -e 's|At any prompt, type X and press \[ENTER\] to cancel the installation\.|Em qualquer pergunta, digite X e pressione [ENTER] para cancelar a instalação.|' \
        -e 's|REFLECTOR DATA INPUT|DADOS DO REFLETOR|' \
        -e 's|Mandatory|Obrigatório|g' \
        -e 's|01\. XLX Reflector ID, 3 alphanumeric characters\. (e\.g\., 300, US1, BRA)|01. ID do refletor XLX: 3 caracteres alfanuméricos. (ex.: 724, US1, BRA)|' \
        -e 's|02\. Dashboard FQDN (fully qualified domain name)\. (e\.g\., xlxbra\.net)|02. Domínio completo (FQDN) do painel. (ex.: xlx724.seudominio.net)|' \
        -e 's|03\. Sysop e-mail address|03. E-mail do sysop|' \
        -e 's|04\. Sysop callsign\. Only letters and numbers allowed, max 6 characters\.|04. Indicativo do sysop. Use letras e números, máximo de 6 caracteres.|' \
        -e 's|05\. Reflector country name\.|05. Nome do país do refletor.|' \
        -e 's|06\. Local timezone\. Detected:|06. Fuso horário local. Detectado:|' \
        -e 's|Press ENTER to keep it or type another timezone\.|Pressione ENTER para manter ou informe outro fuso horário.|' \
        -e 's|06\. What is the local timezone? (e\.g\., America/Sao_Paulo, UTC, GMT-3)|06. Qual é o fuso horário local? (ex.: America/Sao_Paulo, UTC, GMT-3)|' \
        -e 's|07\. Comment to XLX Reflectors list\.|07. Comentário para a lista de refletores XLX.|' \
        -e 's|08\. Custom text for the dashboard tab\. (max 25 characters)|08. Texto personalizado para a aba do painel. (máximo: 25 caracteres)|' \
        -e 's|09\. Custom text on footer of the dashboard webpage\.|09. Texto personalizado no rodapé do painel.|' \
        -e 's|10\. Create an SSL certificate (https) for the dashboard webpage? (Y/N)|10. Criar certificado SSL (HTTPS) para o painel? (S/N)|' \
        -e 's|11\. Install Echo Test on module E? (Y/N)|11. Instalar Echo Test no módulo E? (S/N)|' \
        -e 's|12\. Number of active modules for the DStar Reflector\.|12. Quantidade de módulos ativos para o refletor D-STAR.|' \
        -e 's|13\. YSF Reflector UDP port number\. (1-65535)|13. Porta UDP do refletor YSF. (1-65535)|' \
        -e 's|14\. YSF Wires-X frequency\. In Hertz, 9 digits\.|14. Frequência YSF Wires-X, em Hertz, 9 dígitos.|' \
        -e 's|15\. Auto-link YSF to a module? (Y/N)|15. Vincular YSF automaticamente a um módulo? (S/N)|' \
        -e 's|16\. Module to Auto-link YSF\.|16. Módulo para vínculo automático do YSF.|' \
        -e 's|17\. City and state/region shown on the dashboard\.|17. Cidade e estado/região exibidos no painel.|' \
        -e 's|18\. YSF reflector ID shown on the dashboard\. (1-8 digits)|18. ID do refletor YSF exibido no painel. (1-8 dígitos)|' \
        -e 's|19\. Private Admin username\. (3-64 characters)|19. Usuário do Admin privado. (3-64 caracteres)|' \
        -e 's|20\. Private Admin URL name\.|20. Nome da URL privada do Admin.|' \
        -e 's|21\. Private Admin password\. (minimum 8 characters)|21. Senha do Admin privado. (mínimo 8 caracteres)|' \
        -e 's|Repeat password:|Repita a senha:|' \
        -e 's|password defined (not displayed)|senha definida (não exibida)|g' \
        -e 's|City / region:|Cidade / região:|' \
        -e 's|Admin username:|Usuário Admin:|' \
        -e 's|Admin password:|Senha Admin:|' \
        -e 's|PLEASE REVIEW YOUR SETTINGS:|REVISE AS CONFIGURAÇÕES:|' \
        -e 's|Settings correct? Press \[ENTER\] to confirm, type a question number to edit it, or \[X\] to cancel the installation\.|Configurações corretas? Pressione [ENTER] para confirmar, informe o número para editar ou [X] para cancelar.|' \
        "$translated"
    chmod 700 "$translated"
    printf '%s\n' "$translated"
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
10. Provision and validate the native APRS/D-PRS backend.

Current choices:
- Mode: $MODE
- Dashboard language: $dash_lang
- Dashboard directory: $DEFAULT_DASHBOARD_DIR
- APRS/D-PRS: native and mandatory / nativo e obrigatório

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
10. Provisionar e validar o backend APRS/D-PRS nativo.

Escolhas atuais:
- Modo: $MODE
- Idioma do dashboard: $dash_lang
- Diretório do dashboard: $DEFAULT_DASHBOARD_DIR
- APRS/D-PRS: native and mandatory / nativo e obrigatório

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
    if [ "$CHECK_READY" = "yes" ]; then
        ok "$(msg "Pré-requisitos, rede e HTTPS validados." "Prerequisites, network, and HTTPS validated.")"
    else
        ok "$(msg "Servidor compatível. Os pré-requisitos pendentes serão instalados automaticamente na instalação real." "Server is compatible. Pending prerequisites will be installed automatically during the real installation.")"
    fi
    ok "$(msg "Nenhuma instalação ativa será sobrescrita." "No active installation will be overwritten.")"
    ok "$(msg "Commit e SHA-256 confirmados." "Commit and SHA-256 verified.")"

    section "$(msg "PRÉ-VALIDAÇÃO APRS/D-PRS NATIVO" "NATIVE APRS/D-PRS PRE-CHECK")"
    bash "$ROOT_DIR/modules/67-aprs-dprs.sh" --check
    bash "$ROOT_DIR/modules/71-observability.sh" --check

    info "$(msg "Verificação concluída sem erro bloqueante. Para instalar agora, execute: bash install.sh" "Check completed with no blocking error. To install now, run: bash install.sh")"
}

run_dashboard_only_check() {
    section "$(msg "RESULTADO DA VERIFICAÇÃO DO PAINEL" "DASHBOARD UPDATE CHECK RESULT")"
    [ -x /xlxd/xlxd ] || fatal "$(msg "XLXD não encontrado em /xlxd/xlxd." "XLXD was not found at /xlxd/xlxd.")"
    ok "$(msg "XLXD existente encontrado; ele não será reinstalado." "Existing XLXD found; it will not be reinstalled.")"
    if [ -d "$DEFAULT_DASHBOARD_DIR" ]; then
        ok "$(msg "Painel atual encontrado em $DEFAULT_DASHBOARD_DIR." "Current dashboard found at $DEFAULT_DASHBOARD_DIR.")"
    else
        info "$(msg "O painel moderno será instalado em $DEFAULT_DASHBOARD_DIR." "The modern dashboard will be installed at $DEFAULT_DASHBOARD_DIR.")"
    fi
    info "$(msg "Nenhuma alteração foi feita." "No changes were made.")"
}

execute_dashboard_only() {
    local dashboard_dest="$DEFAULT_DASHBOARD_DIR"
    section "$(msg "ATUALIZANDO SOMENTE O PAINEL MODERNO" "UPDATING ONLY THE MODERN DASHBOARD")"
    info "$(msg "O XLXD existente será preservado; apenas o painel e seus componentes públicos serão atualizados." "The existing XLXD will be preserved; only the dashboard and its public components will be updated.")"
    if [ -n "$DASHBOARD_LANG" ]; then
        INSTALL_DIR="$dashboard_dest" XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/60-dashboard-modern.sh" "--lang=$DASHBOARD_LANG"
    else
        INSTALL_DIR="$dashboard_dest" XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/60-dashboard-modern.sh"
    fi
    for required_file in "$dashboard_dest/index.php" "$dashboard_dest/config/site.php" "$dashboard_dest/api/status.php" "$dashboard_dest/api/live.php"; do
        [ -s "$required_file" ] || fatal "$(msg "Arquivo obrigatório do painel ausente após atualização: $required_file" "Required dashboard file missing after update: $required_file")"
    done
    systemctl is-active --quiet xlxd || fatal "$(msg "XLXD não está ativo após a atualização do painel; o núcleo não foi reinstalado. Consulte os logs antes de continuar." "XLXD is not active after the dashboard update; the core was not reinstalled. Check the logs before continuing.")"
    section "$(msg "ATUALIZAÇÃO DO PAINEL CONCLUÍDA" "DASHBOARD UPDATE COMPLETE")"
    ok "$(msg "Painel moderno validado e XLXD preservado." "Modern dashboard validated and XLXD preserved.")"
}

execute_installer() {
    local stamp logfile installer_rc failures service dashboard_dest state_file
    stamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_ROOT"; chmod 700 "$LOG_ROOT"
    logfile="${LOG_ROOT}/install_${stamp}.log"
    section "$(msg "INICIANDO XLX MODERN INSTALLER" "STARTING XLX MODERN INSTALLER")"
    info "$(msg "Log da instalação: $logfile" "Installation log: $logfile")"
    info "$(msg "A próxima tela pertence ao instalador base e solicitará os dados do refletor." "The next screen is the base installer and will ask for reflector information.")"
    local base_installer
    base_installer="$(localize_base_installer)"
    cd "$SOURCE_DIR"
    info "$(msg "Usando o fluxo de perguntas em Português (Brasil)." "Using the English question flow.")"
    state_file="${WORK_ROOT}/runtime/install-input.env"
    install -d -m 0700 "$(dirname "$state_file")"
    : > "$state_file"
    chmod 0600 "$state_file"

    set +e
    XLX_MODERN_STATE_FILE="$state_file" bash "$base_installer" 2>&1 | tee -a "$logfile"
    installer_rc=${PIPESTATUS[0]}
    set -e
    [ "$installer_rc" -eq 0 ] || fatal "$(msg "O instalador base terminou com código $installer_rc. Consulte o log: $logfile" "The base installer exited with code $installer_rc. Check the log: $logfile")"

    source "$state_file"
    export XLX_CONTROL_USERNAME XLX_CONTROL_PASSWORD XLX_ADMIN_SLUG
    [ -n "${DOMAIN:-}" ] || fatal "$(msg "O instalador base não gravou o domínio para validação final." "The base installer did not save the domain for final validation.")"

    section "$(msg "INSTALANDO XLX MODERN DASHBOARD" "INSTALLING XLX MODERN DASHBOARD")"
    if [ -n "$DASHBOARD_LANG" ]; then
        XLX_INSTALL_STATE_FILE="$state_file" XLX_UI_LANG="$UI_LANG" XLX_CONTROL_USERNAME="$XLX_CONTROL_USERNAME" XLX_CONTROL_PASSWORD="$XLX_CONTROL_PASSWORD" XLX_ADMIN_SLUG="$XLX_ADMIN_SLUG" bash "$ROOT_DIR/modules/60-dashboard-modern.sh" "--lang=$DASHBOARD_LANG"
    else
        XLX_INSTALL_STATE_FILE="$state_file" XLX_UI_LANG="$UI_LANG" XLX_CONTROL_USERNAME="$XLX_CONTROL_USERNAME" XLX_CONTROL_PASSWORD="$XLX_CONTROL_PASSWORD" XLX_ADMIN_SLUG="$XLX_ADMIN_SLUG" bash "$ROOT_DIR/modules/60-dashboard-modern.sh"
    fi

    dashboard_dest="${INSTALL_DIR:-$DEFAULT_DASHBOARD_DIR}"
    section "$(msg "PROVISIONANDO APRS/D-PRS NATIVO" "PROVISIONING NATIVE APRS/D-PRS")"
    XLX_DASHBOARD_DIR="$dashboard_dest" XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/67-aprs-dprs.sh" "--dashboard-dir=$dashboard_dest"
    XLX_DASHBOARD_DIR="$dashboard_dest" XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/71-observability.sh" "--dashboard-dir=$dashboard_dest"

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

    for required_file in "$dashboard_dest/index.php" "$dashboard_dest/config/site.php" "$dashboard_dest/api/status.php" "$dashboard_dest/api/live.php"; do
        if [ -s "$required_file" ]; then
            ok "$(msg "Arquivo obrigatório do painel encontrado: $required_file" "Required dashboard file found: $required_file")"
        else
            warn "$(msg "Arquivo obrigatório do painel ausente: $required_file" "Required dashboard file missing: $required_file")"
            failures=$((failures + 1))
        fi
    done
    if [ -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ] && grep -Fq "DocumentRoot $dashboard_dest" "/etc/apache2/sites-enabled/$DOMAIN.conf"; then
        ok "$(msg "VirtualHost do painel moderno confirmado." "Modern dashboard VirtualHost confirmed.")"
    else
        warn "$(msg "VirtualHost do painel moderno não aponta para $dashboard_dest." "Modern dashboard VirtualHost does not point to $dashboard_dest.")"
        failures=$((failures + 1))
    fi
    if systemctl is-active --quiet xlx-callinghome.timer; then
        ok "$(msg "Timer CallingHome ativo." "CallingHome timer is active.")"
    else
        warn "$(msg "Timer CallingHome inativo." "CallingHome timer is inactive.")"
        failures=$((failures + 1))
    fi

    local dashboard_scheme="http"
    local https_requested=0
    case "${ENABLE_HTTPS:-}" in Y|y|yes|YES) https_requested=1 ;; esac
    if [ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        dashboard_scheme="https"
        ok "$(msg "Certificado HTTPS encontrado para $DOMAIN." "HTTPS certificate found for $DOMAIN.")"
    elif [ "$https_requested" -eq 1 ]; then
        warn "$(msg "HTTPS foi solicitado, mas o certificado ainda está pendente. O painel continuará disponível em HTTP e a instalação não será descartada." "HTTPS was requested, but the certificate is still pending. The dashboard remains available over HTTP and the installation will not be discarded.")"
        info "$(msg "Nova tentativa: xlx-modern-https-retry $DOMAIN $CONTACT_EMAIL" "Retry: xlx-modern-https-retry $DOMAIN $CONTACT_EMAIL")"
    fi
    local dashboard_port="80"
    [ "$dashboard_scheme" = "https" ] && dashboard_port="443"
    if curl --noproxy '*' -fsS --max-time 15 --resolve "$DOMAIN:$dashboard_port:127.0.0.1" "$dashboard_scheme://$DOMAIN/" >/dev/null; then
        ok "$(msg "Painel respondeu localmente por $dashboard_scheme." "Dashboard responded locally over $dashboard_scheme.")"
    else
        warn "$(msg "O painel não respondeu localmente por $dashboard_scheme." "Dashboard did not respond locally over $dashboard_scheme.")"
        failures=$((failures + 1))
    fi

    # End-to-end readiness: do not announce completion unless the actual
    # installed dashboard and native subsystems are reachable/active.
    local base_url="$dashboard_scheme://$DOMAIN"
    local resolve_opt=(--resolve "$DOMAIN:$dashboard_port:127.0.0.1")
    for page in 'ao-vivo' 'conectados' 'modulos' 'digital-lab' 'certificado'; do
        if curl --noproxy '*' -fsS --max-time 15 "${resolve_opt[@]}" "$base_url/?page=$page" >/dev/null; then
            ok "$(msg "Rota do painel pronta: $page" "Dashboard route ready: $page")"
        else
            warn "$(msg "Rota do painel falhou: $page" "Dashboard route failed: $page")"
            failures=$((failures + 1))
        fi
    done
    for api in 'api/status.php' 'api/live.php' 'api/digital-lab.php'; do
        if curl --noproxy '*' -fsS --max-time 15 "${resolve_opt[@]}" "$base_url/$api" >/dev/null; then
            ok "$(msg "API pronta: $api" "API ready: $api")"
        else
            warn "$(msg "API falhou: $api" "API failed: $api")"
            failures=$((failures + 1))
        fi
    done
    for svc in xlx-aprs-dprs.service xlx-modern-health-monitor.service; do
        if systemctl is-active --quiet "$svc"; then
            ok "$(msg "Serviço ativo: $svc" "Service active: $svc")"
        else
            warn "$(msg "Serviço inativo: $svc" "Service inactive: $svc")"
            failures=$((failures + 1))
        fi
    done
    if [ -n "${XLX_ADMIN_SLUG:-}" ] && [ -f "$dashboard_dest/${XLX_ADMIN_SLUG}/index.php" ]; then
        ok "$(msg "Admin privado instalado em /${XLX_ADMIN_SLUG}/" "Private Admin installed at /${XLX_ADMIN_SLUG}/")"
    else
        warn "$(msg "Admin privado não foi encontrado na URL configurada." "Private Admin was not found at the configured URL.")"
        failures=$((failures + 1))
    fi

    if [ "$failures" -ne 0 ]; then
        fatal "$(msg "A instalação terminou, mas $failures validação(ões) falharam. Não considere o servidor pronto. Consulte: $logfile" "Installation finished, but $failures validation check(s) failed. Do not consider the server ready. Check: $logfile")"
    fi

    section "$(msg "INSTALAÇÃO CONCLUÍDA" "INSTALLATION COMPLETE")"
    ok "$(msg "XLX instalado e validações essenciais aprovadas." "XLX installed and essential validation checks passed.")"
    info "$(msg "URL disponível agora: $dashboard_scheme://$DOMAIN" "Available URL now: $dashboard_scheme://$DOMAIN")"
    if [ "$dashboard_scheme" = "http" ] && [ -f /var/lib/xlx-modern/https-status ]; then
        retry_at="$(sed -n 's/^retry_at_utc=//p' /var/lib/xlx-modern/https-status | tail -1)"
        if [ -n "$retry_at" ]; then
            info "$(msg "HTTPS será tentado automaticamente após: $retry_at" "HTTPS will be retried automatically after: $retry_at")"
        fi
    fi
    info "$(msg "Dashboard: $dashboard_dest" "Dashboard: $dashboard_dest")"
    info "$(msg "Log: $logfile" "Log: $logfile")"
    warn "$(msg "Refletor novo: ele pode não aparecer imediatamente nas listas públicas de hotspots. Cadastre-o em https://dvref.com/ e aguarde a propagação antes de testar pela lista pública." "New reflector: it may not appear immediately in public hotspot lists. Register it at https://dvref.com/ and allow propagation before testing through a public list.")"
}

main() {
    clear 2>/dev/null || true
    validate_options
    require_root
    select_ui_language
    select_dashboard_language
    section "XLX MODERN INSTALLER — PU2PNY"
    validate_os
    bootstrap_install_prerequisites
    validate_commands
    validate_resources
    validate_network
    detect_existing_installation
    if [ "$DASHBOARD_ONLY" = "yes" ]; then
        if [ "$MODE" = "check" ]; then
            run_dashboard_only_check
            exit 0
        fi
        create_inventory_and_backup
        execute_dashboard_only
        exit 0
    fi
    prepare_source
    show_plan
    if [ "$MODE" = "check" ]; then run_check; exit 0; fi
    create_inventory_and_backup
    execute_installer
}

main "$@"
