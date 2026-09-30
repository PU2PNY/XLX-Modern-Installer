#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/var/lib/xlx-modern-installer"
CONFIG_DIR="/etc/xlx-modern-installer"
LOG_DIR="/var/log/xlx-reflector/installer-v2"
MODE="install"
LANGUAGE=""

for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --panel-only) MODE="panel-only" ;;
    --repair) MODE="repair" ;;
    --lang=pt-BR) LANGUAGE="pt-BR" ;;
    --lang=en) LANGUAGE="en" ;;
    -h|--help)
      cat <<'HELP'
XLX Modern Installer v2

Uso:
  sudo bash install-v2.sh
  sudo bash install-v2.sh --check
  sudo bash install-v2.sh --panel-only
  sudo bash install-v2.sh --repair
  sudo bash install-v2.sh --lang=pt-BR
  sudo bash install-v2.sh --lang=en
HELP
      exit 0
      ;;
    *) printf 'Opção desconhecida: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

source "$ROOT_DIR/modules/v2/00-language.sh"
source "$ROOT_DIR/modules/v2/05-ui.sh"
source "$ROOT_DIR/modules/v2/10-preflight.sh"
source "$ROOT_DIR/modules/v2/20-questionnaire.sh"
source "$ROOT_DIR/modules/v2/30-config.sh"

main() {
  clear
  require_root
  select_language
  ui_header
  run_preflight

  case "$MODE" in
    check)
      ui_success "$(tr_text check_complete)"
      return 0
      ;;
    panel-only)
      ui_warning "$(tr_text panel_only_development)"
      return 2
      ;;
    repair)
      ui_warning "$(tr_text repair_development)"
      return 2
      ;;
  esac

  run_questionnaire
  show_installation_summary
  save_configuration

  ui_warning "$(tr_text development_stop)"
  ui_info "$(tr_text config_saved): $CONFIG_DIR/reflector.conf"
  ui_info "$(tr_text no_changes_applied)"
}

main "$@"
