#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
fail(){ printf '[FAIL] %s\n' "$*" >&2; failures=$((failures+1)); }
ok(){ printf '[OK] %s\n' "$*"; }

# Physical production webroot retired in September 2026. Active installers,
# Admin code and runtime helpers must never recreate or depend on it.
if grep -RniF --include='*.sh' --include='*.py' --include='*.php' \
  '/var/www/html/xlxd-novo' \
  "$ROOT/install.sh" "$ROOT/install-control.sh" "$ROOT/modules" "$ROOT/control" \
  "$ROOT/dashboard/install" "$ROOT/tools" "$ROOT/runtime" 2>/dev/null; then
  fail 'active installation/runtime code still references /var/www/html/xlxd-novo'
else
  ok 'retired xlxd-novo webroot is absent from active installation/runtime code'
fi

# The previous generic dashboard name may remain only as an explicit migration
# fallback in update.sh. It must not be a default in clean or isolated installs.
if grep -RniF --include='*.sh' --include='*.py' --include='*.php' \
  '/var/www/html/xlx-dashboard' \
  "$ROOT/install.sh" "$ROOT/install-control.sh" "$ROOT/modules" "$ROOT/control" \
  "$ROOT/dashboard/install" "$ROOT/tools" "$ROOT/runtime" 2>/dev/null; then
  fail 'active clean-install/Admin code still references /var/www/html/xlx-dashboard'
else
  ok 'clean-install/Admin code uses only the canonical /var/www/html/xlxd webroot'
fi

grep -Fq '/var/www/html/xlxd' "$ROOT/install.sh" || fail 'main installer does not declare canonical xlxd dashboard root'
grep -Fq '/var/www/html/xlxd' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'dashboard installer does not declare canonical xlxd root'
grep -Fq '/var/www/html/xlxd' "$ROOT/modules/68-control-panel.sh" || fail 'Admin bootstrap does not declare canonical xlxd root'
grep -Fq '/var/www/html/xlxd' "$ROOT/modules/69-admin-page.sh" || fail 'isolated Admin installer does not declare canonical xlxd root'

# Terminal options are a native XLXD core file and can continue to exist in the
# PP5PK base. It is intentionally NOT an Admin web function anymore.
if grep -Fq '/xlxd/xlxd.terminal' "$ROOT/modules/68-control-panel.sh" "$ROOT/modules/69-admin-page.sh"; then
  fail 'Admin still depends on xlxd.terminal'
else
  ok 'Admin no longer exposes or requires terminal configuration'
fi

grep -Fq '/xlxd/xlxd.interlink' "$ROOT/control/xlx-modern-access-helper" || fail 'Interlink helper does not target native xlxd.interlink'

echo "failures=$failures"
exit "$failures"
