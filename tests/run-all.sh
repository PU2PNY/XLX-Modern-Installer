#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

echo "[bash syntax]"
while IFS= read -r file; do
  bash -n "$file" && echo "OK | ${file#"$ROOT/"}" || { echo "FAIL | ${file#"$ROOT/"}"; failures=$((failures+1)); }
done < <(find "$ROOT" -type f -name '*.sh' | sort)

echo "[locales]"
grep -F 'Bem-vindo ao XLX Modern Installer' "$ROOT/locales/pt_BR.sh" >/dev/null || failures=$((failures+1))
grep -F 'Welcome to XLX Modern Installer' "$ROOT/locales/en_US.sh" >/dev/null || failures=$((failures+1))
echo "locales_checked=YES"

echo "[independent core]"
bash "$ROOT/tests/test-independent-core.sh" || failures=$((failures+1))

echo "[independent CallingHome]"
bash "$ROOT/tests/test-callinghome.sh" || failures=$((failures+1))

echo "[installation flow]"
bash "$ROOT/tests/test-install-flow.sh" || failures=$((failures+1))

echo "[retired paths]"
bash "$ROOT/tests/test-retired-paths.sh" || failures=$((failures+1))

echo "[dashboard i18n]"
bash "$ROOT/tests/test-dashboard-i18n.sh" || failures=$((failures+1))

echo "[admin i18n]"
bash "$ROOT/tests/test-admin-i18n.sh" || failures=$((failures+1))

echo "[forbidden permissions]"
if grep -RniE --include='*.sh' --exclude='run-all.sh' 'chmod[[:space:]]+(-R[[:space:]]+)?777|chmod[[:space:]]+(-R[[:space:]]+)?666' "$ROOT"; then
  failures=$((failures+1))
else
  echo "forbidden_permissions=NONE"
fi

echo "[destructive operations]"
if grep -RniE --include='*.sh' --exclude='run-all.sh' 'rm[[:space:]]+-rf[[:space:]]+/(|[[:space:]])|mkfs|dd[[:space:]].*of=/dev/' "$ROOT"; then
  failures=$((failures+1))
else
  echo "critical_destructive_patterns=NONE"
fi

echo "failures=$failures"
exit "$failures"
