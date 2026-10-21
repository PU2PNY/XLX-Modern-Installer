#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HTML="$ROOT/dashboard/digital-lab-native.php"
JS="$ROOT/dashboard/assets/digital-lab-operator.js"
API="$ROOT/dashboard/api/digital-lab-operator.php"
INIT="$ROOT/dashboard/native/aprs/init-accounts.php"

php -l "$HTML" >/dev/null
php -l "$API" >/dev/null
php -l "$INIT" >/dev/null

grep -F 'id="dlabBirthDay"' "$HTML" >/dev/null
grep -F 'inputmode="numeric"' "$HTML" >/dev/null
grep -F 'maxlength="2"' "$HTML" >/dev/null
grep -F 'id="dlabBirthYear"' "$HTML" >/dev/null
grep -F 'maxlength="4"' "$HTML" >/dev/null
grep -F "birth_year:Number(birthYear.value)" "$JS" >/dev/null
grep -F "validBirthdayFull" "$API" >/dev/null
grep -F "birth_year INTEGER" "$INIT" >/dev/null
grep -F "ALTER TABLE accounts ADD COLUMN birth_year INTEGER" "$INIT" >/dev/null

if grep -Eq "'birth_(day|month|year)'[[:space:]]*=>" "$API"; then
  echo "FAIL | birthday recovery data leaked to audit payload"
  exit 1
fi

python3 - "$HTML" <<'PY'
from pathlib import Path
import sys

s=Path(sys.argv[1]).read_text()
markers=[
    ("messages", "MENSAGENS APRS"),
    ("data", "D-PRS / APRS"),
    ("guided", "TESTE GUIADO"),
    ("questions", "APRENDA SEM COMPLICAÇÃO"),
]
pos={name:s.index(marker) for name,marker in markers}
assert pos["messages"] < pos["data"] < pos["guided"] < pos["questions"], pos
print("layout_order=PASS")
PY

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/accounts.sqlite"

php -- "$DB" <<'PHP'
<?php
$db=new PDO('sqlite:'.$argv[1]);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec(
    'CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        callsign TEXT,
        birth_day INTEGER,
        birth_month INTEGER
    )'
);
$db->exec(
    "INSERT INTO accounts(callsign,birth_day,birth_month)
     VALUES('PU2OLD',18,7)"
);
PHP

php "$INIT" "$DB" "" "" >/dev/null

php -- "$DB" <<'PHP'
<?php
$db=new PDO('sqlite:'.$argv[1]);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$cols=$db->query('PRAGMA table_info(accounts)')->fetchAll(PDO::FETCH_ASSOC);
$names=array_column($cols,'name');
if (!in_array('birth_year',$names,true)) {
    fwrite(STDERR,"birth_year missing\n");
    exit(1);
}
$row=$db->query(
    "SELECT callsign,birth_day,birth_month,birth_year
     FROM accounts WHERE callsign='PU2OLD'"
)->fetch(PDO::FETCH_ASSOC);
if (!$row || $row['birth_year'] !== null) {
    fwrite(STDERR,"legacy account was not preserved\n");
    exit(1);
}
if ($db->query('PRAGMA integrity_check')->fetchColumn() !== 'ok') {
    fwrite(STDERR,"sqlite integrity failed\n");
    exit(1);
}
echo "legacy_migration=PASS\n";
PHP

echo "aprs_registration_birthday=PASS"
