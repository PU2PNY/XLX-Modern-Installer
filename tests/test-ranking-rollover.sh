#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VIEW="$ROOT/dashboard/ranking-v2-view.php"
API="$ROOT/dashboard/api/ranking-v2.php"
COLLECTOR="$ROOT/dashboard/install/ranking-v2-collector.py"
INSTALLER="$ROOT/dashboard/install/install-dashboard.sh"

fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

grep -Fq 'data-p="year">ANUAL</button>' "$VIEW" || fail 'annual ranking tab missing'
grep -Fq "grid-template-columns:repeat(4,1fr)" "$VIEW" || fail 'mobile ranking tabs are not four columns'
grep -Fq "rolled&&!S.manualPeriod&&S.p==='today'" "$VIEW" || fail 'live midnight rollover guard missing'
grep -Fq "Ainda não houve transmissões hoje; exibindo automaticamente os últimos 7 dias." "$VIEW" || fail 'midnight fallback explanation missing'
ok 'ranking view exposes annual period and midnight fallback'

grep -Fq "'year_complete'=>" "$API" || fail 'ranking API year coverage missing'
grep -Fq "'year'=>rank_period" "$API" || fail 'ranking API annual period missing'
grep -Fq "'start_ts'=>" "$API" || fail 'ranking API period boundary missing'
php -l "$API" >/dev/null
ok 'ranking API exposes annual period and period boundaries'

python3 - "$COLLECTOR" <<'PY'
import ast,sys
s=open(sys.argv[1],encoding='utf-8').read()
ast.parse(s)
for needle in (
    'year = today.replace(month=1, day=1)',
    '"year_complete"',
    '"year": stats(conn, int(year.timestamp()), tz)',
    '400 * 86400',
):
    assert needle in s, needle
PY
ok 'persistent collector retains annual ranking logic'

grep -Fq 'ranking-v2-collector.py' "$INSTALLER" || fail 'ranking collector is not provisioned by dashboard installer'
grep -Fq 'xlx-modern-ranking-v2.timer' "$INSTALLER" || fail 'ranking timer is not provisioned by dashboard installer'
bash -n "$INSTALLER"
ok 'fresh install provisions persistent ranking collector'
