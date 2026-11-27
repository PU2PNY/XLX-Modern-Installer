#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:?Usage: apply-and-build.sh /path/to/clean/PP5PK-xlxd [generic|xlx026]}"
PROFILE="${2:-generic}"
case "$PROFILE" in generic|xlx026) ;; *) echo "Unknown XLXD profile: $PROFILE" >&2; exit 2 ;; esac
[[ "$(git -C "$SRC" rev-parse HEAD)" == e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004 ]] || exit 20
[[ -z "$(git -C "$SRC" status --porcelain)" ]] || exit 21
git -C "$SRC" apply "$ROOT/../tx-turn-guard/patches/xlxd-2.5.3-anti-ping-pong-v1.patch"
git -C "$SRC" apply --check "$ROOT/ysf-vw-native.patch"
git -C "$SRC" apply "$ROOT/ysf-vw-native.patch"
if [[ "$PROFILE" == xlx026 ]]; then
  python3 - "$SRC/src/main.h" <<'PYTHON'
from pathlib import Path
import re
import sys

header = Path(sys.argv[1])
text = header.read_text()
settings = {
    "NB_OF_MODULES": "5",
    "DMRMMDVM_KEEPALIVE_TIMEOUT": "180",
    "YSF_KEEPALIVE_TIMEOUT": "90",
    "YSF_DEFAULT_NODE_TX_FREQ": "433125000",
    "YSF_DEFAULT_NODE_RX_FREQ": "433125000",
    "YSF_AUTOLINK_ENABLE": "1",
    "YSF_AUTOLINK_MODULE": "'C'",
}
for key, value in settings.items():
    text, count = re.subn(
        rf"^(#define +{key} +)[^/\r\n]+?( *)(?=//|$)",
        lambda match: match[1] + value + match[2],
        text,
        flags=re.M,
    )
    if count != 1:
        raise SystemExit(f"Unexpected number of definitions for {key}: {count}")
header.write_text(text)
PYTHON
fi
make -C "$SRC/src" clean
make -C "$SRC/src" -j"${JOBS:-2}"
sha256sum "$SRC/src/xlxd"
echo 'LAB build only. No installation, service restart or activation.'
