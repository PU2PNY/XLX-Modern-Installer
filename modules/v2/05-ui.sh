#!/usr/bin/env bash

UI_RED=$'\033[31m'; UI_YELLOW=$'\033[33m'; UI_GREEN=$'\033[32m'; UI_BLUE=$'\033[34m'; UI_RESET=$'\033[0m'
ui_header(){ printf '\n============================================================\n                 XLX MODERN INSTALLER v2\n============================================================\n'; }
ui_info(){ printf '%s[INFO]%s %s\n' "$UI_BLUE" "$UI_RESET" "$*"; }
ui_success(){ printf '%s[OK]%s %s\n' "$UI_GREEN" "$UI_RESET" "$*"; }
ui_warning(){ printf '%s[ATENÇÃO]%s %s\n' "$UI_YELLOW" "$UI_RESET" "$*"; }
ui_error(){ printf '%s[ERRO]%s %s\n' "$UI_RED" "$UI_RESET" "$*" >&2; }
ui_section(){ printf '\n------------------------------------------------------------\n%s\n------------------------------------------------------------\n' "$*"; }
