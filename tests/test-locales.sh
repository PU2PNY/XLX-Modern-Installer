#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
set +e
PT="$(printf '1\n0\n' | "$ROOT/install.sh" 2>&1)"; RCPT=$?
EN="$(printf '2\n0\n' | "$ROOT/install.sh" 2>&1)"; RCEN=$?
set -e
grep -F "Bem-vindo" <<<"$PT" >/dev/null
grep -F "Welcome" <<<"$EN" >/dev/null
[ "$RCPT" -eq 0 ] && [ "$RCEN" -eq 0 ]
echo "locales=OK"
