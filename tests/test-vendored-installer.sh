#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source="$ROOT/vendor/pp5pk-installer/installer.sh"
metadata="$ROOT/vendor/pp5pk-installer/UPSTREAM.md"
[[ -s "$source" ]] || { echo "[FAIL] vendored installer missing" >&2; exit 1; }
[[ -s "$metadata" ]] || { echo "[FAIL] upstream pin metadata missing" >&2; exit 1; }
for template in xlx_log.service xlx_log.sh xlx_logrotate.conf apache.tbd.conf uninstaller.sh; do
  [[ -s "$ROOT/vendor/pp5pk-installer/templates/$template" ]] || { echo "[FAIL] vendored template missing: $template" >&2; exit 1; }
done
expected="$(sed -n 's/^readonly EXPECTED_INSTALLER_SHA256="\([^"]*\)"/\1/p' "$ROOT/install.sh")"
reviewed="$(sed -n 's/^readonly REVIEWED_COMMIT="\([^"]*\)"/\1/p' "$ROOT/install.sh")"
actual="$(sha256sum "$source" | awk '{print $1}')"
[[ "$expected" == "$actual" ]] || { echo "[FAIL] vendored installer checksum mismatch" >&2; exit 1; }
[[ "$reviewed" == 'vendor-pinned-PP5PK-20b4893' ]] || { echo "[FAIL] root installer PP5PK review marker changed unexpectedly" >&2; exit 1; }
grep -Fq '20b48934505b1939317bf71b30ddc32b1ced0035' "$metadata" || { echo "[FAIL] full reviewed PP5PK commit is not documented" >&2; exit 1; }
grep -Fq '266217ee910742710b9c5c9f30009c8a0f0fcaf7' "$metadata" || { echo "[FAIL] reviewed upstream installer blob is not documented" >&2; exit 1; }
grep -Fq 'a2710d17d7d51c547c81fce3b5f184a423f20cd361abd0401066f8981acdfaac' "$ROOT/install.sh" || { echo "[FAIL] expected PP5PK installer SHA-256 pin changed" >&2; exit 1; }
bash -n "$source"
bash -n "$ROOT/vendor/pp5pk-installer/templates/uninstaller.sh"
echo "[OK] vendored PP5PK installer, templates, upstream pin and checksum validated"
