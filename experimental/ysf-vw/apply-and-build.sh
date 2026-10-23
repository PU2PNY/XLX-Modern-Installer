#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:?Usage: apply-and-build.sh /path/to/clean/PP5PK-xlxd}"
[[ "$(git -C "$SRC" rev-parse HEAD)" == e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004 ]] || exit 20
[[ -z "$(git -C "$SRC" status --porcelain)" ]] || exit 21
git -C "$SRC" apply "$ROOT/../tx-turn-guard/patches/xlxd-2.5.3-anti-ping-pong-v1.patch"
git -C "$SRC" apply --check "$ROOT/ysf-vw-native.patch"
git -C "$SRC" apply "$ROOT/ysf-vw-native.patch"
make -C "$SRC/src" clean
make -C "$SRC/src" -j"${JOBS:-2}"
sha256sum "$SRC/src/xlxd"
echo 'LAB build only. No installation, service restart or activation.'
