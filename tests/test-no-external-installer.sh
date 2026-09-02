#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Build the forbidden historical reference at runtime so the literal name does
# not exist anywhere in this repository, including this guard itself.
forbidden="$(printf '%s%s' 'PP5' 'PK')"
failures=0

while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  echo "[FAIL] forbidden external-installer reference found: $hit" >&2
  failures=$((failures+1))
done < <(
  grep -RniI --exclude-dir='.git' --exclude='test-no-external-installer.sh' -- "$forbidden" "$ROOT" 2>/dev/null || true
)

grep -Fq 'https://github.com/LX3JL/xlxd.git' "$ROOT/modules/40-xlxd.sh" || { echo '[FAIL] official XLXD source missing' >&2; failures=$((failures+1)); }
grep -Fq 'https://github.com/narspt/XLXEcho.git' "$ROOT/modules/50-echo.sh" || { echo '[FAIL] independent optional Echo source missing' >&2; failures=$((failures+1)); }

# The Modern Dashboard must come from this repository, not a remote dashboard.
if grep -RniE --include='*.sh' --include='*.py' --include='*.php' 'git[[:space:]]+clone.*dashboard|DASHBOARD_REPOSITORY=' "$ROOT/install.sh" "$ROOT/modules" "$ROOT/dashboard/install" 2>/dev/null; then
  echo '[FAIL] external dashboard download logic detected' >&2
  failures=$((failures+1))
fi

echo "failures=$failures"
exit "$failures"
