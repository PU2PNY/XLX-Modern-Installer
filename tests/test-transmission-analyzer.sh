#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")/.." && pwd)"

python3 -m py_compile "$ROOT/observability/transmission-analyzer/monitor.py"
python3 "$ROOT/tests/test-transmission-analyzer.py"

grep -F 'AmbientCapabilities=CAP_NET_RAW' "$ROOT/modules/71-observability.sh" >/dev/null
grep -F 'MemoryMax=64M' "$ROOT/modules/71-observability.sh" >/dev/null
grep -F 'CPUQuota=10%' "$ROOT/modules/71-observability.sh" >/dev/null

if grep -F 'OPENAI_API_KEY' "$ROOT/observability/transmission-analyzer/monitor.py" >/dev/null; then
  echo "ERRO: analisador passivo nao deve depender de OpenAI." >&2
  exit 1
fi

echo "transmission_analyzer_contract=PASS"
