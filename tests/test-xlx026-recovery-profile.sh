#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
P="$ROOT/profiles/xlx026-prod-20261017"
fail(){ echo "FAIL | $*" >&2; exit 1; }
[ -s "$P/PRODUCTION_MANIFEST.json" ] || fail manifest
[ -s "$P/dashboard-overlay/assets/app.js" ] || fail app_overlay
[ -s "$P/dashboard-overlay/assets/live-core-v2-client.js" ] || fail v2_client
[ -s "$P/runtime/live-core-v2/src/main.rs" ] || fail live_core
[ -s "$P/runtime/live-hub/server.js" ] || fail live_hub
[ -s "$P/runtime/xuvd/xuvd.cpp" ] || fail xuvd_source
[ -s "$P/runtime/nginx/xlx026-live-runtime.conf" ] || fail nginx_live_routes
[ -s "$P/control/index.php" ] || fail control
python3 - "$P/PRODUCTION_MANIFEST.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
assert m['profile']=='xlx026-prod-20261017'
assert m['secrets_committed'] is False
assert len(m['dashboard_overlay_files']) >= 100
expected={
'/xlxd/xlxd':'9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0',
'/opt/xlx-unified-voice/bin/xuvd':'d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884',
'/opt/helix-voice/bin/helix-daemon':'7c4292bfe5610bc22870308b6c5b934b492caf4d579626586ac30da4c2ff6745',
'/usr/local/bin/xlx026-live-core-v2':'83977c221a327a6d39d7fd12a6aa1170274b3fa71de367934ce8fd87601099ed'}
for p,h in expected.items(): assert m['runtime_binaries'][p]['sha256']==h
PY
# No secret-bearing files may exist in the public profile.
if find "$P" -type f \( -name '*.key' -o -name '*.pem' -o -name '.env' -o -name '*.db' -o -name '*.sqlite' -o -name '*.sql' -o -name '*.pcap' \) | grep -q .; then fail private_artifact; fi
if grep -RIlE 'sk-[A-Za-z0-9_-]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|OPENAI_API_KEY=[^[:space:]]+' "$P" | grep -q .; then fail secret_pattern; fi
grep -F -- '--profile=NAME' "$ROOT/install.sh" >/dev/null || fail profile_help
grep -F 'modules/69-runtime-profile.sh' "$ROOT/install.sh" >/dev/null || fail profile_hook
grep -F 'location = /api/live-v2/ws' "$P/runtime/nginx/xlx026-live-runtime.conf" >/dev/null || fail ws_route
grep -F 'location = /api/live-stream' "$P/runtime/nginx/xlx026-live-runtime.conf" >/dev/null || fail sse_route
grep -F 'location = /sw.js' "$P/runtime/nginx/xlx026-live-runtime.conf" >/dev/null || fail sw_cache
bash -n "$ROOT/modules/69-runtime-profile.sh"
echo 'xlx026_recovery_profile=PASS'
