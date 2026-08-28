#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

USERS_DIR="${XLX_USERS_DIR:-/xlxd/users_db}"
DB="${XLX_USERS_DB:-$USERS_DIR/users.db}"
BASE_CSV="${XLX_USERS_BASE_CSV:-$USERS_DIR/users_base.csv}"
GENERATOR="${XLX_USERS_GENERATOR:-$USERS_DIR/create_user_db.php}"
SOURCE_URL="${XLX_USERS_SOURCE_URL:-https://radioid.net/static/user.csv}"
BACKUP_ROOT="${XLX_USERS_BACKUP_ROOT:-/var/backups/xlx-reflector/users-db}"
LOCK_FILE="${XLX_USERS_LOCK_FILE:-/run/lock/xlx-modern-users-refresh.lock}"

log(){ printf '[XLX-USERS] %s\n' "$*"; }
fatal(){ printf '[XLX-USERS][ERROR] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal 'run as root'
for cmd in curl php sqlite3 sha256sum install flock stat awk grep mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "missing command: $cmd"
done
[ -f "$GENERATOR" ] || fatal "generator not found: $GENERATOR"

install -d -m 0755 "$USERS_DIR"
install -d -m 0700 "$BACKUP_ROOT"
install -d -m 0755 "$(dirname "$LOCK_FILE")"

exec 9>"$LOCK_FILE"
flock -n 9 || { log 'another refresh is already running'; exit 0; }

work="$(mktemp -d "$USERS_DIR/.refresh.XXXXXX")"
trap 'rm -rf "$work"' EXIT
csv="$work/user.csv"
candidate="$work/users.db"

log "downloading RadioID directory"
curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 180 \
    -A 'XLX-Modern-Installer/1.0' "$SOURCE_URL" -o "$csv"

size="$(stat -c '%s' "$csv")"
[ "$size" -ge 1000000 ] || fatal "download is too small: $size bytes"
head -n 1 "$csv" | grep -qi 'CALLSIGN' || fatal 'CSV header does not contain CALLSIGN'

php "$GENERATOR" "$csv" "$candidate"
[ -s "$candidate" ] || fatal 'candidate database was not created'

integrity="$(sqlite3 "$candidate" 'PRAGMA integrity_check;' 2>/dev/null || true)"
[ "$integrity" = 'ok' ] || fatal "candidate integrity check failed: ${integrity:-no result}"
rows="$(sqlite3 "$candidate" 'SELECT COUNT(*) FROM users;' 2>/dev/null || echo 0)"
[[ "$rows" =~ ^[0-9]+$ ]] || rows=0
[ "$rows" -ge 1000 ] || fatal "candidate has too few rows: $rows"

stamp="$(date +%Y%m%d_%H%M%S)"
if [ -f "$DB" ]; then
    backup="$BACKUP_ROOT/users-$stamp.db"
    cp -a "$DB" "$backup"
    sha256sum "$backup" > "$backup.sha256"
    sqlite3 "$backup" 'PRAGMA integrity_check;' | grep -qx 'ok' || fatal 'backup integrity check failed'
    log "backup verified: $backup"
fi

install -m 0640 -o root -g www-data "$csv" "$BASE_CSV.new"
install -m 0640 -o root -g www-data "$candidate" "$DB.new"
mv -f "$BASE_CSV.new" "$BASE_CSV"
mv -f "$DB.new" "$DB"

log "database published: $rows rows"
log "source bytes: $size"
