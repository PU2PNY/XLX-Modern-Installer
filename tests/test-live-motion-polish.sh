#!/usr/bin/env bash
# UI-018 / TEST-060: safety contract for the additive motion CSS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS="$ROOT/dashboard/assets/ao-vivo-motion-polish-v1.css"
INDEX="$ROOT/dashboard/index.php"
test -s "$CSS"
python3 - "$CSS" "$INDEX" <<'PY'
import pathlib,re,sys
css=pathlib.Path(sys.argv[1]).read_text()
index=pathlib.Path(sys.argv[2]).read_text()
assert 'ao-vivo-motion-polish-v1.css' in index
assert index.index('ao-vivo-motion-polish-v1.css')>index.index('ao-vivo-multi-tx-layout-v1.css')
assert '@keyframes xlx026QrzNeonPulseRed' in css
for forbidden in ['@keyframes xlx026TotYellowPulse','@keyframes xlx026TotRedPulse','@keyframes xlx026V31RadarRotate','@keyframes xlx026-mtr-dot']:
    assert forbidden not in css, forbidden
for token in ['tx-tot-warning-yellow','tx-tot-warning-red','tx-tot-warning','tx-tot-expired']:
    assert ':not(.'+token+')' in css
for forbidden in ['grid-template','grid-auto','position:','display:','width:','height:','transform:','setInterval','fetch(','XMLHttpRequest']:
    assert forbidden not in css, 'Forbidden layout/network change: '+forbidden
assert 'body[data-page="ao-vivo"]' in css
assert 'prefers-reduced-motion' in css
assert 'animation: none !important' in css
assert '1.35s' in css
print('TEST-060 PASS: opt-in visual layer, TOT exclusions, no layout or network changes')
PY
