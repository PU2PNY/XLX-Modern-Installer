#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d /tmp/xlx-control-functional.XXXXXX)"
cleanup(){ if [[ $(id -u) -eq 0 ]]; then rm -rf "$TMP"; else sudo rm -rf "$TMP"; fi; }
trap cleanup EXIT
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }
ok(){ printf 'OK | %s\n' "$*"; }
run_root(){ if [[ $(id -u) -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

mkdir -p "$TMP/access" "$TMP/backups" "$TMP/state" "$TMP/radio" "$TMP/mockbin" "$TMP/core-backups"
printf '# white\nN0CALL\n' > "$TMP/access/white"
printf '# black\n' > "$TMP/access/black"
printf '# interlink\nXLX999 192.0.2.10 A\n' > "$TMP/access/interlink"

ACCESS_ENV=(
  XLX_CONTROL_STATE="$TMP/state"
  XLX_ACCESS_BACKUPS="$TMP/backups/access"
  XLX_WHITELIST="$TMP/access/white"
  XLX_BLACKLIST="$TMP/access/black"
  XLX_INTERLINK="$TMP/access/interlink"
  XLX_ACCESS_LOCK="$TMP/access.lock"
)
access(){ run_root env "${ACCESS_ENV[@]}" bash "$ROOT/control/xlx-modern-access-helper" "$@"; }
access status | python3 -c 'import json,sys; x=json.load(sys.stdin); assert "N0CALL" in x["whitelist"] and x["interlinks"][0]["callsign"]=="XLX999"'
access add-white PU2PNY >/dev/null; grep -Fxq PU2PNY "$TMP/access/white"
access delete-white PU2PNY >/dev/null; ! grep -Fxq PU2PNY "$TMP/access/white"
access add-black BAD123 >/dev/null; grep -Fxq BAD123 "$TMP/access/black"
access delete-black BAD123 >/dev/null; ! grep -Fxq BAD123 "$TMP/access/black"
access interlink-add XLX123 203.0.113.5 ABC >/dev/null; grep -Fxq 'XLX123 203.0.113.5 ABC' "$TMP/access/interlink"
access interlink-delete XLX123 >/dev/null; ! grep -Fq XLX123 "$TMP/access/interlink"
run_root grep -Fq 'action=interlink-delete' "$TMP/state/audit.log"
ok 'whitelist, blacklist and Interlink add/delete/status are functional'

cat > "$TMP/radio/users.csv" <<'CSV'
radio_id,callsign,first_name,last_name,city,state,country
7240001,PU2AAA,Ana,Teste,Sao Paulo,SP,Brazil
CSV
cat > "$TMP/radio/generate.php" <<'PHP'
<?php
[$self,$csv,$db]=$argv;
@unlink($db);
$p=new PDO('sqlite:'.$db);$p->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$p->exec('CREATE TABLE users(callsign TEXT PRIMARY KEY,name TEXT,city_state TEXT)');
$f=fopen($csv,'r');fgetcsv($f);
$st=$p->prepare('INSERT INTO users(callsign,name,city_state) VALUES(?,?,?)');
while(($r=fgetcsv($f))!==false){if(count($r)<7)continue;$st->execute([$r[1],trim($r[2].' '.$r[3]),trim($r[4].' - '.$r[5])]);}
PHP
php "$TMP/radio/generate.php" "$TMP/radio/users.csv" "$TMP/radio/users.db"
cat > "$TMP/radio/refresh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$TMP/radio/refresh"
RADIO_ENV=(
  XLX_USERS_BASE_CSV="$TMP/radio/users.csv"
  XLX_USERS_DB="$TMP/radio/users.db"
  XLX_USERS_GENERATOR="$TMP/radio/generate.php"
  XLX_USERS_REFRESH="$TMP/radio/refresh"
  XLX_RADIOID_PATCH_DB="$TMP/radio/local.db"
  XLX_RADIOID_BACKUPS="$TMP/backups/radio"
  XLX_RADIOID_LOCK="$TMP/radio.lock"
)
radio(){ run_root env "${RADIO_ENV[@]}" bash "$ROOT/control/xlx-modern-radioid-helper" "$@"; }
radio status | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["ok"] and x["records"]==1 and x["integrity"]=="ok"'
radio search callsign PU2AAA | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["count"]==1 and x["rows"][0]["callsign"]=="PU2AAA"'
radio save '' '' 7240002 PU2BBB Bruno Teste Campinas SP Brazil | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["ok"] and x["action"]=="added" and x["persistent"]'
radio search callsign PU2BBB | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["count"]==1'
radio save 7240002 PU2BBB 7240002 PU2BBC Bruno Editado Campinas SP Brazil | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["ok"] and x["action"]=="updated"'
radio delete 7240002 PU2BBC | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["ok"] and x["action"]=="deleted" and x["persistent"]'
radio check | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["ok"] and x["main"]=="ok" and x["local"]=="ok"'
radio refresh | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["ok"]'
ok 'RadioID status/search/add/edit/delete/check/refresh are functional'

# Exercise the top-level helper with a mocked service boundary. No real XLXD
# process or service is restarted by this test.
printf 'fake-xlxd-binary\n' > "$TMP/core.bin"
SHA="$(sha256sum "$TMP/core.bin" | awk '{print $1}')"
printf '<XLXPNY><Version>2.5.3</Version></XLXPNY>\n' > "$TMP/xlxd.xml"
printf 'line one\nline two\n' > "$TMP/xlx.log"
mkdir -p "$TMP/core-backups/20260915_test"
printf '{"ok":true,"status":"ok"}\n' > "$TMP/health.json"
cat > "$TMP/helper.conf" <<EOF
EXPECTED_SHA='$SHA'
EXPECTED_VERSION='2.5.3'
SERVICE='xlxd.service'
BIN='$TMP/core.bin'
XML='$TMP/xlxd.xml'
LOG='$TMP/xlx.log'
BACKUPS='$TMP/core-backups'
EOF
cat > "$TMP/mockbin/systemctl" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
 is-active) echo active; exit 0;;
 show)
   case "$*" in *MainPID*) echo 4242;; *ActiveEnterTimestamp*) echo 'Mon 2026-09-15 12:00:00 -03';; esac;;
 restart) exit 0;;
 *) exit 0;;
esac
SH
cat > "$TMP/mockbin/pgrep" <<'SH'
#!/usr/bin/env bash
echo 4242
SH
cat > "$TMP/mockbin/ss" <<'SH'
#!/usr/bin/env bash
echo 'UNCONN 0 0 0.0.0.0:42000 0.0.0.0:* users:(("xlxd",pid=4242,fd=1))'
SH
chmod +x "$TMP/mockbin/systemctl" "$TMP/mockbin/pgrep" "$TMP/mockbin/ss"
cp "$ROOT/control/xlx-modern-control-helper" "$TMP/control-helper"
cp "$ROOT/control/xlx-modern-radioid-helper" "$TMP/radio-helper"
cp "$ROOT/control/xlx-modern-access-helper" "$TMP/access-helper"
chmod +x "$TMP/radio-helper" "$TMP/access-helper"
# The production helper intentionally pins PATH. Override only this disposable
# test copy so service commands are simulated.
python3 - "$TMP/control-helper" "$TMP/mockbin" <<'PY'
import sys
p=sys.argv[1]; mock=sys.argv[2]; s=open(p).read(); s=s.replace('PATH=/usr/sbin:/usr/bin:/sbin:/bin',f'PATH={mock}:/usr/sbin:/usr/bin:/sbin:/bin'); open(p,'w').write(s)
PY
chmod +x "$TMP/control-helper"
HELP_ENV=(
 XLX_CONTROL_HELPER_CONF="$TMP/helper.conf"
 XLX_CONTROL_RADIO_HELPER="$TMP/radio-helper"
 XLX_CONTROL_ACCESS_HELPER="$TMP/access-helper"
 XLX_HEALTH_SNAPSHOT="$TMP/health.json"
 "${ACCESS_ENV[@]}" "${RADIO_ENV[@]}"
)
helper(){ run_root env "${HELP_ENV[@]}" "$TMP/control-helper" "$@"; }
out="$(helper status)"; grep -Fxq 'service=active' <<<"$out"
out="$(helper listeners)"; grep -Fq ':42000' <<<"$out"
out="$(helper logs)"; grep -Fq 'line two' <<<"$out"
out="$(helper backups)"; grep -Fq '20260915_test' <<<"$out"
out="$(helper health-status)"; python3 -c 'import json,sys; assert json.loads(sys.argv[1])["ok"]' "$out"
out="$(helper restart)"; grep -Fxq 'processes=1' <<<"$out"
helper access-add-white TEST9 >/dev/null; grep -Fxq TEST9 "$TMP/access/white"
helper access-delete-white TEST9 >/dev/null
helper radioid-search callsign PU2AAA | python3 -c 'import json,sys; assert json.load(sys.stdin)["count"]==1'
ok 'top-level status/listeners/logs/backups/Health/restart/access/RadioID dispatch is functional'
