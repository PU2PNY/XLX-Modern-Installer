#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d /tmp/xlx-callinghome-test.XXXXXX)"
cleanup(){ [[ -z "${SERVER_PID:-}" ]] || kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }
ok(){ printf 'OK | %s\n' "$*"; }

# Contract constants must match the upstream XLXD dashboard.
grep -Fq "'server_url' => 'http://xlxapi.rlx.lu/api.php'" "$ROOT/dashboard/install/install-dashboard.sh" || fail 'official CallingHome server URL drifted'
grep -Fq 'OnUnitActiveSec=10min' "$ROOT/dashboard/install/xlx-callinghome.timer" || fail 'CallingHome timer is not the upstream 600-second cadence'
grep -Fq 'for($i=0;$i<16;$i++)' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'new CallingHome hash is not 16 characters'

cat > "$TMP/xlxd.xml" <<'XML'
<XLXPNY><Version>2.5.3</Version></XLXPNY>
XML
cat > "$TMP/interlink" <<'EOF'
XLX123 203.0.113.10 AC
EOF

PORT_FILE="$TMP/port"
CAPTURE="$TMP/capture.json"
python3 - "$PORT_FILE" "$CAPTURE" <<'PY' &
import http.server,json,socketserver,sys,urllib.parse
port_file,capture=sys.argv[1:]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n=int(self.headers.get('Content-Length','0'))
        body=self.rfile.read(n).decode()
        form=urllib.parse.parse_qs(body,keep_blank_values=True)
        with open(capture,'w') as f:
            json.dump({'path':self.path,'content_type':self.headers.get('Content-Type'),'form':form},f)
        self.send_response(200); self.end_headers(); self.wfile.write(b'OK')
    def log_message(self,*a): pass
with socketserver.TCPServer(('127.0.0.1',0),H) as srv:
    with open(port_file,'w') as f: f.write(str(srv.server_address[1]))
    srv.handle_request()
PY
SERVER_PID=$!
for _ in $(seq 1 50); do [[ -s "$PORT_FILE" ]] && break; sleep .05; done
[[ -s "$PORT_FILE" ]] || fail 'mock CallingHome server did not start'
PORT="$(cat "$PORT_FILE")"
cat > "$TMP/config.php" <<PHP
<?php
return [
 'reflector_name'=>'XLXPNY',
 'dashboard_url'=>'https://example.invalid',
 'country'=>'Brazil',
 'comment'=>'Contract test',
 'hash'=>'AbC123xYz987Qwer',
 'server_url'=>'http://127.0.0.1:$PORT/api.php',
 'xml_path'=>'$TMP/xlxd.xml',
 'interlink_path'=>'$TMP/interlink',
];
PHP
XLX_CALLINGHOME_CONFIG="$TMP/config.php" php "$ROOT/dashboard/install/xlx-callinghome.php" > "$TMP/client.out"
wait "$SERVER_PID"; SERVER_PID=''
grep -Fq 'CallingHome accepted by directory (HTTP 200).' "$TMP/client.out" || fail 'client did not accept HTTP 200'
python3 - "$CAPTURE" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); f=x.get('form',{}); xml=(f.get('xml') or [''])[0]
assert x['path']=='/api.php',x
assert x['content_type']=='application/x-www-form-urlencoded',x
for token in (
 '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
 '<query>CallingHome</query>', '<name>XLXPNY</name>',
 '<hash>AbC123xYz987Qwer</hash>', '<url>https://example.invalid</url>',
 '<country>Brazil</country>', '<comment>Contract test</comment>',
 '<reflectorversion>2.5.3</reflectorversion>',
 '<interlink><name>XLX123</name><address>203.0.113.10</address><modules>AC</modules></interlink>'
): assert token in xml,(token,xml)
PY
ok 'CallingHome contract matches XLXD XML POST and 600-second cadence'
