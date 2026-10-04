#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${1:?usage: prepare-xlxd-source.sh NEW_CHECKOUT}"
PIN=e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004
[[ ! -e "$SOURCE" ]] || { echo 'ERROR: XLXD source destination already exists.' >&2; exit 20; }
git clone --no-checkout https://github.com/PP5PK/xlxd.git "$SOURCE"
git -C "$SOURCE" checkout --detach "$PIN"
[[ "$(git -C "$SOURCE" rev-parse HEAD)" == "$PIN" ]]
PATCH="$ROOT/experimental/tx-turn-guard/patches/xlxd-2.5.3-anti-ping-pong-v1.patch"
git -C "$SOURCE" apply --check "$PATCH"
git -C "$SOURCE" apply "$PATCH"
printf 'XLXD_SOURCE_PIN=%s\nTOT_SECONDS=180\nTX_TURN_DEFAULT=OFF\n' "$PIN"
