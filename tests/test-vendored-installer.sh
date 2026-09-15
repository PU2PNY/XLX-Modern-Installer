#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source="$ROOT/vendor/pp5pk-installer/installer.sh"
[[ -s "$source" ]] || { echo "[FAIL] vendored installer missing" >&2; exit 1; }
for template in xlx_log.service xlx_log.sh xlx_logrotate.conf apache.tbd.conf uninstaller.sh; do
  [[ -s "$ROOT/vendor/pp5pk-installer/templates/$template" ]] || { echo "[FAIL] vendored template missing: $template" >&2; exit 1; }
done
expected="$(sed -n 's/^readonly EXPECTED_INSTALLER_SHA256="\([^"]*\)"/\1/p' "$ROOT/install.sh")"
actual="$(sha256sum "$source" | awk '{print $1}')"
[[ "$expected" == "$actual" ]] || { echo "[FAIL] vendored installer checksum mismatch" >&2; exit 1; }
bash -n "$source"
grep -Fq 'if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then' "$source" || { echo "[FAIL] vendored installer still requires an interactive TERM" >&2; exit 1; }
if grep -qx 'clear' "$source"; then echo "[FAIL] unguarded clear remains in vendored installer" >&2; exit 1; fi
bash -n "$ROOT/vendor/pp5pk-installer/templates/uninstaller.sh"
echo "[OK] vendored installer, templates and checksum validated"
