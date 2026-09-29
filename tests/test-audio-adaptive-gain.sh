#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
g++ -std=c++17 -Wall -Wextra -Werror "$ROOT/tests/test-audio-adaptive-gain.cpp" -o "$TMP/t"
"$TMP/t"
grep -F 'adaptive_gain_dmr=0' "$ROOT/audio/dmr-normalizer/xlx-dmr-normalizer.conf.example" >/dev/null
grep -F 'std::min(3.0' "$ROOT/audio/dmr-normalizer/src/adaptive_gain.hpp" >/dev/null
grep -F 'CYsfUtils::AdjustAmbeGain' "$ROOT/audio/dmr-normalizer/src/dmr_audio_core.hpp" >/dev/null
if grep -RniE 'openai|api\.openai|curl .*openai|https?://' "$ROOT/audio/dmr-normalizer/src" "$ROOT/audio/dmr-normalizer/xlx-dmr-normalizer.conf.example"; then
 echo "ERROR: external/AI dependency found in real-time audio component" >&2; exit 1
fi
echo "audio_adaptive_gain_contract=PASS"
