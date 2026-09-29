#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 -m py_compile "$ROOT/runtime/ai-monitor/xlx-ai-monitor.py"
bash -n "$ROOT/runtime/ai-monitor/xlx-ai-key.sh"
bash -n "$ROOT/runtime/ai-monitor/install.sh"

grep -F "/etc/xlx-ai-monitor.env" "$ROOT/runtime/ai-monitor/xlx-ai-key.sh" >/dev/null
grep -F "chmod 0600" "$ROOT/runtime/ai-monitor/xlx-ai-key.sh" >/dev/null
grep -F "api_connected" "$ROOT/dashboard/api/status.php" >/dev/null
grep -F "RuntimeDirectory=xlx-ai-monitor" "$ROOT/runtime/ai-monitor/xlx-ai-monitor.service" >/dev/null
grep -F "User=www-data" "$ROOT/runtime/ai-monitor/xlx-ai-monitor.service" >/dev/null
grep -F "Group=www-data" "$ROOT/runtime/ai-monitor/xlx-ai-monitor.service" >/dev/null
if grep -F "DynamicUser=yes" "$ROOT/runtime/ai-monitor/xlx-ai-monitor.service" >/dev/null; then
  echo "ERRO: DynamicUser não pode ser usado no estado público do monitor." >&2
  exit 1
fi
grep -F "/run/xlx-ai-monitor/public.json" "$ROOT/dashboard/api/status.php" >/dev/null
grep -F "tx-ai-monitor" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "tx-ai-monitor-wrap" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "tx-top-main" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F 'grid-template-columns:minmax(0,1fr) auto minmax(0,1fr)' "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
grep -F "min-height:25px" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
grep -F '<em class="tx-ai-scan" aria-hidden="true"></em>' "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "primary='IA CONECTADA'" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "text='coletando dados'" "$ROOT/dashboard/assets/app.js" >/dev/null
if grep -F "<b>IA DO SERVIDOR</b>" "$ROOT/dashboard/assets/app.js" >/dev/null; then
  echo "ERRO: rótulo redundante IA DO SERVIDOR voltou ao box TX." >&2
  exit 1
fi
if grep -F "<em>MONITORAMENTO LOCAL ATIVO</em>" "$ROOT/dashboard/assets/app.js" >/dev/null; then
  echo "ERRO: texto redundante MONITORAMENTO LOCAL ATIVO voltou ao box TX." >&2
  exit 1
fi
grep -F "@keyframes xlxmodernAiScanSweep" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
grep -F "@keyframes xlxmodernAiScanTrail" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
grep -F "@media (prefers-reduced-motion: reduce)" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
grep -F "repeating-linear-gradient" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
python3 - "$ROOT/dashboard/assets/app.js" <<'PY'
import pathlib, sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('function xlxmodernUpdateTxAi(live){')
b=s.index('const xlxmodernVuPeakHold', a)
block=s[a:b]
for forbidden in ('fetch(', 'setInterval(', 'setTimeout('):
    if forbidden in block:
        raise SystemExit(f'ERRO: monitor IA introduziu loop/chamada extra: {forbidden}')
print('ai_monitor_no_extra_polling=PASS')
PY
grep -F "xlxmodernUpdateTxAi(live)" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "ai-monitor-v1.css" "$ROOT/dashboard/index.php" >/dev/null

if grep -RniE 'OPENAI_API_KEY=[A-Za-z0-9_-]{20,}' "$ROOT" --exclude='test-ai-monitor-contract.sh'; then
  echo "ERRO: possível chave OpenAI versionada." >&2
  exit 1
fi

if grep -F "fetch(" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null; then
  echo "ERRO: CSS inválido." >&2
  exit 1
fi

echo "ai_monitor_contract=PASS"
