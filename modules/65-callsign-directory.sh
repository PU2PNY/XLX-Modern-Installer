#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/tools/xlx-user-directory.sh"
TARGET="${XLX_USER_TOOL_TARGET:-/usr/local/sbin/xlx-user-directory}"
OVERRIDE_DB="${XLX_OVERRIDE_DB:-/var/lib/xlx-user-directory/overrides.db}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ if [ "$UI_LANG" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

RED=$'\033[31m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
fatal(){ printf '%s%s%s %s\n' "$RED" "$(say '[ERRO]' '[ERROR]')" "$RESET" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal "$(say 'Execute como root.' 'Run as root.')"
[ -f "$SOURCE" ] || fatal "$(say "Utilitário ausente: $SOURCE" "Utility missing: $SOURCE")"
command -v sqlite3 >/dev/null 2>&1 || fatal "$(say 'sqlite3 não encontrado; ele deve ter sido instalado com as dependências do XLX.' 'sqlite3 not found; it should have been installed with the XLX dependencies.')"
getent group www-data >/dev/null 2>&1 || fatal "$(say 'Grupo www-data não encontrado.' 'www-data group not found.')"

install -D -m 0750 -o root -g root "$SOURCE" "$TARGET"
XLX_OVERRIDE_DB="$OVERRIDE_DB" "$TARGET" init

ok "$(say "Gerenciador de indicativos instalado: $TARGET" "Callsign manager installed: $TARGET")"
ok "$(say "Correções persistentes: $OVERRIDE_DB" "Persistent overrides: $OVERRIDE_DB")"
info "$(say 'A base principal do XLX continua independente e pode ser atualizada com: xlx-user-directory refresh' 'The main XLX database remains independent and can be updated with: xlx-user-directory refresh')"
