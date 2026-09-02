#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
needle="$(printf '%s%s' 'PP5' 'PK')"
lower="$(printf '%s' "$needle" | tr '[:upper:]' '[:lower:]')"
failures=0

paths=(
  "$ROOT/install.sh"
  "$ROOT/install-control.sh"
  "$ROOT/update.sh"
  "$ROOT/modules"
  "$ROOT/control"
  "$ROOT/dashboard"
  "$ROOT/runtime"
  "$ROOT/tools"
  "$ROOT/scripts"
  "$ROOT/extras"
)

if [[ -d "$ROOT/vendor/pp5pk-installer" ]]; then
  echo '[FAIL] retired installer dependency directory still exists' >&2
  failures=$((failures+1))
fi

while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  echo "[FAIL] active installation/runtime reference found: $hit" >&2
  failures=$((failures+1))
done < <(
  grep -RniI --exclude='test-no-pp5pk-runtime.sh' -- "$lower" "${paths[@]}" 2>/dev/null || true
)

grep -Fq 'https://github.com/LX3JL/xlxd.git' "$ROOT/modules/40-xlxd.sh" || { echo '[FAIL] official XLXD source missing' >&2; failures=$((failures+1)); }
grep -Fq 'https://github.com/narspt/XLXEcho.git' "$ROOT/modules/50-echo.sh" || { echo '[FAIL] independent XLXEcho source missing' >&2; failures=$((failures+1)); }

echo "failures=$failures"
exit "$failures"
