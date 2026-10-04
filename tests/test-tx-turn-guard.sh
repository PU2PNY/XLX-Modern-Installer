#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT/experimental/tx-turn-guard"
PATCH="$BASE/patches/xlxd-2.5.3-anti-ping-pong-v1.patch"
MON="$BASE/monitor/xlx-tx-turn-ai-monitor.py"
SVC="$BASE/systemd/xlx-tx-turn-ai-monitor.service"
TIMER="$BASE/systemd/xlx-tx-turn-ai-monitor.timer"
README="$BASE/README.md"

python3 -m py_compile "$MON"
python3 "$MON" --self-test | grep -F 'tx_turn_ai_monitor_self_test=PASS' >/dev/null

test -s "$PATCH"
grep -F 'XLX_TX_TURN_GUARD' "$PATCH" >/dev/null
grep -F 'XLX_TX_TURN_TRIGGER_MS' "$PATCH" >/dev/null
grep -F 'XLX_TX_TURN_COOLDOWN_MS' "$PATCH" >/dev/null
grep -F 'TXTURN event=pair_detected' "$PATCH" >/dev/null
grep -F 'TXTURN event=blocked' "$PATCH" >/dev/null
grep -F 'TXTURN event=third_party_break' "$PATCH" >/dev/null

# V1 defaults: disabled unless explicitly enabled; 2 s detection and 7 s pair cooldown.
grep -F 'strcmp(enabled, "1")' "$PATCH" >/dev/null
grep -F '2000' "$PATCH" >/dev/null
grep -F '7000' "$PATCH" >/dev/null

# Privacy invariant: structured TXTURN events carry module/timing only, not identity.
if grep -E 'TXTURN event=.*(callsign=|station=|radioid=|user=|ip=)' "$PATCH"; then
  echo 'tx_turn_guard=FAIL identity leaked in TXTURN event'
  exit 1
fi

# AI must remain advisory and outside the C++ patch/hot path.
if grep -Ei 'openai|api\.openai\.com|curl|urllib' "$PATCH"; then
  echo 'tx_turn_guard=FAIL remote AI leaked into XLXD patch'
  exit 1
fi
grep -F "'advisory_only': True" "$MON" >/dev/null
grep -F 'https://api.openai.com/v1/responses' "$MON" >/dev/null
grep -F "OPENAI_TX_TURN_MODEL', 'gpt-6-luna'" "$MON" >/dev/null
grep -F 'OnUnitActiveSec=60s' "$TIMER" >/dev/null
grep -F 'SupplementaryGroups=systemd-journal' "$SVC" >/dev/null
grep -F 'TOT existente de 180 s' "$README" >/dev/null

echo 'tx_turn_guard=PASS'
