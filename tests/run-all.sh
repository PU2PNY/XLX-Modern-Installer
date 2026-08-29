#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
echo "[bash syntax]"
while IFS= read -r file; do bash -n "$file" && echo "OK | ${file#"$ROOT/"}" || { echo "FAIL | ${file#"$ROOT/"}"; failures=$((failures+1)); }; done < <(find "$ROOT" -type f -name '*.sh' | sort)
echo "[locales]"
grep -F 'Bem-vindo ao XLX Modern Installer' "$ROOT/locales/pt_BR.sh" >/dev/null || failures=$((failures+1))
grep -F 'Welcome to XLX Modern Installer' "$ROOT/locales/en_US.sh" >/dev/null || failures=$((failures+1))
echo "locales_checked=YES"
echo "[installation flow]"
bash "$ROOT/tests/test-install-flow.sh" || failures=$((failures+1))
echo "[forbidden permissions]"
if grep -RniE --include='*.sh' --exclude='run-all.sh' 'chmod[[:space:]]+(-R[[:space:]]+)?777|chmod[[:space:]]+(-R[[:space:]]+)?666' "$ROOT"; then failures=$((failures+1)); else echo "forbidden_permissions=NONE"; fi
echo "[destructive operations]"
if grep -RniE --include='*.sh' --exclude='run-all.sh' 'rm[[:space:]]+-rf[[:space:]]+/(|[[:space:]])|mkfs|dd[[:space:]].*of=/dev/' "$ROOT"; then failures=$((failures+1)); else echo "critical_destructive_patterns=NONE"; fi
echo "failures=$failures"
exit "$failures"
