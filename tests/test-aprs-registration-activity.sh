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
REFLECTOR_LOG="$TMP/xlx.log"
TIMEZONE_FILE="$TMP/timezone"

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
$stmt->execute(['PU2OLD',$now-1801,$now]);
PHP

printf '%s\n' 'America/Sao_Paulo' > "$TIMEZONE_FILE"

python3 - "$REFLECTOR_LOG" <<'PY'
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo
import sys

p=Path(sys.argv[1])
tz=ZoneInfo("America/Sao_Paulo")
now=datetime.now(timezone.utc)

def fmt(dt):
    local=dt.astimezone(tz)
    return local.strftime("%-d %b, %H:%M:%S")

open_at=now-timedelta(seconds=70)
close_at=now-timedelta(seconds=60)

p.write_text(
    f"{fmt(open_at)}: Opening stream on module C for client PU2LOG  B with sid 12345\n"
    f"{fmt(close_at)}: Closing stream of module C\n"
)
PY

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
    "is_readable('/etc/timezone')":
        "is_readable('__TIMEZONE_FILE__')",
    "file_get_contents('/etc/timezone')":
        "file_get_contents('__TIMEZONE_FILE__')",
    "return '/var/log/xlx.log';":
        "return '__REFLECTOR_LOG__';",
}

for old,new in repls.items():
    if s.count(old)!=1:
        raise SystemExit(f"missing test replacement: {old}")
    s=s.replace(old,new,1)

p.write_text(s)
PY

python3 - "$TEST_API" "$TIMEZONE_FILE" "$REFLECTOR_LOG" <<'PY'
from pathlib import Path
import sys
api=Path(sys.argv[1])
tz=sys.argv[2]
log=sys.argv[3]
s=api.read_text()
s=s.replace("__TIMEZONE_FILE__",tz)
s=s.replace("__REFLECTOR_LOG__",log)
api.write_text(s)
PY

php -l "$TEST_API" >/dev/null

run_action(){
  local action="$1"
  local call="$2"
  local body

  if [[ "$action" == "registration_check" ]]; then
    body="$(printf '{"action":"registration_check","callsign":"%s"}' "$call")"
  else
    body="$(printf '{"action":"register","callsign":"%s","birth_day":18,"birth_month":7,"birth_year":1980,"birthday_consent":true}' "$call")"
  fi

  printf '%s' "$body" |
    REQUEST_METHOD=POST     CONTENT_LENGTH="${#body}"     REMOTE_ADDR="127.0.0.1"     php "$TEST_API"
}

CHECK_NEW="$(run_action registration_check PU2NEW)"

python3 - "$CHECK_NEW" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d.get("ok") is True,d
assert d.get("recent") is True,d
assert d.get("window_seconds")==1800,d
print("precheck_recent=PASS")
PY

CHECK_OLD="$(run_action registration_check PU2OLD)"

python3 - "$CHECK_OLD" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d.get("ok") is True,d
assert d.get("recent") is False,d
print("precheck_stale=PASS")
PY

CHECK_LOG="$(run_action registration_check PU2LOG)"

python3 - "$CHECK_LOG" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d.get("ok") is True,d
assert d.get("recent") is True,d
assert d.get("window_seconds")==1800,d
print("precheck_timezone_correct_log=PASS")
PY

NEW_OUT="$(run_action register PU2NEW)"

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

OLD_OUT="$(run_action register PU2OLD)"

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
grep -F "reflectorLogTimezone" "$API" >/dev/null
grep -F "recentlySeenOnReflectorLog" "$API" >/dev/null
grep -F "rateAllowed('register', 6, 900)" "$API" >/dev/null

if grep -A45 -F "function recentlySeenOnReflector" "$API" |
   grep -F "last_seen>=:cutoff" >/dev/null; then
  echo "FAIL | reflector registration proof uses collector last_seen"
  exit 1
fi

echo "aprs_registration_activity=PASS"
