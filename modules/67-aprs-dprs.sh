#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'; umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/vendor/xlx-aprs-dprs/771abaa0c1ea662f33f3fa0c4a59ec712b1e4fcb"
DASHBOARD="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
MODE=install
UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ [[ "$UI_LANG" == en ]]&&printf '%s' "$2"||printf '%s' "$1"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }
for a in "$@";do case "$a" in --check|--dry-run)MODE=check;;--dashboard-dir=*)DASHBOARD="${a#*=}";;*)fail "$(say "Opção desconhecida: $a" "Unknown option: $a")";;esac;done
[[ "$(id -u)" -eq 0 ]]||fail "$(say 'Execute como root.' 'Run as root.')"
[[ -f "$SOURCE/install.sh" && -f "$SOURCE/SOURCE-MANIFEST.sha256" ]]||fail "$(say 'Componente APRS/D-PRS incorporado está incompleto.' 'Bundled APRS/D-PRS component is incomplete.')"
(cd "$SOURCE" && sha256sum -c SOURCE-MANIFEST.sha256 >/dev/null)||fail "$(say 'Manifesto APRS/D-PRS inválido.' 'Invalid APRS/D-PRS manifest.')"
find "$SOURCE" -type f -name '*.sh' -print0|xargs -0 -r -n1 bash -n
if command -v php >/dev/null;then find "$SOURCE" -type f -name '*.php' -print0|xargs -0 -r -n1 php -l >/dev/null;fi
if command -v python3 >/dev/null;then python3 -m py_compile "$SOURCE/gateway/xlx_aprs_dprs.py";fi
[[ "$MODE" == check ]]&&{ printf '[OK] %s\n' "$(say 'APRS/D-PRS incorporado validado; nenhuma alteração feita.' 'Bundled APRS/D-PRS validated; no changes made.')";exit 0; }
[[ -d "$DASHBOARD" && -f "$DASHBOARD/index.php" ]]||fail "$(say "Dashboard não encontrado: $DASHBOARD" "Dashboard not found: $DASHBOARD")"
args=(--dashboard-dir "$DASHBOARD")
SITE="$DASHBOARD/config/site.php"
if [[ -f "$SITE" ]];then
 REF="$(php -r '$c=require $argv[1];echo (string)($c["reflector"]["name"]??"");' "$SITE")"
 SYSOP="$(php -r '$c=require $argv[1];echo (string)($c["reflector"]["sysop_callsign"]??"");' "$SITE")"
 [[ -z "$REF" ]]||args+=(--reflector-name "$REF")
 [[ -z "$SYSOP" ]]||args+=(--client-callsign "$SYSOP")
fi
XLX_UI_LANG="$UI_LANG" bash "$SOURCE/install.sh" "${args[@]}"
printf '[OK] %s\n' "$(say 'APRS/D-PRS instalado e integrado.' 'APRS/D-PRS installed and integrated.')"
