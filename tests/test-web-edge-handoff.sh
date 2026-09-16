#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$ROOT/modules/60-dashboard-modern.sh"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }

for marker in \
  'PREVIOUS_NGINX_ACTIVE=0' \
  'WEB_EDGE_HANDOFF=0' \
  'trap restore_previous_nginx_on_failure EXIT' \
  'systemctl stop nginx.service' \
  'systemctl stop apache2.service' \
  'systemctl start nginx.service' \
  'WEB_EDGE_HANDOFF=1'; do
  grep -Fq "$marker" "$MODULE" || fail "missing recovery web-edge handoff marker: $marker"
done

python3 - "$MODULE" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
runtime = s.index('bash "$ROOT/modules/64-runtime-data.sh"')
stop_nginx = s.index('systemctl stop nginx.service', runtime)
dashboard = s.index('bash "$ROOT/dashboard/install/install-dashboard.sh"', stop_nginx)
admin = s.index('bash "$ROOT/modules/69-admin-page.sh"', dashboard)
if not (runtime < stop_nginx < dashboard < admin):
    raise SystemExit('Nginx handoff must occur after runtime preparation and before Apache dashboard provisioning')
restore = s.index('restore_previous_nginx_on_failure')
stop_apache = s.index('systemctl stop apache2.service', restore)
start_nginx = s.index('systemctl start nginx.service', stop_apache)
if not (restore < stop_apache < start_nginx):
    raise SystemExit('failure rollback must stop Apache before restoring Nginx')
PY

printf 'OK | partial-install recovery serializes Apache/Nginx port ownership and restores Nginx on failure\n'
