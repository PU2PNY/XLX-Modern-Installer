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
grep -F "IA DO SERVIDOR" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "MONITORAMENTO LOCAL ATIVO" "$ROOT/dashboard/assets/app.js" >/dev/null
grep -F "min-height:34px" "$ROOT/dashboard/assets/ai-monitor-v1.css" >/dev/null
if grep -Eq '@keyframes|animation[[:space:]]*:' "$ROOT/dashboard/assets/ai-monitor-v1.css"; then
  echo "ERRO: banner IA não pode usar animação contínua." >&2
  exit 1
fi
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
