#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for f in "$ROOT/install.sh" "$ROOT/update.sh" "$ROOT/backup.sh" "$ROOT/uninstall.sh"; do
    bash -n "$f"
done

while IFS= read -r -d '' f; do
    php -l "$f" >/dev/null
done < <(find "$ROOT/web" "$ROOT/scripts" -type f -name '*.php' -print0)

python3 - "$ROOT/gateway/xlx_aprs_dprs.py" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
compile(p.read_text(encoding="utf-8"), str(p), "exec")
PY

python3 "$ROOT/gateway/xlx_aprs_dprs.py" \
    --config "$ROOT/config/config.example.json" \
    --check-config >/dev/null

if command -v node >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
        node --check "$f" >/dev/null
    done < <(find "$ROOT/web/assets" -type f -name '*.js' -print0)
fi

if grep -RniE \
    --exclude-dir='.git' \
    --exclude-dir='.github' \
    --exclude='validate-source.sh' \
    --binary-files=without-match \
    -- \
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|github_pat_|ghp_[A-Za-z0-9]{20,}' \
    "$ROOT"
then
    echo "[ERRO] Padrao sensivel detectado." >&2
    exit 1
fi

echo "[OK] Fonte validada."
