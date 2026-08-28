#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

USERS_DIR="${XLX_USERS_DIR:-/xlxd/users_db}"
DB="${XLX_USERS_DB:-$USERS_DIR/users.db}"
BASE_CSV="${XLX_USERS_BASE_CSV:-$USERS_DIR/users_base.csv}"
UPSTREAM_CSV="${XLX_USERS_UPSTREAM_CSV:-$USERS_DIR/users_upstream.csv}"
GENERATOR="${XLX_USERS_GENERATOR:-$USERS_DIR/create_user_db.php}"
SOURCE_URL="${XLX_USERS_SOURCE_URL:-https://radioid.net/static/user.csv}"
PATCH_DB="${XLX_RADIOID_PATCH_DB:-/var/lib/xlx-user-directory/radioid-local.db}"
BACKUP_ROOT="${XLX_USERS_BACKUP_ROOT:-/var/backups/xlx-reflector/users-db}"
LOCK_FILE="${XLX_USERS_LOCK_FILE:-/run/lock/xlx-modern-users-refresh.lock}"

log(){ printf '[XLX-USERS] %s\n' "$*"; }
fatal(){ printf '[XLX-USERS][ERROR] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal 'run as root'
for cmd in curl php sqlite3 sha256sum install flock stat awk grep mktemp python3; do
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
remote_csv="$work/user.remote.csv"
patched_csv="$work/user.csv"
candidate="$work/users.db"

log 'downloading RadioID directory'
curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 180 \
    -A 'XLX-Modern-Installer/1.0' "$SOURCE_URL" -o "$remote_csv"

size="$(stat -c '%s' "$remote_csv")"
[ "$size" -ge 1000000 ] || fatal "download is too small: $size bytes"
head -n 1 "$remote_csv" | grep -qi 'CALLSIGN' || fatal 'CSV header does not contain CALLSIGN'
cp -a "$remote_csv" "$patched_csv"

# Local Admin edits are intentionally kept outside the upstream download.
# The Admin helper records final local rows and deletions in PATCH_DB. Every
# automatic RadioID refresh starts from the fresh upstream file and reapplies
# those local decisions, so an operator edit is not silently lost overnight.
local_records=0
local_deletions=0
if [ -s "$PATCH_DB" ]; then
    integrity="$(sqlite3 "$PATCH_DB" 'PRAGMA integrity_check;' 2>/dev/null || true)"
    [ "$integrity" = ok ] || fatal "local RadioID patch database failed integrity: ${integrity:-no result}"
    local_records="$(sqlite3 "$PATCH_DB" 'SELECT COUNT(*) FROM local_records;' 2>/dev/null || echo 0)"
    local_deletions="$(sqlite3 "$PATCH_DB" 'SELECT COUNT(*) FROM local_deletions;' 2>/dev/null || echo 0)"
    [[ "$local_records" =~ ^[0-9]+$ ]] || local_records=0
    [[ "$local_deletions" =~ ^[0-9]+$ ]] || local_deletions=0

    python3 - "$remote_csv" "$PATCH_DB" "$patched_csv" <<'PY'
import csv
import os
import sqlite3
import sys
import tempfile

remote, patch_db, output = sys.argv[1:]
with open(remote, 'r', encoding='utf-8', errors='strict', newline='') as handle:
    rows = list(csv.reader(handle))
if not rows:
    raise SystemExit('empty upstream CSV')
header, data = rows[0], rows[1:]

con = sqlite3.connect('file:' + patch_db + '?mode=ro', uri=True, timeout=5)
deletions = {
    (str(call or '').strip().upper(), str(dmr or '').strip())
    for call, dmr in con.execute('SELECT callsign,dmrid FROM local_deletions')
}
local = [
    [str(dmr or '').strip(), str(call or '').strip().upper(), str(first or '').strip(),
     str(last or '').strip(), str(city or '').strip(), str(state or '').strip(), str(country or '').strip()]
    for call, dmr, first, last, city, state, country in con.execute(
        'SELECT callsign,dmrid,first_name,last_name,city,state,country FROM local_records ORDER BY callsign'
    )
]
con.close()

local_calls = {r[1] for r in local if r[1]}
local_dmrs = {r[0] for r in local if r[0]}

def deleted(row):
    if len(row) < 7:
        return False
    call = row[1].strip().upper()
    dmr = row[0].strip()
    return any((dc == call and (not dd or dd == dmr)) for dc, dd in deletions)

filtered = []
for row in data:
    if len(row) < 7:
        continue
    call = row[1].strip().upper()
    dmr = row[0].strip()
    if deleted(row):
        continue
    if call in local_calls:
        continue
    if dmr and dmr in local_dmrs:
        continue
    filtered.append(row)
filtered.extend(local)

fd, tmp = tempfile.mkstemp(prefix='.radioid-patched.', dir=os.path.dirname(output), text=True)
os.close(fd)
try:
    with open(tmp, 'w', encoding='utf-8', newline='') as handle:
        writer = csv.writer(handle, lineterminator='\n')
        writer.writerow(header)
        writer.writerows(filtered)
    os.replace(tmp, output)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY
    log "reapplied local Admin records=$local_records deletions=$local_deletions"
fi

head -n 1 "$patched_csv" | grep -qi 'CALLSIGN' || fatal 'patched CSV header invalid'
php "$GENERATOR" "$patched_csv" "$candidate"
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
if [ -f "$BASE_CSV" ]; then
    base_backup="$BACKUP_ROOT/users-base-$stamp.csv"
    cp -a "$BASE_CSV" "$base_backup"
    sha256sum "$base_backup" > "$base_backup.sha256"
fi
if [ -f "$UPSTREAM_CSV" ]; then
    upstream_backup="$BACKUP_ROOT/users-upstream-$stamp.csv"
    cp -a "$UPSTREAM_CSV" "$upstream_backup"
    sha256sum "$upstream_backup" > "$upstream_backup.sha256"
fi

install -m 0640 -o root -g www-data "$remote_csv" "$UPSTREAM_CSV.new"
install -m 0640 -o root -g www-data "$patched_csv" "$BASE_CSV.new"
install -m 0640 -o root -g www-data "$candidate" "$DB.new"
mv -f "$UPSTREAM_CSV.new" "$UPSTREAM_CSV"
mv -f "$BASE_CSV.new" "$BASE_CSV"
mv -f "$DB.new" "$DB"

log "database published: $rows rows"
log "source bytes: $size"
log "local records preserved: $local_records"
log "local deletions preserved: $local_deletions"
