#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

MAIN_DB="${XLX_USERS_DB:-/xlxd/users_db/users.db}"
GENERATOR="${XLX_USERS_GENERATOR:-/xlxd/users_db/create_user_db.php}"
OVERRIDE_DB="${XLX_OVERRIDE_DB:-/var/lib/xlx-user-directory/overrides.db}"
BACKUP_ROOT="${XLX_BACKUP_ROOT:-/var/backups/xlx-reflector/callsign-directory}"

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage(){
  cat <<'EOF'
XLX User Directory

Uso:
  xlx-user-directory init
  xlx-user-directory lookup INDICATIVO
  xlx-user-directory set INDICATIVO "Nome" "Cidade, Região"
  xlx-user-directory alias ANTIGO NOVO
  xlx-user-directory delete INDICATIVO
  xlx-user-directory refresh
  xlx-user-directory check

A base principal do XLX permanece separada. Correções locais ficam em um banco
de overrides persistente, portanto não são perdidas quando a base principal é
reconstruída.
EOF
}

require_root(){ [ "$(id -u)" -eq 0 ] || fatal 'Execute como root.'; }
require_sqlite(){ command -v sqlite3 >/dev/null 2>&1 || fatal 'sqlite3 não encontrado.'; }

norm_call(){
  local c="${1^^}"
  c="${c// /}"
  [[ "$c" =~ ^[A-Z0-9]{3,12}$ ]] || fatal "Indicativo inválido: $1"
  printf '%s' "$c"
}

sql_quote(){ printf '%s' "$1" | sed "s/'/''/g"; }

init_db(){
  require_sqlite
  install -d -m 0750 -o root -g www-data "$(dirname "$OVERRIDE_DB")"
  sqlite3 "$OVERRIDE_DB" <<'SQL'
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS user_overrides (
  callsign TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  city_state TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS callsign_aliases (
  old_callsign TEXT PRIMARY KEY,
  new_callsign TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
SQL
  chown root:www-data "$OVERRIDE_DB"
  chmod 0640 "$OVERRIDE_DB"
  ok "Base de correções locais pronta: $OVERRIDE_DB"
}

check_db(){
  require_sqlite
  [ -f "$OVERRIDE_DB" ] && {
    local r
    r="$(sqlite3 "$OVERRIDE_DB" 'PRAGMA integrity_check;' 2>/dev/null || true)"
    [ "$r" = 'ok' ] || fatal "Base de overrides inválida: ${r:-sem resposta}"
    ok 'Base de overrides íntegra.'
  }
  if [ -f "$MAIN_DB" ]; then
    local r2
    r2="$(sqlite3 "$MAIN_DB" 'PRAGMA integrity_check;' 2>/dev/null || true)"
    [ "$r2" = 'ok' ] || fatal "Base principal inválida: ${r2:-sem resposta}"
    ok 'Base principal íntegra.'
  else
    warn "Base principal ainda não existe: $MAIN_DB"
  fi
}

lookup_call(){
  init_db >/dev/null
  local call resolved row
  call="$(norm_call "$1")"
  resolved="$(sqlite3 "$OVERRIDE_DB" "SELECT new_callsign FROM callsign_aliases WHERE old_callsign='$(sql_quote "$call")' LIMIT 1;" 2>/dev/null || true)"
  [ -n "$resolved" ] || resolved="$call"
  row="$(sqlite3 -separator '|' "$OVERRIDE_DB" "SELECT callsign,name,city_state FROM user_overrides WHERE callsign='$(sql_quote "$resolved")' LIMIT 1;" 2>/dev/null || true)"
  if [ -n "$row" ]; then
    printf 'override|%s\n' "$row"
    return
  fi
  if [ -r "$MAIN_DB" ]; then
    row="$(sqlite3 -separator '|' "$MAIN_DB" "SELECT callsign,name,city_state FROM users WHERE callsign='$(sql_quote "$resolved")' LIMIT 1;" 2>/dev/null || true)"
    if [ -n "$row" ]; then
      printf 'base|%s\n' "$row"
      return
    fi
  fi
  printf 'not-found|%s||\n' "$resolved"
}

set_override(){
  init_db >/dev/null
  local call name city now
  call="$(norm_call "$1")"; name="$2"; city="$3"; now="$(date +%s)"
  [ -n "$name" ] || fatal 'Nome não pode ficar vazio.'
  sqlite3 "$OVERRIDE_DB" "BEGIN IMMEDIATE; INSERT INTO user_overrides(callsign,name,city_state,updated_at) VALUES('$(sql_quote "$call")','$(sql_quote "$name")','$(sql_quote "$city")',$now) ON CONFLICT(callsign) DO UPDATE SET name=excluded.name,city_state=excluded.city_state,updated_at=excluded.updated_at; COMMIT;"
  ok "Correção salva para $call."
}

set_alias(){
  init_db >/dev/null
  local old new now
  old="$(norm_call "$1")"; new="$(norm_call "$2")"; now="$(date +%s)"
  [ "$old" != "$new" ] || fatal 'Indicativo antigo e novo são iguais.'
  sqlite3 "$OVERRIDE_DB" "BEGIN IMMEDIATE; INSERT INTO callsign_aliases(old_callsign,new_callsign,updated_at) VALUES('$(sql_quote "$old")','$(sql_quote "$new")',$now) ON CONFLICT(old_callsign) DO UPDATE SET new_callsign=excluded.new_callsign,updated_at=excluded.updated_at; COMMIT;"
  ok "Alias salvo: $old -> $new."
}

delete_override(){
  init_db >/dev/null
  local call
  call="$(norm_call "$1")"
  sqlite3 "$OVERRIDE_DB" "BEGIN IMMEDIATE; DELETE FROM user_overrides WHERE callsign='$(sql_quote "$call")'; DELETE FROM callsign_aliases WHERE old_callsign='$(sql_quote "$call")'; COMMIT;"
  ok "Correções locais removidas para $call."
}

refresh_main(){
  require_root; require_sqlite
  command -v php >/dev/null 2>&1 || fatal 'php não encontrado.'
  [ -f "$GENERATOR" ] || fatal "Gerador oficial não encontrado: $GENERATOR"
  install -d -m 0700 "$BACKUP_ROOT"
  local stamp backup tmp_before rc integrity
  stamp="$(date +%Y%m%d_%H%M%S)"; backup="$BACKUP_ROOT/users-${stamp}.db"
  tmp_before=0
  if [ -f "$MAIN_DB" ]; then
    cp -a "$MAIN_DB" "$backup"
    sqlite3 "$backup" 'PRAGMA integrity_check;' | grep -qx 'ok' || fatal 'Backup da base principal falhou na verificação.'
    tmp_before=1
    ok "Backup verificado: $backup"
  fi
  set +e
  (cd "$(dirname "$GENERATOR")" && php "$(basename "$GENERATOR")")
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] || [ ! -f "$MAIN_DB" ]; then
    [ "$tmp_before" -eq 0 ] || cp -a "$backup" "$MAIN_DB"
    fatal "Gerador terminou com erro ($rc); base anterior restaurada quando disponível."
  fi
  integrity="$(sqlite3 "$MAIN_DB" 'PRAGMA integrity_check;' 2>/dev/null || true)"
  if [ "$integrity" != 'ok' ]; then
    [ "$tmp_before" -eq 0 ] || cp -a "$backup" "$MAIN_DB"
    fatal "Nova base falhou na integridade (${integrity:-sem resposta}); rollback executado."
  fi
  ok 'Base principal reconstruída e validada.'
  ok 'Correções locais foram preservadas separadamente.'
}

cmd="${1:-}"
case "$cmd" in
  init) require_root; init_db; check_db ;;
  check) check_db ;;
  lookup) [ "$#" -eq 2 ] || { usage; exit 2; }; lookup_call "$2" ;;
  set) require_root; [ "$#" -eq 4 ] || { usage; exit 2; }; set_override "$2" "$3" "$4" ;;
  alias) require_root; [ "$#" -eq 3 ] || { usage; exit 2; }; set_alias "$2" "$3" ;;
  delete) require_root; [ "$#" -eq 2 ] || { usage; exit 2; }; delete_override "$2" ;;
  refresh) refresh_main ;;
  -h|--help|help|'') usage ;;
  *) usage; fatal "Comando desconhecido: $cmd" ;;
esac
