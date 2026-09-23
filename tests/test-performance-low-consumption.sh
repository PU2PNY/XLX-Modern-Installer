#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dashboard/assets/app.js"
RUNTIME="$ROOT/dashboard/api/runtime.php"
HEALTH="$ROOT/observability/health/health_monitor.py"

php -l "$RUNTIME" >/dev/null
python3 -m py_compile "$HEALTH"

if command -v node >/dev/null 2>&1; then
  node --check "$APP"
fi

grep -F "Date.now()-xlxmodernAprsPresenceAt<60000" "$APP" >/dev/null
grep -F "const eagerLookup=Boolean(root&&root.id==='moduleGrid')" "$APP" >/dev/null
grep -F "let xlxmodernConnectedRowsSignature=''" "$APP" >/dev/null
grep -F "function xlxmodernHistoryQuickKey(d)" "$APP" >/dev/null
grep -F "function xlxmodernStatusInterval()" "$APP" >/dev/null
grep -F "if(page==='ao-vivo')return 15000;" "$APP" >/dev/null
grep -F "if(page==='conectados')return 30000;" "$APP" >/dev/null
grep -F "if(page==='modulos'||page==='ranking')return 60000;" "$APP" >/dev/null
grep -F "Date.now()-xlxmodernStatusHiddenAt>300000" "$APP" >/dev/null
grep -F "'manual-enable'" "$APP" >/dev/null
grep -F "clearConnectedVoiceEventTimer();" "$APP" >/dev/null

if grep -F "clearConnectedVoiceTimer();" "$APP" >/dev/null; then
  echo "legacy_connected_voice_timer=FAIL"
  exit 1
fi

grep -F "function dashboard_status(history24=False):" "$HEALTH" >/dev/null
grep -F 'PUBLIC_URL + "/api/runtime.php"' "$HEALTH" >/dev/null
grep -F 'PUBLIC_URL + "/api/status.php?history_hours=24"' "$HEALTH" >/dev/null
if grep -F "history_hours=24&control=1" "$HEALTH" >/dev/null; then
  echo "health_cache_bypass=FAIL"
  exit 1
fi

grep -F "'connected_count' => count($compactConnections)" "$RUNTIME" >/dev/null
grep -F "'callsign' =>" "$RUNTIME" >/dev/null
grep -F "'protocol' =>" "$RUNTIME" >/dev/null
grep -F "'module' =>" "$RUNTIME" >/dev/null
if grep -E "['\"](ip|peer|endpoint_ip)['\"]" "$RUNTIME" >/dev/null; then
  echo "runtime_privacy=FAIL"
  exit 1
fi

echo "performance_low_consumption=OK"
