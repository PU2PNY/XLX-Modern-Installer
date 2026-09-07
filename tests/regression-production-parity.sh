#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n "$ROOT/modules/60-dashboard-modern.sh" "$ROOT/modules/70-production-parity.sh" "$ROOT/control/xlx-modern-control-helper" "$ROOT/control/xlx-modern-access-helper"
python3 -m py_compile "$ROOT/control/build-admin.py"
php -l "$ROOT/control/current-production-admin.php" >/dev/null
ok 'canonical Admin/helper syntax'

grep -Fq 'modules/70-production-parity.sh' "$ROOT/modules/60-dashboard-modern.sh" || fail 'final parity validation not wired into dashboard install'
grep -Fq 'modules/71-observability.sh' "$ROOT/install.sh" || fail 'observability not wired into full install'
grep -Fq 'modules/67-aprs-dprs.sh' "$ROOT/install.sh" || fail 'APRS/D-PRS not wired into full install'
ok 'installer wiring'

for locale in pt-BR en; do
  cp "$ROOT/control/current-production-admin.php" "$TMP/admin-$locale.php"
  python3 "$ROOT/control/build-admin.py" "$TMP/admin-$locale.php" "$locale"
  php -l "$TMP/admin-$locale.php" >/dev/null
done
grep -Fq "const CTRL_VER='1.5.1'" "$TMP/admin-en.php" || fail 'Admin version marker missing'
grep -Fq 'access-interlink-add' "$TMP/admin-en.php" || fail 'Interlink add dispatch missing'
grep -Fq 'access-interlink-delete' "$TMP/admin-en.php" || fail 'Interlink delete dispatch missing'
grep -Fq 'health-status' "$TMP/admin-en.php" || fail 'Health action missing'
grep -Fq 'radioid_api_search' "$TMP/admin-en.php" || fail 'RadioID.net action missing'
! grep -Eq 'Terminal XLXD|Terminal SSH' "$TMP/admin-en.php" || fail 'forbidden terminal feature present'
grep -Fq "\$allowed = ['ao-vivo','modulos','conectados','ranking','refletores'];" "$ROOT/dashboard/index.php" || fail 'Modules route not independent'
grep -Fq "<?php elseif (\$page === 'modulos'): ?>" "$ROOT/dashboard/index.php" || fail 'Modules page missing'
ok 'Admin and public page structure'

: > "$TMP/whitelist"; : > "$TMP/blacklist"; : > "$TMP/interlink"
export XLX_WHITELIST="$TMP/whitelist" XLX_BLACKLIST="$TMP/blacklist" XLX_INTERLINK="$TMP/interlink"
export XLX_ACCESS_BACKUPS="$TMP/backups" XLX_CONTROL_STATE="$TMP/state" XLX_ACCESS_LOCK="$TMP/access.lock"
H="$ROOT/control/xlx-modern-access-helper"
runh(){ bash "$H" "$@"; }
runh add-white 'PU2*' >/dev/null; grep -Fxq 'PU2*' "$TMP/whitelist" || fail 'whitelist format failed'
runh add-black 'PY4ABC' >/dev/null; grep -Fxq 'PY4ABC' "$TMP/blacklist" || fail 'blacklist format failed'
runh interlink-add XLX123 reflector.example BCD >/dev/null; grep -Fxq 'XLX123 reflector.example BCD' "$TMP/interlink" || fail 'first Interlink line failed'
runh interlink-add XLX456 203.0.113.5 C >/dev/null; grep -Fxq 'XLX456 203.0.113.5 C' "$TMP/interlink" || fail 'second Interlink line failed'
runh interlink-add XLX123 new.example CD >/dev/null
[[ "$(grep -c '^XLX123 ' "$TMP/interlink")" -eq 1 ]] || fail 'Interlink update duplicated reflector'
grep -Fxq 'XLX123 new.example CD' "$TMP/interlink" || fail 'Interlink update failed'
runh interlink-delete XLX123 >/dev/null; ! grep -q '^XLX123 ' "$TMP/interlink" || fail 'Interlink delete failed'
json="$(runh status)"
python3 - "$json" <<'PY'
import json,sys
j=json.loads(sys.argv[1]); assert j['whitelist']==['PU2*']; assert j['blacklist']==['PY4ABC']
assert j['interlinks']==[{'callsign':'XLX456','address':'203.0.113.5','modules':'C'}]
PY
ok 'XLXD whitelist/blacklist/interlink formats'

for f in "$ROOT/control/current-production-admin.php" "$ROOT/control/build-admin.py" "$ROOT/control/xlx-modern-control-helper" "$ROOT/control/xlx-modern-access-helper" "$ROOT/modules/70-production-parity.sh"; do
  ! grep -Eqi '/root/production-backups|/var/www/html/legacy-dashboard' "$f" || fail "production-specific data leaked into $f"
done
ok 'generic public release invariants'
printf '\nProduction parity regression: PASS\n'
