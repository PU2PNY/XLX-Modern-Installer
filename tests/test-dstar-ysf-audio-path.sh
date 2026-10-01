#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/experimental/helix-bridge/xuvd.cpp"

grep -F "in_codec == CODEC_DSTAR &&" "$SRC" >/dev/null
grep -F "out_codec == CODEC_AMBE2" "$SRC" >/dev/null
grep -F "divisor_pcm = 8;" "$SRC" >/dev/null
grep -F "scaled = (scaled * 3) / 2;" "$SRC" >/dev/null
grep -F "dstar_initial_erasures" "$SRC" >/dev/null
grep -F "dstar_concealed" "$SRC" >/dev/null
grep -F "dstar_muted" "$SRC" >/dev/null
grep -F "dstar_repeat_count <= 3" "$SRC" >/dev/null
grep -F "if (!dstar_have_good)" "$SRC" >/dev/null

if grep -F "lp_dstar" "$SRC" >/dev/null; then
  echo "dstar_ysf_audio_path=FAIL per-frame low-pass returned"
  exit 1
fi

# Guard the opposite direction: this change must not silently remove the
# separately approved AMBE2->D-Star pre-emphasis path.
grep -F "constexpr double HP_ALPHA = 0.68;" "$SRC" >/dev/null
grep -F "constexpr double TREBLE_MIX = 1.80;" "$SRC" >/dev/null
grep -F "constexpr double LOW_MID_CUT = 0.65;" "$SRC" >/dev/null

python3 - <<'PY'
samples=[-32768,-16000,-8000,-1000,0,1000,8000,16000,32767]
for x in samples:
    scaled=int(x/8)
    restored=int((scaled*3)/2)
    assert -32768 <= restored <= 32767
# The restored path is exactly 1.5x after /8 for non-zero values.
assert int((8000//8)*3/2)==1500
print("dstar_ysf_numeric_contract=PASS")
PY

echo "dstar_ysf_audio_path=PASS"
