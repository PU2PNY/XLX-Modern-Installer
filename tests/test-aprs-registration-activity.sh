#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
API="$ROOT/dashboard/api/digital-lab-operator.php"
INIT="$ROOT/dashboard/native/aprs/init-accounts.php"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ACCOUNTS="$TMP/accounts.sqlite"
GATEWAY="$TMP/gateway.sqlite"
HISTORY="$TMP/history.sqlite"
RATE="$TMP/rate.json"
TEST_API="$TMP/operator.php"

php "$INIT" "$ACCOUNTS" "" "" >/dev/null

php -- "$GATEWAY" "$HISTORY" <<'PHP'
<?php
$g=new PDO('sqlite:'.$argv[1]);
$g->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$g->exec(
    'CREATE TABLE stations(
        callsign TEXT,
        last_seen TEXT,
        source TEXT,
        module TEXT
    )'
);
$g->exec(
    'CREATE TABLE messages(
        peer TEXT,
        ts TEXT,
        direction TEXT,
        status TEXT
    )'
);

$h=new PDO('sqlite:'.$argv[2]);
$h->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$h->exec(
    'CREATE TABLE history(
        callsign TEXT NOT NULL,
        ended_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL
    )'
);

$now=time();

$stmt=$h->prepare(
    'INSERT INTO history(callsign,ended_at,last_seen)
     VALUES(?,?,?)'
);

$stmt->execute(['PU2NEW',$now-60,$now]);
$stmt->execute(['PU2OLD',$now-901,$now]);
PHP

cp "$API" "$TEST_API"

python3 - "$TEST_API" "$ACCOUNTS" "$GATEWAY" "$HISTORY" "$RATE" <<'PY'
from pathlib import Path
import sys

p=Path(sys.argv[1])
accounts,gateway,history,rate=sys.argv[2:]
s=p.read_text()

repls={
    "const ACCOUNTS_DB =\n    '/var/lib/xlx-aprs-dprs/accounts.sqlite';":
        f"const ACCOUNTS_DB =\n    '{accounts}';",
    "const GATEWAY_DB =\n    '/var/lib/xlx-aprs-dprs/digital-lab.sqlite';":
        f"const GATEWAY_DB =\n    '{gateway}';",
    "const HISTORY_DB =\n    '/var/lib/xlx-modern-history/history.sqlite';":
        f"const HISTORY_DB =\n    '{history}';",
    "const RATE_FILE =\n    '/var/lib/xlx-aprs-dprs/operator-rate.json';":
        f"const RATE_FILE =\n    '{rate}';",
    "file_get_contents('php://input')":
        "file_get_contents('php://stdin')",
}

for old,new in repls.items():
    if s.count(old)!=1:
        raise SystemExit(f"missing test replacement: {old}")
    s=s.replace(old,new,1)

p.write_text(s)
PY

php -l "$TEST_API" >/dev/null

run_register(){
  local call="$1"
  local body
  body="$(printf '{"action":"register","callsign":"%s","birth_day":18,"birth_month":7,"birth_year":1980,"birthday_consent":true}' "$call")"
  printf '%s' "$body" |
    REQUEST_METHOD=POST     CONTENT_LENGTH="${#body}"     REMOTE_ADDR="127.0.0.1"     php "$TEST_API"
}

NEW_OUT="$(run_register PU2NEW)"

python3 - "$NEW_OUT" "$ACCOUNTS" <<'PY'
import json,sqlite3,sys
d=json.loads(sys.argv[1])
assert d.get("ok") is True,d
db=sqlite3.connect(sys.argv[2])
assert db.execute(
    "select count(*) from accounts where callsign='PU2NEW'"
).fetchone()[0]==1
print("recent_reflector_eot=PASS")
PY

OLD_OUT="$(run_register PU2OLD)"

python3 - "$OLD_OUT" "$ACCOUNTS" <<'PY'
import json,sqlite3,sys
d=json.loads(sys.argv[1])
assert d.get("ok") is False,d
assert d.get("error")=="not_recently_seen",d
db=sqlite3.connect(sys.argv[2])
assert db.execute(
    "select count(*) from accounts where callsign='PU2OLD'"
).fetchone()[0]==0
print("stale_eot_rejected=PASS")
PY

grep -F "AND ended_at>=:cutoff" "$API" >/dev/null

if grep -A45 -F "function recentlySeenOnReflector" "$API" |
   grep -F "last_seen>=:cutoff" >/dev/null; then
  echo "FAIL | reflector registration proof uses collector last_seen"
  exit 1
fi

echo "aprs_registration_activity=PASS"
