#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT="$ROOT/dashboard/install/xlx-callinghome.php"
WRAPPER="$ROOT/dashboard/install/xlx-callinghome.sh"
SERVICE="$ROOT/dashboard/install/xlx-callinghome.service"
TIMER="$ROOT/dashboard/install/xlx-callinghome.timer"
MODULE="$ROOT/modules/63-callinghome.sh"

fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n "$WRAPPER"
bash -n "$MODULE"
php -l "$CLIENT" >/dev/null

grep -Fq 'CALLHOME_OK http=' "$CLIENT" || fail 'success marker missing'
grep -Fq '<query>CallingHome</query>' "$CLIENT" || fail 'CallingHome XML query missing'
grep -Fq '<interlinks>' "$CLIENT" || fail 'Interlink XML missing'
grep -Fq 'XLX_CALLINGHOME_CONFIG' "$CLIENT" || fail 'testable protected config override missing'
grep -Fq 'XLX_UPTIME' "$CLIENT" || fail 'runtime uptime validation missing'
grep -Fq 'ExecStart=/usr/local/sbin/xlx-modern-callinghome' "$SERVICE" || fail 'service bypasses independent wrapper'
grep -Fq 'ProtectSystem=strict' "$SERVICE" || fail 'service hardening missing'
grep -Fq 'OnUnitActiveSec=5min' "$TIMER" || fail 'five-minute timer missing'
grep -Fq '/xlxd/callinghome.php' "$MODULE" || fail 'legacy hash migration path missing'
grep -Fq 'CALLINGHOME_DASHBOARD_DEPENDENCY=no' "$MODULE" || fail 'independence report missing'
if grep -Fq '/var/www/html' "$CLIENT" "$WRAPPER"; then
  fail 'CallingHome runtime depends on dashboard webroot'
fi

command -v php >/dev/null 2>&1 || fail 'php is required'
if ! php -m | grep -Fxq curl; then
  echo '[SKIP] php-curl is unavailable in this CI image; static CallingHome checks passed'
  exit 0
fi

tmp="$(mktemp -d /tmp/xlx-callinghome-test.XXXXXX)"
server_pid=''
cleanup(){
  [[ -z "$server_pid" ]] || kill "$server_pid" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/server"

cat > "$tmp/server/index.php" <<'PHP'
<?php
file_put_contents(getenv('CAPTURE_FILE'), (string)($_POST['xml'] ?? ''));
header('Content-Type: text/plain');
echo "accepted\n";
PHP

cat > "$tmp/xlxd.xml" <<'XML'
<?xml version="1.0"?>
<XLXReflector><Version>2.5.3</Version></XLXReflector>
XML

cat > "$tmp/xlxd.interlink" <<'EOF'
# preserved comment
ECHO 127.0.0.1 E
XLX123 peer.example.net ABC
EOF

cat > "$tmp/callinghome.php" <<PHP
<?php
return [
 'reflector_name'=>'XLX724',
 'dashboard_url'=>'https://dstarbrasil.com.br',
 'country'=>'Brazil',
 'comment'=>'XLX724 test reflector',
 'hash'=>'0123456789abcdef0123456789abcdef',
 'server_url'=>'http://127.0.0.1:18082/',
 'xml_path'=>'$tmp/xlxd.xml',
 'interlink_path'=>'$tmp/xlxd.interlink',
];
PHP

CAPTURE_FILE="$tmp/captured.xml" php -S 127.0.0.1:18082 -t "$tmp/server" >"$tmp/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 30); do
  curl -fsS http://127.0.0.1:18082/ >/dev/null 2>&1 && break
  sleep 0.1
done

output="$(XLX_UPTIME=12345 XLX_CALLINGHOME_CONFIG="$tmp/callinghome.php" php "$CLIENT")" || fail 'CallingHome client failed against local directory fixture'
printf '%s\n' "$output" | grep -Eq '^CALLHOME_OK http=200 response_bytes=[0-9]+$' || fail 'success marker has unexpected format'
[[ -s "$tmp/captured.xml" ]] || fail 'directory fixture did not receive XML'

grep -Fq '<query>CallingHome</query>' "$tmp/captured.xml" || fail 'captured query is not CallingHome'
grep -Fq '<name>XLX724</name>' "$tmp/captured.xml" || fail 'reflector name missing from payload'
grep -Fq '<uptime>12345</uptime>' "$tmp/captured.xml" || fail 'uptime missing from payload'
grep -Fq '<reflectorversion>2.5.3</reflectorversion>' "$tmp/captured.xml" || fail 'XLXD version missing from payload'
grep -Fq '<name>ECHO</name><address>127.0.0.1</address><modules>E</modules>' "$tmp/captured.xml" || fail 'Echo interlink missing from payload'
grep -Fq '<name>XLX123</name><address>peer.example.net</address><modules>ABC</modules>' "$tmp/captured.xml" || fail 'peer interlink missing from payload'
if grep -Fq '/var/www/html' "$tmp/captured.xml"; then fail 'webroot leaked into CallingHome payload'; fi

ok 'CallingHome XML submission, response validation and dashboard independence passed'
