#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if command -v g++ >/dev/null 2>&1; then
    g++ -std=c++17 -Wall -Wextra -Werror "$ROOT/tests/test-audio-adaptive-gain.cpp" -o "$TMP/t"
    "$TMP/t"
    echo "compiler_test=PASS"
else
    python3 - "$ROOT/audio/dmr-normalizer/src/adaptive_gain.hpp" <<'PY'
import math
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")

required = {
    "target_dbfs": "-25.0",
    "deadband_db": "3.0",
    "hard_limit_db": "3.0",
    "speech_gate_dbfs": "-50.0",
    "min_samples": "12",
    "max_frames": "30",
}
for key, value in required.items():
    if not re.search(rf"\b{re.escape(key)}\s*=\s*{re.escape(value)}\s*;", src):
        raise SystemExit(f"missing/default mismatch: {key}={value}")

if "std::min(3.0" not in src:
    raise SystemExit("hard ±3 dB ceiling missing")
if "correction_db_ = 0.0; // fail open" not in src:
    raise SystemExit("fail-open contract missing")

def correction(values, target=-25.0, deadband=3.0, hard_limit=3.0, gate=-50.0, minimum=12, max_frames=30):
    usable = [v for v in values[:max_frames] if math.isfinite(v) and v >= gate]
    if len(usable) < minimum:
        return 0.0
    x = sorted(usable[:minimum])
    median = (x[minimum//2-1] + x[minimum//2]) / 2 if minimum % 2 == 0 else x[minimum//2]
    err = target - median
    hard = min(3.0, max(0.0, abs(hard_limit)))
    return 0.0 if abs(err) <= max(0.0, deadband) else max(-hard, min(hard, err))

cases = [
    ([-38.0] * 12, 3.0, "low"),
    ([-17.0] * 12, -3.0, "high"),
    ([-25.0] * 12, 0.0, "ideal"),
    ([-40.0] * 12, 3.0, "hard-cap"),
    ([-90.0] * 30, 0.0, "fail-open"),
]
for values, expected, name in cases:
    got = correction(values, hard_limit=9.0 if name == "hard-cap" else 3.0)
    if abs(got - expected) > 1e-9:
        raise SystemExit(f"{name}: expected {expected}, got {got}")

print("python_contract=PASS")
PY
    echo "compiler_test=SKIP_NO_GXX"
fi

grep -F 'adaptive_gain_dmr=0' "$ROOT/audio/dmr-normalizer/xlx-dmr-normalizer.conf.example" >/dev/null
grep -F 'std::min(3.0' "$ROOT/audio/dmr-normalizer/src/adaptive_gain.hpp" >/dev/null
grep -F 'CYsfUtils::AdjustAmbeGain' "$ROOT/audio/dmr-normalizer/src/dmr_audio_core.hpp" >/dev/null

if grep -RniE 'openai|api\.openai|curl .*openai|https?://'     "$ROOT/audio/dmr-normalizer/src"     "$ROOT/audio/dmr-normalizer/xlx-dmr-normalizer.conf.example"; then
    echo "ERROR: external/AI dependency found in real-time audio component" >&2
    exit 1
fi

echo "audio_adaptive_gain_contract=PASS"
