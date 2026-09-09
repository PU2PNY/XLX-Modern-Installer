#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok(){ echo "OK | $*"; }
bad(){ echo "FAIL | $*" >&2; fail=$((fail+1)); }
for f in "$ROOT/install.sh" "$ROOT/modules/68-control-panel.sh" "$ROOT/modules/69-admin-page.sh"; do
  grep -Fq 'XLX_ERROR_TRACE_V1' "$f" && ok "error trace present: ${f#$ROOT/}" || bad "error trace missing: ${f#$ROOT/}"
done
if grep -Eq 'Controle de Acesso e Interlink|Access Control and Interlink|Quick links' "$ROOT/modules/68-control-panel.sh" "$ROOT/modules/69-admin-page.sh"; then bad 'Admin still validates translated labels'; else ok 'Admin functional validation is translation-independent'; fi
for marker in 'id="access"' 'id="radioid"' 'access-interlink-add' 'radioid_save'; do
  grep -Fq "$marker" "$ROOT/modules/68-control-panel.sh" && ok "Admin stable marker: $marker" || bad "Admin stable marker missing: $marker"
done
if grep -Eq '(^|[^-])\bapt (update|install|upgrade|full-upgrade)' "$ROOT/vendor/pp5pk-installer/installer.sh" "$ROOT/install.sh"; then bad 'apt CLI remains in automation'; else ok 'automation uses apt-get rather than apt'; fi
for pkg in sudo procps iproute2 util-linux openssl rsync python3; do
  grep -Fq "$pkg" "$ROOT/vendor/pp5pk-installer/installer.sh" && ok "dependency declared: $pkg" || bad "dependency missing: $pkg"
done
grep -Fq 'birthday_verified' "$ROOT/dashboard/api/digital-lab-operator.php" && ok 'APRS audit records birthday verification without raw date' || bad 'APRS birthday audit hardening missing'
if grep -nA12 -B2 "'SELF_REGISTER'" "$ROOT/dashboard/api/digital-lab-operator.php" | grep -Eq "'birth_day'|'birth_month'"; then bad 'raw birthday remains in SELF_REGISTER audit detail'; else ok 'raw birthday absent from SELF_REGISTER audit detail'; fi
grep -Fq "if (\$action === 'reset_password')" "$ROOT/dashboard/api/digital-lab-operator.php" && ok 'APRS authorized birthday reset action present' || bad 'APRS birthday reset action missing'
grep -Fq 'auth_version=auth_version+1' "$ROOT/dashboard/api/digital-lab-operator.php" && ok 'APRS reset rotates auth version' || bad 'APRS auth-version rotation missing'
grep -Fq 'revokeRemember' "$ROOT/dashboard/api/digital-lab-operator.php" && ok 'APRS reset revokes remember tokens' || bad 'APRS remember-token revocation missing'
php "$ROOT/tests/test-certificate-hmac.php" || fail=$((fail+1))
grep -Fq '/?page=certificado&validar=' "$ROOT/dashboard/api/certificado.php" && ok 'certificate QR uses native dashboard route' || bad 'native certificate QR route missing'
if grep -REq 'XLX-Certificate-Generator|vendor/xlx-aprs-dprs' "$ROOT/modules" "$ROOT/dashboard"; then bad 'legacy external APRS/certificate architecture remains active'; else ok 'legacy external APRS/certificate architecture absent from active code'; fi
grep -Fq 'INSTALLATION COMPLETE' "$ROOT/install.sh" && ok 'explicit successful terminal state exists' || bad 'installation complete marker missing'
printf 'failures=%d\n' "$fail"
exit "$fail"
