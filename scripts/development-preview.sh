#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
clear
echo "============================================================"
echo " XLX MODERN INSTALLER — DEVELOPMENT PREVIEW"
echo "============================================================"
echo
echo "1) Português — Brasil"
echo "2) English — United States"
read -r -p "> " lang
case "$lang" in
  1) source "$ROOT/locales/pt_BR.sh" ;;
  2) source "$ROOT/locales/en_US.sh" ;;
  *) echo "Opção inválida / Invalid option"; exit 1 ;;
esac
source "$ROOT/lib/common.sh"
echo
echo "$MSG_WELCOME"
while true; do
  echo
  echo "1) $MSG_MENU_PREFLIGHT"
  echo "2) $MSG_MENU_PLAN"
  echo "3) $MSG_MENU_TEST"
  echo "0) $MSG_MENU_EXIT"
  read -r -p "> " option
  case "$option" in
    1) "$ROOT/modules/00-preflight.sh" ;;
    2) cat "$ROOT/ARCHITECTURE.md"; echo; echo "$MSG_NO_CHANGES" ;;
    3) "$ROOT/tests/run-all.sh" ;;
    0) echo "$MSG_NO_CHANGES"; exit 0 ;;
    *) warn "$MSG_INVALID_OPTION" ;;
  esac
done
