#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/tools/xlx-user-directory.sh"
TARGET="${XLX_USER_TOOL_TARGET:-/usr/local/sbin/xlx-user-directory}"
OVERRIDE_DB="${XLX_OVERRIDE_DB:-/var/lib/xlx-user-directory/overrides.db}"

RED=$'\033[31m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal 'Execute como root.'
[ -f "$SOURCE" ] || fatal "Utilitário ausente: $SOURCE"
command -v sqlite3 >/dev/null 2>&1 || fatal 'sqlite3 não encontrado; ele deve ter sido instalado com as dependências do XLX.'
getent group www-data >/dev/null 2>&1 || fatal 'Grupo www-data não encontrado.'

install -D -m 0750 -o root -g root "$SOURCE" "$TARGET"
XLX_OVERRIDE_DB="$OVERRIDE_DB" "$TARGET" init

ok "Gerenciador de indicativos instalado: $TARGET"
ok "Correções persistentes: $OVERRIDE_DB"
info 'A base principal do XLX continua independente e pode ser atualizada com: xlx-user-directory refresh'
