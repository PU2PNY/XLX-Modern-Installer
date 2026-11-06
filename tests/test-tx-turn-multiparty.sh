#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
PATCH="$ROOT/experimental/tx-turn-guard/patches/xlxd-vw-20261023-participants-v2-3s.patch"
CPP="$ROOT/tests/test-tx-turn-multiparty-cpp.cpp"
MODEL="$ROOT/tests/test-tx-turn-multiparty-policy.py"

test -s "$PATCH"
python3 "$MODEL"
grep -F 'XLX_TX_TURN_POLICY' "$PATCH" >/dev/null
grep -F 'strcmp(policy, "participants")' "$PATCH" >/dev/null
grep -F 'XLX_TX_TURN_TRIGGER_MS' "$PATCH" >/dev/null
grep -F 'XLX_TX_TURN_COOLDOWN_MS' "$PATCH" >/dev/null
grep -F 'TXTURN event=violation_detected' "$PATCH" >/dev/null
grep -F 'TXTURN event=blocked' "$PATCH" >/dev/null
grep -F 'STxTurnParticipantsState' "$PATCH" >/dev/null
grep -F 'state.participants.size() >= 128' "$PATCH" >/dev/null
grep -F 'IsMaxDurationReached()' "$CPP" >/dev/null
if grep -Ei 'TXTURN event=.*(callsign=|user=|station=|radioid=|ip=)|api.openai.com|urllib|curl' "$PATCH"; then
  echo 'tx_turn_multi_static=FAIL: identity or remote API in core'; exit 1
fi
echo 'tx_turn_multi_static=PASS'
# Optional real C++ integration test against a built matching XLXD source tree.
# Never starts or installs the XLXD daemon.
if [[ $# -eq 0 ]]; then exit 0; fi
SRC="$1"
BUILD="$SRC/src"
[[ -x "$BUILD/xlxd" ]] || { echo "build XLXD in LAB before C++ test" >&2; exit 2; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
g++ -c -std=c++11 -pthread -iquote "$BUILD" -Dmain=xlxd_original_main "$BUILD/main.cpp" -o "$TMP/main-test.o"
g++ -c -std=c++11 -pthread -iquote "$BUILD" "$CPP" -o "$TMP/txturn-multi.o"
[[ $(find "$BUILD" -maxdepth 1 -name '*.o' ! -name 'main.o' | wc -l) -gt 10 ]] || exit 3
g++ -std=c++11 -pthread "$TMP/txturn-multi.o" "$TMP/main-test.o" $(find "$BUILD" -maxdepth 1 -name '*.o' ! -name 'main.o' | sort) -o "$TMP/txturn-multi"
"$TMP/txturn-multi" | tail -n 2
