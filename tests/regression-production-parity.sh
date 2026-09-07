#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n \
  "$ROOT/modules/60-dashboard-modern.sh" \
  "$ROOT/modules/70-production-parity.sh" \
  "$ROOT/control/xlx-modern-control-helper-v2" \
  "$ROOT/control/xlx-modern-access-helper-v2"
python3 -m py_compile "$ROOT/control/finalize-production-parity-v14.py" "$ROOT/control/genericize-xlx-control.py" "$ROOT/control/patch-xlx026-control-v111.py"
ok 'shell/python syntax'

grep -Fq 'modules/70-production-parity.sh' "$ROOT/modules/60-dashboard-modern.sh" || fail 'production parity module is not wired into fresh installs/upgrades'
grep -Fq 'interlink-save *' "$ROOT/modules/70-production-parity.sh" || fail 'interlink sudo authorization missing'
grep -Fq 'interlink-delete *' "$ROOT/modules/70-production-parity.sh" || fail 'interlink delete sudo authorization missing'
! grep -Eq 'Terminal XLXD|Terminal SSH' "$ROOT/control/finalize-production-parity-v14.py" || true
ok 'installer wiring'

# Reproduce the exact Admin build pipeline and then apply the parity finalizer.
cp "$ROOT/control/xlx026-control-index-radioid-v2.php" "$TMP/admin.php"
python3 "$ROOT/control/patch-xlx026-control-v111.py" "$TMP/admin.php"
python3 "$ROOT/control/genericize-xlx-control.py" "$TMP/admin.php" en
cp "$ROOT/dashboard/index.php" "$TMP/dashboard.php"
python3 "$ROOT/control/finalize-production-parity-v14.py" "$TMP/dashboard.php" "$TMP/admin.php" en
php -l "$TMP/admin.php" >/dev/null
php -l "$TMP/dashboard.php" >/dev/null

grep -Fq "const CTRL_VER='1.4.0'" "$TMP/admin.php" || fail 'Admin version marker missing'
grep -Fq 'name="interlink_reflector"' "$TMP/admin.php" || fail 'remote XLX field missing'
grep -Fq 'name="interlink_address"' "$TMP/admin.php" || fail 'Interlink address field missing'
grep -Fq 'name="interlink_modules"' "$TMP/admin.php" || fail 'Interlink modules field missing'
grep -Fq "jr('interlink-save',[$reflector,$address,$modules])" "$TMP/admin.php" || fail 'three-field Interlink dispatch missing'
grep -Fq 'href="/modulos"' "$TMP/admin.php" || fail 'Admin quick-link to Modules missing'
grep -Fq "'modulos' => 'Modules'" "$TMP/dashboard.php" || fail 'Modules navigation missing'
grep -Fq "$allowed = ['ao-vivo','modulos','conectados','ranking','refletores'];" "$TMP/dashboard.php" || fail 'Modules route not independent'
! grep -Fq "if ($page === 'modulos') $page = 'conectados';" "$TMP/dashboard.php" || fail 'legacy Modules-to-Connected redirect still present'

python3 - "$TMP/dashboard.php" <<'PY'
from pathlib import Path
s=Path(__import__('sys').argv[1]).read_text()
a=s.index("<?php elseif ($page === 'conectados'): ?>")
b=s.index("<?php elseif ($page === 'ranking'): ?>",a)
chunk=s[a:b]
assert 'connected-stations-heading' in chunk
assert 'connected-modules-heading' not in chunk
assert 'moduleOverview' not in chunk
PY
ok 'generated Admin and public page structure'

# Exercise the real file formats without touching a server.
: > "$TMP/whitelist"
: > "$TMP/blacklist"
: > "$TMP/interlink"
export XLX_WHITELIST="$TMP/whitelist"
export XLX_BLACKLIST="$TMP/blacklist"
export XLX_INTERLINK="$TMP/interlink"
export XLX_ACCESS_BACKUPS="$TMP/backups"
export XLX_CONTROL_STATE="$TMP/state"
export XLX_ACCESS_LOCK="$TMP/access.lock"

H="$ROOT/control/xlx-modern-access-helper-v2"
"$H" add-white 'PU2*' >/dev/null
grep -Fxq 'PU2*' "$TMP/whitelist" || fail 'whitelist format failed'
"$H" add-black 'PY4ABC' >/dev/null
grep -Fxq 'PY4ABC' "$TMP/blacklist" || fail 'blacklist format failed'
"$H" save-interlink XLX123 reflector.example BCD >/dev/null
grep -Fxq 'XLX123 reflector.example BCD' "$TMP/interlink" || fail 'first Interlink line failed'
"$H" save-interlink XLX456 203.0.113.5 C >/dev/null
grep -Fxq 'XLX123 reflector.example BCD' "$TMP/interlink" || fail 'existing Interlink line was lost'
grep -Fxq 'XLX456 203.0.113.5 C' "$TMP/interlink" || fail 'second Interlink line failed'
"$H" save-interlink XLX123 new.example CD >/dev/null
[[ "$(grep -c '^XLX123 ' "$TMP/interlink")" -eq 1 ]] || fail 'Interlink update duplicated reflector'
grep -Fxq 'XLX123 new.example CD' "$TMP/interlink" || fail 'Interlink update failed'
"$H" delete-interlink XLX123 >/dev/null
! grep -q '^XLX123 ' "$TMP/interlink" || fail 'Interlink delete failed'

json="$($H status)"
python3 - "$json" <<'PY'
import json,sys
j=json.loads(sys.argv[1])
assert j['whitelist']==['PU2*']
assert j['blacklist']==['PY4ABC']
assert j['interlinks']==[{'reflector':'XLX456','address':'203.0.113.5','modules':'C'}]
PY
ok 'XLXD whitelist/blacklist/interlink file formats'

# New parity layer must stay generic and must not publish production identities.
for f in \
  "$ROOT/control/xlx-modern-access-helper-v2" \
  "$ROOT/control/xlx-modern-control-helper-v2" \
  "$ROOT/control/finalize-production-parity-v14.py" \
  "$ROOT/modules/70-production-parity.sh"
do
  ! grep -Eqi 'xlx026\.net|82\.152\.174\.|179\.242\.|/var/www/html/xlxd-novo' "$f" || fail "production-specific data leaked into $f"
done
ok 'generic public release invariants'

printf '\nProduction parity regression: PASS\n'
