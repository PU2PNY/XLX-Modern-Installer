#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MON="$ROOT/experimental/helix-bridge/monitor/xlx-helix-monitor.py"
SVC="$ROOT/experimental/helix-bridge/systemd/xlx-helix-monitor.service"
TIMER="$ROOT/experimental/helix-bridge/systemd/xlx-helix-monitor.timer"
PROCESS_SVC="$ROOT/experimental/helix-bridge/systemd/helix-voice-process-test.service"
PROCESS_DROPIN="$ROOT/experimental/helix-bridge/systemd/xlx-unified-voice-process-test.conf"
API="$ROOT/dashboard/api/helix-status.php"
JS="$ROOT/dashboard/assets/helix-shadow-monitor-v1.js"

python3 -m py_compile "$MON"
php -l "$API" >/dev/null
if command -v node >/dev/null 2>&1; then node --check "$JS"; fi

grep -F "OnUnitActiveSec=30s" "$TIMER" >/dev/null
grep -F "EnvironmentFile=-/etc/xlx-ai-monitor.env" "$SVC" >/dev/null
grep -F "now-last_ai>=900" "$MON" >/dev/null
grep -F "https://api.openai.com/v1/responses" "$MON" >/dev/null
grep -F "'mode':mode" "$MON" >/dev/null
grep -F "recent_fallback" "$MON" >/dev/null
grep -F "recent_consecutive_max" "$MON" >/dev/null
grep -F "recent_stream_disabled" "$MON" >/dev/null
grep -F "recent_consecutive_max" "$API" >/dev/null
grep -F "recent_stream_disabled" "$API" >/dev/null
grep -F "XLX_HELIX_MODE=process" "$PROCESS_DROPIN" >/dev/null
grep -F "XLX_HELIX_TIMEOUT_MS=5" "$PROCESS_DROPIN" >/dev/null
grep -F -- "--pcm-bridge /run/helix-voice/pcm.sock" "$PROCESS_SVC" >/dev/null
grep -F "const label=processing?'PROCESSANDO TESTE':(active?'MONITORANDO':'INDISPONÍVEL');" "$JS" >/dev/null
grep -F "O áudio transmitido continua no caminho legado." "$JS" >/dev/null
grep -F "dataset.helixSignature" "$JS" >/dev/null
grep -F "PROCESSANDO TESTE" "$JS" >/dev/null
grep -F "process_active" "$API" >/dev/null
grep -F "helix-voice-process-test.service" "$MON" >/dev/null
grep -F "helix=(shadow|process)" "$MON" >/dev/null

if grep -R -n -F "XLX_HELIX_MODE=process" "$MON" "$SVC" "$TIMER" "$API" "$JS"; then
  echo "helix_shadow_monitor=FAIL process mode leaked into monitor"
  exit 1
fi

echo "helix_shadow_monitor=PASS"
