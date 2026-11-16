#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dashboard/assets/app.js"
MTR="$ROOT/dashboard/assets/mtr.js"
CSS="$ROOT/dashboard/assets/ao-vivo-multi-tx-layout-v1.css"
INDEX="$ROOT/dashboard/index.php"

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

grep -Fq "active.map(txCard).join('')" "$APP" || fail "initial render must include every active TX"
grep -Fq "window.XLXMODERNMTR?.sync(" "$APP" || fail "MTR sync must remain connected"
grep -Fq "active.slice(0,3)" "$APP" && fail "a three-card TX cap remains in app.js"

grep -Fq "const MAX_WIDGETS = 5;" "$MTR" || fail "MTR must support five cards"
grep -Fq "const MAX_CONCURRENT_WIDGETS = 3;" "$MTR" || fail "MTR client concurrency must remain bounded at three"
grep -Fq "const INTERVAL = 10000;" "$MTR" || fail "MTR refresh cadence must remain bounded"
grep -Fq "selected.length < MAX_CONCURRENT_WIDGETS" "$MTR" || fail "MTR scheduler must enforce its concurrency limit"
grep -Fq "nextWidgetIndex" "$MTR" || fail "MTR scheduler must rotate fairly"

grep -Fq "grid-template-columns: repeat(auto-fit, minmax(min(100%, 560px), 1fr)) !important;" "$CSS" || fail "responsive minimum-width grid is missing"
grep -Fq "grid-auto-flow: row !important;" "$CSS" || fail "TX cards must flow by row"
grep -Fq "max-width: 1720px !important;" "$CSS" || fail "desktop grid must remain bounded"
grep -Fq "grid-template-columns: minmax(0, 1fr) !important;" "$CSS" || fail "mobile must use one column"
grep -Fq "assets/ao-vivo-multi-tx-layout-v1.css?v=20261116-1" "$INDEX" || fail "multi-TX stylesheet is not loaded"

echo "[PASS] live multi-TX layout contract (1–5+ cards, responsive rows, MTR <= 3 concurrent)"
