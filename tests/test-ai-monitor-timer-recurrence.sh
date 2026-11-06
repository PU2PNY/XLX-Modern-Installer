#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
AI="$ROOT/observability/ai-supervisor/xlx-ai-monitor.timer.d/zz-recurrence.conf"
HELIX="$ROOT/experimental/helix-bridge/systemd/xlx-helix-monitor.timer.d/zz-recurrence.conf"
test -s "$AI"
test -s "$HELIX"
grep -Fx '[Timer]' "$AI" >/dev/null
grep -Fx '[Timer]' "$HELIX" >/dev/null
grep -Fx 'OnUnitActiveSec=' "$AI" >/dev/null
grep -Fx 'OnUnitActiveSec=' "$HELIX" >/dev/null
grep -Fx 'OnUnitInactiveSec=60s' "$AI" >/dev/null
grep -Fx 'OnUnitInactiveSec=30s' "$HELIX" >/dev/null
if grep -E 'ExecStart|OnCalendar|Restart=|sudo|xlxd|xuvd' "$AI" "$HELIX"; then
  echo 'ai_monitor_timer_recurrence=FAIL (unsafe directive)' >&2
  exit 1
fi
echo 'ai_monitor_timer_recurrence=PASS'
