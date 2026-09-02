#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_ROOT="/opt/xlx-modern-installer"
readonly BACKUP_ROOT="/var/backups/xlx-reflector"
readonly LOG_ROOT="/var/log/xlx-reflector/installer"
readonly CONFIRMATION="INSTALL"
readonly DEFAULT_DASHBOARD_DIR="/var/www/html/xlxd"

MODE="install"
ALLOW_REMNANTS="no"
DASHBOARD_ONLY="no"
DASHBOARD_LANG=""
UI_LANG="pt-BR"
APRS_DPRS_MODE="ask"

REFLECTOR_NAME=""
REFLECTOR_TITLE=""
REFLECTOR_DESCRIPTION=""
SYSOP_CALLSIGN=""
LOCATION=""
COUNTRY=""
DOMAIN=""
CONTACT_EMAIL=""
TIMEZONE=""
YSF_ID=""
MODULE_COUNT="5"
ENABLE_HTTPS="yes"
ENABLE_ECHO="yes"
ECHO_MODULE="E"
YSF_PORT="42000"
YSF_FREQUENCY="433125000"
YSF_AUTOLINK="1"
YSF_AUTOLINK_MODULE="C"
LISTEN_IP=""
PUBLIC_IP=""

for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) MODE="check" ;;
    --dashboard-only) DASHBOARD_ONLY="yes" ;;
    --allow-remnants|--force-clean) ALLOW_REMNANTS="yes" ;;
    --lang=*) DASHBOARD_LANG="${arg#*=}" ;;
    --with-aprs-dprs) APRS_DPRS_MODE="yes" ;;
    --without-aprs-dprs) APRS_DPRS_MODE="no" ;;
    -h|--help)
      cat <<'HELP'
XLX Modern Installer — independent installation

Usage / Uso:
  sudo bash install.sh --check
  sudo bash install.sh
  sudo bash install.sh --lang=en
  sudo bash install.sh --dashboard-only
  sudo bash install.sh --with-aprs-dprs

Options / Opções:
  --check               Read-only compatibility check.
  --dashboard-only      Install/update only the Modern Dashboard on an existing XLXD.
  --lang=CODE           Dashboard language: pt-BR | en | es | fr | de | it.
  --with-aprs-dprs      Install the optional APRS/D-PRS module.
  --without-aprs-dprs   Skip APRS/D-PRS.
  --allow-remnants      Allow inactive remnants after preventive backup.
HELP
      exit 0
      ;;
    *) printf 'ERRO / ERROR: opção desconhecida / unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

case "$DASHBOARD_LANG" in en) UI_LANG="en" ;; esac
export XLX_UI_LANG="$UI_LANG"

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
msg(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s%s%s %s\n' "$YELLOW" "$(msg '[ATENÇÃO]' '[WARNING]')" "$RESET" "$*"; }
fatal(){ printf '%s%s%s %s\n' "$RED" "$(msg '[ERRO]' '[ERROR]')" "$RESET" "$*" >&2; exit 1; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$*"; }

validate_options(){
  case "$DASHBOARD_LANG" in ""|pt-BR|en|es|fr|de|it) ;; *) fatal "$(msg "Idioma inválido: $DASHBOARD_LANG" "Invalid language: $DASHBOARD_LANG")" ;; esac
}
require_root(){ [[ "$(id -u)" -eq 0 ]] || fatal "$(msg 'Execute como root.' 'Run as root.')"; }

select_ui_language(){
  [[ -n "$DASHBOARD_LANG" || ! -t 0 ]] && return 0
  section 'XLX MODERN INSTALLER — PU2PNY'
  printf 'Selecione o idioma / Select language:\n  1) Português (Brasil) [padrão]\n  2) English\n'
  local choice
  while :; do
    printf 'Opção / Option [1]: '
    read -r choice || choice=""
    case "${choice,,}" in
      ""|1|pt|pt-br|p) UI_LANG="pt-BR"; break ;;
      2|en|e|english) UI_LANG="en"; break ;;
      *) warn 'Opção inválida. Digite 1 ou 2. / Invalid option. Type 1 or 2.' ;;
    esac
  done
  export XLX_UI_LANG="$UI_LANG"
}

select_dashboard_language(){
  [[ -n "$DASHBOARD_LANG" ]] && return 0
  if [[ ! -t 0 ]]; then DASHBOARD_LANG="$UI_LANG"; return 0; fi
  local choice default=1
  [[ "$UI_LANG" == en ]] && default=2
  section "$(msg 'IDIOMA DO PAINEL' 'DASHBOARD LANGUAGE')"
  printf '  1) Português (Brasil)\n  2) English\n  3) Español\n  4) Français\n  5) Deutsch\n  6) Italiano\n'
  while :; do
    printf '%s' "$(msg "Escolha [$default]: " "Choose [$default]: ")"
    read -r choice || choice=""
    choice="${choice:-$default}"
    case "$choice" in
      1) DASHBOARD_LANG=pt-BR ;;
      2) DASHBOARD_LANG=en ;;
      3) DASHBOARD_LANG=es ;;
      4) DASHBOARD_LANG=fr ;;
      5) DASHBOARD_LANG=de ;;
      6) DASHBOARD_LANG=it ;;
      *) warn "$(msg 'Opção inválida.' 'Invalid option.')"; continue ;;
    esac
    break
  done
}

bootstrap_prerequisites(){
  local needed=() cmd
  for cmd in curl git rsync sqlite3; do
    command -v "$cmd" >/dev/null 2>&1 || needed+=("$cmd")
  done
  [[ ${#needed[@]} -eq 0 ]] && return 0
  if [[ "$MODE" == check ]]; then
    info "$(msg "Pré-requisitos pendentes: ${needed[*]}. A instalação real os instalará automaticamente." "Pending prerequisites: ${needed[*]}. The real installation will install them automatically.")"
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates "${needed[@]}"
}

validate_os(){
  [[ -r /etc/os-release ]] || fatal "$(msg '/etc/os-release ausente.' '/etc/os-release is missing.')"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == debian && "${VERSION_ID:-}" == 12 ]] || fatal "$(msg 'Use Debian 12.' 'Use Debian 12.')"
  [[ "$(uname -m)" == x86_64 ]] || fatal "$(msg 'Use arquitetura x86_64.' 'Use x86_64 architecture.')"
  ok 'Debian 12 x86_64'
}

validate_resources(){
  local mem disk
  mem="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
  disk="$(df -Pm / | awk 'NR==2 {print $4}')"
  [[ "$mem" -ge 768 ]] || fatal "$(msg 'RAM disponível menor que 768 MB.' 'Available RAM is below 768 MB.')"
  [[ "$disk" -ge 4096 ]] || fatal "$(msg 'Espaço livre menor que 4 GB.' 'Free disk space is below 4 GB.')"
  info "RAM=${mem}MB | free_disk=${disk}MB"
}

validate_network(){
  getent hosts github.com >/dev/null 2>&1 || fatal "$(msg 'Falha DNS para github.com.' 'DNS failure for github.com.')"
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsSI --connect-timeout 10 https://github.com/ >/dev/null || fatal "$(msg 'Sem HTTPS para GitHub.' 'GitHub HTTPS is unreachable.')"
}

validate_independent_sources(){
  [[ -f "$ROOT_DIR/modules/40-xlxd.sh" ]] || fatal "$(msg 'Módulo próprio do XLXD ausente.' 'Own XLXD module is missing.')"
  [[ -f "$ROOT_DIR/modules/50-echo.sh" ]] || fatal "$(msg 'Módulo próprio de Echo ausente.' 'Own Echo module is missing.')"
  [[ -f "$ROOT_DIR/dashboard/index.php" && -f "$ROOT_DIR/dashboard/install/install-dashboard.sh" ]] || fatal "$(msg 'Dashboard local incompleto.' 'Local dashboard is incomplete.')"
  grep -Fq 'https://github.com/LX3JL/xlxd.git' "$ROOT_DIR/modules/40-xlxd.sh" || fatal "$(msg 'Fonte independente do XLXD não está configurada.' 'Independent XLXD source is not configured.')"
  grep -Fq 'https://github.com/narspt/XLXEcho.git' "$ROOT_DIR/modules/50-echo.sh" || fatal "$(msg 'Fonte independente do Echo não está configurada.' 'Independent Echo source is not configured.')"
  bash "$ROOT_DIR/tests/test-no-external-installer.sh" >/dev/null || fatal "$(msg 'A auditoria de independência do repositório falhou.' 'Repository independence audit failed.')"
  ok "$(msg 'Instalação independente validada: núcleo e painel não usam outro instalador.' 'Independent installation validated: core and dashboard do not use another installer.')"
}

detect_existing_installation(){
  local detected=0
  [[ -x /xlxd/xlxd ]] && detected=1
  systemctl is-active --quiet xlxd.service 2>/dev/null && detected=1 || true
  [[ -e /var/www/html/xlxd ]] && detected=1
  if [[ "$detected" -eq 1 ]]; then
    if [[ "$DASHBOARD_ONLY" == yes ]]; then
      [[ -x /xlxd/xlxd ]] || fatal "$(msg 'Modo somente painel exige /xlxd/xlxd existente.' 'Dashboard-only mode requires an existing /xlxd/xlxd.')"
      ok "$(msg 'XLXD existente confirmado; o núcleo será preservado.' 'Existing XLXD confirmed; the core will be preserved.')"
      return 0
    fi
    fatal "$(msg 'Instalação XLX ativa detectada. Use --dashboard-only para preservar o núcleo.' 'Active XLX installation detected. Use --dashboard-only to preserve the core.')"
  fi
  if [[ -d /xlxd || -d /usr/src/xlxd || -d /usr/src/XLXEcho ]]; then
    [[ "$ALLOW_REMNANTS" == yes ]] || fatal "$(msg 'Vestígios de instalação encontrados. Revise-os ou use --allow-remnants.' 'Installation remnants found. Review them or use --allow-remnants.')"
  fi
}

create_inventory_and_backup(){
  local stamp backup manifest path
  stamp="$(date +%Y%m%d_%H%M%S)"
  backup="$BACKUP_ROOT/$stamp"
  manifest="$backup/manifest.txt"
  install -d -m 0700 "$backup"
  : > "$manifest"
  for path in \
    /etc/apache2 \
    /etc/systemd/system \
    /var/www/html/xlxd \
    /xlxd \
    /usr/src/xlxd \
    /usr/src/XLXEcho \
    /etc/xlx-modern-control \
    /etc/xlx-modern
  do
    [[ ! -e "$path" ]] || printf '%s\n' "$path" >> "$manifest"
  done
  if [[ -s "$manifest" ]]; then
    tar --one-file-system --ignore-failed-read -czpf "$backup/pre-installation.tar.gz" -T "$manifest"
    sha256sum "$backup/pre-installation.tar.gz" > "$backup/pre-installation.tar.gz.sha256"
    sha256sum -c "$backup/pre-installation.tar.gz.sha256" >/dev/null
    ok "$(msg 'Backup preventivo verificado:' 'Verified preventive backup:') $backup/pre-installation.tar.gz"
  else
    info "$(msg 'Servidor limpo: nenhum caminho existente exigiu backup preventivo.' 'Clean server: no existing path required a preventive backup.')"
  fi
}

read_nonempty(){
  local var="$1" prompt_pt="$2" prompt_en="$3" value=""
  while [[ -z "$value" ]]; do
    printf '%s' "$(msg "$prompt_pt" "$prompt_en")"
    read -r value || value=""
  done
  printf -v "$var" '%s' "$value"
}

ask_yes_no(){
  local var="$1" prompt_pt="$2" prompt_en="$3" default_yes="${4:-yes}" ans
  while :; do
    if [[ "$default_yes" == yes ]]; then
      printf '%s' "$(msg "$prompt_pt [S/n]: " "$prompt_en [Y/n]: ")"
    else
      printf '%s' "$(msg "$prompt_pt [s/N]: " "$prompt_en [y/N]: ")"
    fi
    read -r ans || ans=""
    if [[ -z "$ans" ]]; then
      [[ "$default_yes" == yes ]] && printf -v "$var" yes || printf -v "$var" no
      return
    fi
    case "${ans,,}" in
      s|sim|y|yes) printf -v "$var" yes; return ;;
      n|nao|não|no) printf -v "$var" no; return ;;
      *) warn "$(msg 'Responda S ou N.' 'Answer Y or N.')" ;;
    esac
  done
}

detect_ips(){
  LISTEN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
  [[ -n "$LISTEN_IP" ]] || LISTEN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [[ -n "$LISTEN_IP" ]] || LISTEN_IP=127.0.0.1
  PUBLIC_IP="$(curl -m 5 -fsS https://v4.ident.me 2>/dev/null || curl -m 5 -fsS https://api4.ipify.org 2>/dev/null || true)"
  info "$(msg "IP de escuta: $LISTEN_IP" "Listen IP: $LISTEN_IP")"
  if [[ -n "$PUBLIC_IP" ]]; then
    info "$(msg "IP público detectado: $PUBLIC_IP" "Detected public IP: $PUBLIC_IP")"
  else
    warn "$(msg 'IP público não pôde ser detectado; xlxd.terminal ficará sem address explícito.' 'Public IP could not be detected; xlxd.terminal will keep no explicit address.')"
  fi
}

collect_configuration(){
  [[ "$MODE" == install ]] || return 0
  [[ -t 0 ]] || fatal "$(msg 'A instalação completa exige terminal interativo.' 'Full installation requires an interactive terminal.')"

  section "$(msg 'CONFIGURAÇÃO DO REFLETOR' 'REFLECTOR CONFIGURATION')"
  local suffix current_tz tz value idx min_modules alink

  while :; do
    printf '%s' "$(msg 'Número XLX, 3 dígitos (ex.: 724): ' 'XLX number, 3 digits (example: 724): ')"
    read -r suffix || suffix=""
    [[ "$suffix" =~ ^[0-9]{3}$ ]] && break
    warn "$(msg 'Use exatamente 3 dígitos.' 'Use exactly 3 digits.')"
  done
  REFLECTOR_NAME="XLX$suffix"

  while :; do
    printf '%s' "$(msg 'Domínio/FQDN do painel: ' 'Dashboard FQDN: ')"
    read -r DOMAIN || DOMAIN=""
    DOMAIN="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]')"
    [[ "$DOMAIN" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]] && break
    warn "$(msg 'Domínio inválido.' 'Invalid domain.')"
  done

  while :; do
    printf '%s' "$(msg 'E-mail do sysop: ' 'Sysop e-mail: ')"
    read -r CONTACT_EMAIL || CONTACT_EMAIL=""
    CONTACT_EMAIL="$(printf '%s' "$CONTACT_EMAIL" | tr '[:upper:]' '[:lower:]')"
    [[ "$CONTACT_EMAIL" =~ ^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$ ]] && break
    warn "$(msg 'E-mail inválido.' 'Invalid e-mail.')"
  done

  while :; do
    printf '%s' "$(msg 'Indicativo do sysop: ' 'Sysop callsign: ')"
    read -r SYSOP_CALLSIGN || SYSOP_CALLSIGN=""
    SYSOP_CALLSIGN="${SYSOP_CALLSIGN^^}"
    [[ "$SYSOP_CALLSIGN" =~ ^[A-Z0-9]{3,8}$ ]] && break
    warn "$(msg 'Indicativo inválido.' 'Invalid callsign.')"
  done

  read_nonempty COUNTRY 'País: ' 'Country: '
  read_nonempty LOCATION 'Cidade e estado/região: ' 'City and state/region: '

  current_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || echo UTC)"
  while :; do
    printf '%s' "$(msg "Fuso horário [$current_tz]: " "Timezone [$current_tz]: ")"
    read -r tz || tz=""
    tz="${tz:-$current_tz}"
    if timedatectl list-timezones 2>/dev/null | grep -iFx "$tz" >/dev/null; then
      TIMEZONE="$(timedatectl list-timezones | grep -iFx "$tz" | head -1)"
      break
    fi
    [[ "$tz" == UTC ]] && { TIMEZONE=UTC; break; }
    warn "$(msg 'Fuso inválido.' 'Invalid timezone.')"
  done

  REFLECTOR_TITLE="$REFLECTOR_NAME by $SYSOP_CALLSIGN"
  REFLECTOR_DESCRIPTION="$REFLECTOR_NAME Multiprotocol Reflector by $SYSOP_CALLSIGN"
  printf '%s' "$(msg "Nome exibido [$REFLECTOR_TITLE]: " "Displayed name [$REFLECTOR_TITLE]: ")"
  read -r value || value=""
  [[ -n "$value" ]] && REFLECTOR_TITLE="$value"
  value=""
  printf '%s' "$(msg "Descrição [$REFLECTOR_DESCRIPTION]: " "Description [$REFLECTOR_DESCRIPTION]: ")"
  read -r value || value=""
  [[ -n "$value" ]] && REFLECTOR_DESCRIPTION="$value"

  ask_yes_no ENABLE_HTTPS 'Ativar HTTPS com Let’s Encrypt?' 'Enable HTTPS with Let’s Encrypt?' yes
  ask_yes_no ENABLE_ECHO 'Instalar Echo/Parrot no módulo E?' 'Install Echo/Parrot on module E?' yes

  min_modules=1
  [[ "$ENABLE_ECHO" == yes ]] && min_modules=5
  while :; do
    printf '%s' "$(msg "Quantidade de módulos ($min_modules-26) [5]: " "Number of modules ($min_modules-26) [5]: ")"
    read -r MODULE_COUNT || MODULE_COUNT=""
    MODULE_COUNT="${MODULE_COUNT:-5}"
    [[ "$MODULE_COUNT" =~ ^[0-9]+$ && "$MODULE_COUNT" -ge "$min_modules" && "$MODULE_COUNT" -le 26 ]] && break
    warn "$(msg 'Quantidade inválida.' 'Invalid module count.')"
  done

  while :; do
    printf '%s' "$(msg 'Porta UDP YSF [42000]: ' 'YSF UDP port [42000]: ')"
    read -r YSF_PORT || YSF_PORT=""
    YSF_PORT="${YSF_PORT:-42000}"
    [[ "$YSF_PORT" =~ ^[0-9]+$ && "$YSF_PORT" -ge 1 && "$YSF_PORT" -le 65535 ]] && break
    warn "$(msg 'Porta inválida.' 'Invalid port.')"
  done

  while :; do
    printf '%s' "$(msg 'Frequência YSF em Hz [433125000]: ' 'YSF frequency in Hz [433125000]: ')"
    read -r YSF_FREQUENCY || YSF_FREQUENCY=""
    YSF_FREQUENCY="${YSF_FREQUENCY:-433125000}"
    [[ "$YSF_FREQUENCY" =~ ^[0-9]{9}$ ]] && break
    warn "$(msg 'Use exatamente 9 dígitos.' 'Use exactly 9 digits.')"
  done

  ask_yes_no alink 'Ativar auto-link YSF?' 'Enable YSF auto-link?' yes
  [[ "$alink" == yes ]] && YSF_AUTOLINK=1 || YSF_AUTOLINK=0
  if [[ "$YSF_AUTOLINK" == 1 ]]; then
    while :; do
      printf '%s' "$(msg 'Módulo de auto-link YSF [C]: ' 'YSF auto-link module [C]: ')"
      read -r YSF_AUTOLINK_MODULE || YSF_AUTOLINK_MODULE=""
      YSF_AUTOLINK_MODULE="${YSF_AUTOLINK_MODULE:-C}"
      YSF_AUTOLINK_MODULE="${YSF_AUTOLINK_MODULE^^}"
      [[ "$YSF_AUTOLINK_MODULE" =~ ^[A-Z]$ ]] || { warn "$(msg 'Módulo inválido.' 'Invalid module.')"; continue; }
      idx=$(( $(printf '%d' "'$YSF_AUTOLINK_MODULE") - 64 ))
      [[ "$idx" -ge 1 && "$idx" -le "$MODULE_COUNT" ]] && break
      warn "$(msg 'Módulo fora da faixa configurada.' 'Module is outside configured range.')"
    done
  fi

  while :; do
    printf '%s' "$(msg 'ID numérico YSF exibido no painel: ' 'Numeric YSF ID shown on dashboard: ')"
    read -r YSF_ID || YSF_ID=""
    [[ "$YSF_ID" =~ ^[0-9]{1,8}$ ]] && break
    warn "$(msg 'ID YSF inválido.' 'Invalid YSF ID.')"
  done

  detect_ips
}

write_install_state(){
  local state="$1"
  install -d -m 0700 "$(dirname "$state")"
  {
    printf 'REFLECTOR_NAME=%q\n' "$REFLECTOR_NAME"
    printf 'REFLECTOR_TITLE=%q\n' "$REFLECTOR_TITLE"
    printf 'REFLECTOR_DESCRIPTION=%q\n' "$REFLECTOR_DESCRIPTION"
    printf 'SYSOP_CALLSIGN=%q\n' "$SYSOP_CALLSIGN"
    printf 'LOCATION=%q\n' "$LOCATION"
    printf 'COUNTRY=%q\n' "$COUNTRY"
    printf 'DOMAIN=%q\n' "$DOMAIN"
    printf 'CONTACT_EMAIL=%q\n' "$CONTACT_EMAIL"
    printf 'TIMEZONE=%q\n' "$TIMEZONE"
    printf 'YSF_ID=%q\n' "$YSF_ID"
    printf 'MODULE_COUNT=%q\n' "$MODULE_COUNT"
    printf 'ENABLE_HTTPS=%q\n' "$ENABLE_HTTPS"
    printf 'ENABLE_ECHO=%q\n' "$ENABLE_ECHO"
    printf 'ECHO_MODULE=%q\n' "$ECHO_MODULE"
    printf 'YSF_PORT=%q\n' "$YSF_PORT"
    printf 'YSF_FREQUENCY=%q\n' "$YSF_FREQUENCY"
    printf 'YSF_AUTOLINK=%q\n' "$YSF_AUTOLINK"
    printf 'YSF_AUTOLINK_MODULE=%q\n' "$YSF_AUTOLINK_MODULE"
    printf 'LISTEN_IP=%q\n' "$LISTEN_IP"
    printf 'PUBLIC_IP=%q\n' "$PUBLIC_IP"
  } > "$state"
  chmod 0600 "$state"
}

show_plan(){
  section "$(msg 'PLANO DA INSTALAÇÃO' 'INSTALLATION PLAN')"
  printf '%s\n' "$(msg "Refletor: ${REFLECTOR_NAME:-ainda não informado}" "Reflector: ${REFLECTOR_NAME:-not collected yet}")"
  printf '%s\n' "$(msg "Painel: $DEFAULT_DASHBOARD_DIR" "Dashboard: $DEFAULT_DASHBOARD_DIR")"
  printf '%s\n' "$(msg "Idioma do painel: ${DASHBOARD_LANG:-automático}" "Dashboard language: ${DASHBOARD_LANG:-automatic}")"
  printf '%s\n' "$(msg 'Fonte do núcleo: projeto oficial XLXD em revisão fixada' 'Core source: official XLXD project at a pinned revision')"
  printf '%s\n' "$(msg 'Echo: fonte independente em revisão fixada, somente quando selecionado' 'Echo: independent pinned source, only when selected')"
  printf '%s\n' "APRS/D-PRS: $APRS_DPRS_MODE"
  cat <<PLAN

1. Validate Debian 12 x86_64 and resources.
2. Create preventive backup.
3. Install Debian dependencies.
4. Build and install XLXD using this repository's module.
5. Install this repository's systemd service configuration.
6. Install optional Echo/Parrot independently.
7. Install the local XLX Modern Dashboard.
8. Install/validate RadioID, timers, logs, CallingHome and private Admin.
9. Optionally install APRS/D-PRS.
10. Validate services, UDP listeners, database, Admin and HTTP/HTTPS.
PLAN
}

confirm_real_installation(){
  local typed
  section "$(msg 'CONFIRMAÇÃO FINAL' 'FINAL CONFIRMATION')"
  warn "$(msg 'A próxima etapa altera pacotes, systemd, Apache e arquivos XLX.' 'The next step changes packages, systemd, Apache and XLX files.')"
  while :; do
    printf '%s' "$(msg 'Digite INSTALL para continuar: ' 'Type INSTALL to continue: ')"
    read -r typed || typed=""
    [[ "${typed^^}" == "$CONFIRMATION" ]] && break
    warn "$(msg 'Confirmação inválida; tente novamente ou pressione Ctrl+C para cancelar.' 'Invalid confirmation; try again or press Ctrl+C to cancel.')"
  done
}

resolve_aprs_choice(){
  local answer
  case "$APRS_DPRS_MODE" in
    yes) return 0 ;;
    no) return 1 ;;
    ask)
      printf '%s' "$(msg 'Instalar APRS/D-PRS opcional? [s/N]: ' 'Install optional APRS/D-PRS? [y/N]: ')"
      read -r answer || answer=""
      case "${answer,,}" in
        s|sim|y|yes) APRS_DPRS_MODE=yes; return 0 ;;
        *) APRS_DPRS_MODE=no; return 1 ;;
      esac
      ;;
  esac
}

run_check(){
  section "$(msg 'PRÉ-VALIDAÇÃO' 'PRE-CHECK')"
  bash "$ROOT_DIR/tests/test-no-external-installer.sh"
  bash "$ROOT_DIR/modules/30-packages.sh" check
  bash "$ROOT_DIR/modules/40-xlxd.sh" check
  bash "$ROOT_DIR/modules/50-echo.sh" check
  bash "$ROOT_DIR/modules/60-dashboard.sh" check
  ok "$(msg 'Pré-validação concluída. Nenhuma alteração foi executada.' 'Pre-check complete. No changes were made.')"
}

run_dashboard_only(){
  [[ -x /xlxd/xlxd ]] || fatal "$(msg 'Binário /xlxd/xlxd ausente.' '/xlxd/xlxd is missing.')"
  if [[ "$MODE" == check ]]; then
    bash "$ROOT_DIR/tests/test-no-external-installer.sh"
    ok "$(msg 'XLXD existente; modo somente painel aprovado sem alteração.' 'Existing XLXD; dashboard-only check passed without changes.')"
    return
  fi
  create_inventory_and_backup
  confirm_real_installation
  INSTALL_DIR="$DEFAULT_DASHBOARD_DIR" XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/60-dashboard-modern.sh" "--lang=$DASHBOARD_LANG"
  systemctl is-active --quiet xlxd.service || fatal "$(msg 'XLXD ficou inativo durante o fluxo somente painel.' 'XLXD became inactive during dashboard-only flow.')"
  ok "$(msg 'Painel atualizado; núcleo XLXD preservado.' 'Dashboard updated; XLXD core preserved.')"
}

validate_final(){
  local failures=0 port scheme port_http admin_slug rows integrity
  section "$(msg 'VALIDAÇÃO FINAL' 'FINAL VALIDATION')"

  for service in xlxd.service apache2.service update_XLX_db.timer xlx_log.service xlx-callinghome.timer; do
    if systemctl is-active --quiet "$service"; then
      ok "$service active"
    else
      warn "$service inactive"
      failures=$((failures+1))
    fi
  done

  if [[ "$ENABLE_ECHO" == yes ]]; then
    if systemctl is-active --quiet xlxecho.service; then
      ok 'xlxecho.service active'
    else
      warn 'xlxecho.service inactive'
      failures=$((failures+1))
    fi
  fi

  [[ -x /xlxd/xlxd ]] || { warn '/xlxd/xlxd missing'; failures=$((failures+1)); }
  [[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { warn 'XLXD process count is not 1'; failures=$((failures+1)); }

  for port in 8880 10001 10002 12345 12346 20001 21110 30001 30051 40000 "$YSF_PORT" 62030; do
    if ss -H -lunp 2>/dev/null | grep -E "[:.]${port}[[:space:]].*xlxd" >/dev/null; then
      ok "UDP $port xlxd"
    else
      warn "UDP $port missing"
      failures=$((failures+1))
    fi
  done

  integrity="$(sqlite3 /xlxd/users_db/users.db 'PRAGMA integrity_check;' 2>/dev/null || true)"
  rows="$(sqlite3 /xlxd/users_db/users.db 'SELECT COUNT(*) FROM users;' 2>/dev/null || echo 0)"
  [[ "$integrity" == ok ]] || { warn 'users.db integrity failed'; failures=$((failures+1)); }
  [[ "$rows" =~ ^[0-9]+$ && "$rows" -ge 1000 ]] || { warn "users.db rows=$rows"; failures=$((failures+1)); }

  [[ -s /etc/xlx-modern-control/route ]] || { warn 'Admin route missing'; failures=$((failures+1)); }
  if [[ -s /etc/xlx-modern-control/route ]]; then
    admin_slug="$(tr -d '\r\n' < /etc/xlx-modern-control/route)"
    [[ -s "$DEFAULT_DASHBOARD_DIR/$admin_slug/index.php" ]] || { warn 'Admin page missing'; failures=$((failures+1)); }
  fi

  apache2ctl configtest >/dev/null 2>&1 || { warn 'Apache config invalid'; failures=$((failures+1)); }
  scheme=http
  port_http=80
  [[ "$ENABLE_HTTPS" == yes ]] && { scheme=https; port_http=443; }
  if curl --noproxy '*' -kfsS --max-time 15 --resolve "$DOMAIN:$port_http:127.0.0.1" "$scheme://$DOMAIN/" >/dev/null; then
    ok "dashboard $scheme local response"
  else
    warn "dashboard $scheme local response failed"
    failures=$((failures+1))
  fi

  [[ "$failures" -eq 0 ]] || fatal "$(msg "Falharam $failures validações; não considere o servidor pronto." "$failures validation checks failed; do not consider the server ready.")"
  ok "$(msg 'Servidor e painel passaram nas validações locais.' 'Server and dashboard passed local validation.')"
}

execute_full_install(){
  local state_file stamp logfile
  stamp="$(date +%Y%m%d_%H%M%S)"
  install -d -m 0700 "$LOG_ROOT" "$WORK_ROOT/runtime"
  logfile="$LOG_ROOT/install_$stamp.log"
  state_file="$WORK_ROOT/runtime/install-input.env"
  write_install_state "$state_file"
  timedatectl set-timezone "$TIMEZONE"

  exec > >(tee -a "$logfile") 2>&1
  section "$(msg 'INSTALAÇÃO REAL' 'REAL INSTALLATION')"
  info "Log: $logfile"

  XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/30-packages.sh" install
  XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/40-xlxd.sh" install "$state_file"
  XLX_UI_LANG="$UI_LANG" bash "$ROOT_DIR/modules/50-echo.sh" install "$state_file"
  XLX_INSTALL_STATE_FILE="$state_file" XLX_UI_LANG="$UI_LANG" INSTALL_DIR="$DEFAULT_DASHBOARD_DIR" bash "$ROOT_DIR/modules/60-dashboard-modern.sh" "--lang=$DASHBOARD_LANG"

  if resolve_aprs_choice; then
    XLX_DASHBOARD_DIR="$DEFAULT_DASHBOARD_DIR" bash "$ROOT_DIR/modules/67-aprs-dprs.sh" "--dashboard-dir=$DEFAULT_DASHBOARD_DIR"
  fi

  validate_final
  section "$(msg 'INSTALAÇÃO CONCLUÍDA' 'INSTALLATION COMPLETE')"
  ok "$REFLECTOR_NAME"
  info "Dashboard: $DEFAULT_DASHBOARD_DIR"
  info "Log: $logfile"
}

main(){
  clear
  validate_options
  require_root
  select_ui_language
  select_dashboard_language
  export XLX_UI_LANG="$UI_LANG"

  section 'XLX MODERN INSTALLER — PU2PNY'
  validate_os
  bootstrap_prerequisites
  validate_resources
  validate_network
  validate_independent_sources
  detect_existing_installation

  if [[ "$DASHBOARD_ONLY" == yes ]]; then
    run_dashboard_only
    exit 0
  fi

  if [[ "$MODE" == check ]]; then
    show_plan
    run_check
    exit 0
  fi

  collect_configuration
  show_plan
  create_inventory_and_backup
  confirm_real_installation
  execute_full_install
}

main "$@"
