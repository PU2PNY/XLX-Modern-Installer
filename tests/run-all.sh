#!/usr/bin/env bash
set -Eeuo pipefail
export PYTHONDONTWRITEBYTECODE=1
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
run_check(){
  local rc
  if "$@"; then return 0; else rc=$?; fi
  printf "FAIL | %s (exit %s)\n" "$*" "$rc" >&2
  failures=$((failures+1))
}
echo "[bash syntax]"
while IFS= read -r file; do bash -n "$file" && echo "OK | ${file#"$ROOT/"}" || { echo "FAIL | ${file#"$ROOT/"}"; failures=$((failures+1)); }; done < <(find "$ROOT" -type f -name '*.sh' | sort)
echo "[locales]"
grep -F 'Bem-vindo ao XLX Modern Installer' "$ROOT/locales/pt_BR.sh" >/dev/null || failures=$((failures+1))
grep -F 'Welcome to XLX Modern Installer' "$ROOT/locales/en_US.sh" >/dev/null || failures=$((failures+1))
echo "locales_checked=YES"
echo "[installer language contract]"
run_check bash "$ROOT/tests/test-installer-language-contract.sh"

echo "[dashboard locale key parity]"
run_check php "$ROOT/tests/test-dashboard-locale-key-parity.php"

echo "[installation flow]"
run_check bash "$ROOT/tests/test-install-flow.sh"
echo "[web edge handoff]"
run_check bash "$ROOT/tests/test-web-edge-handoff.sh"
echo "[dashboard i18n]"
run_check bash "$ROOT/tests/test-dashboard-i18n.sh"
echo "[admin i18n]"
run_check bash "$ROOT/tests/test-admin-i18n.sh"
echo "[admin slug contract]"
run_check bash "$ROOT/tests/test-admin-slug-contract.sh"
echo "[admin route readiness]"
run_check bash "$ROOT/tests/test-admin-route-readiness.sh"
echo "[admin password storage contract]"
run_check bash "$ROOT/tests/test-admin-password-storage-contract.sh"
echo "[canonical navigation]"
run_check bash "$ROOT/tests/test-canonical-navigation.sh"
echo "[vendored installer]"
run_check bash "$ROOT/tests/test-vendored-installer.sh"
echo "[native i18n]"
run_check php "$ROOT/tests/test-native-i18n.php"
echo "[route i18n]"
run_check php "$ROOT/tests/test-route-i18n.php"
echo "[https rate limit]"
run_check bash "$ROOT/tests/test-https-rate-limit.sh"
echo "[callinghome contract]"
run_check bash "$ROOT/tests/test-callinghome-contract.sh"
echo "[control functional sandbox]"
run_check bash "$ROOT/tests/test-control-functional.sh"
echo "[current panel runtime parity]"
run_check bash "$ROOT/tests/test-current-panel-runtime-parity.sh"
echo "[connected station dedupe]"
run_check bash "$ROOT/tests/test-connected-dedupe.sh"
echo "[ranking rollover]"
run_check bash "$ROOT/tests/test-ranking-rollover.sh"
echo "[transmission analyzer]"
run_check bash "$ROOT/tests/test-transmission-analyzer.sh"
echo "[helix pcm fallback]"
run_check bash "$ROOT/tests/test-helix-pcm-fallback.sh"
echo "[helix total deadline]"
run_check bash "$ROOT/tests/test-helix-pcm-deadline.sh"
echo "[helix shadow monitor]"
run_check bash "$ROOT/tests/test-helix-shadow-monitor.sh"
echo "[stereotool lab foundation]"
run_check bash "$ROOT/tests/test-stereotool-foundation.sh"
echo "[tx turn guard]"
run_check bash "$ROOT/tests/test-tx-turn-guard.sh"
echo "[complete recovery]"
run_check bash "$ROOT/tests/test-complete-recovery.sh"
echo "[project governance]"
run_check bash "$ROOT/tests/test-project-governance.sh"
echo "[release hardening]"
run_check bash "$ROOT/tests/test-release-hardening.sh"
echo "[forbidden permissions]"
if grep -RniE --include='*.sh' --exclude='run-all.sh' 'chmod[[:space:]]+(-R[[:space:]]+)?777|chmod[[:space:]]+(-R[[:space:]]+)?666' "$ROOT"; then failures=$((failures+1)); else echo "forbidden_permissions=NONE"; fi
echo "[destructive operations]"
if grep -RniE --include='*.sh' --exclude='run-all.sh' 'rm[[:space:]]+-rf[[:space:]]+/(|[[:space:]])|mkfs|dd[[:space:]].*of=/dev/' "$ROOT"; then failures=$((failures+1)); else echo "critical_destructive_patterns=NONE"; fi
echo "failures=$failures"
exit "$failures"
