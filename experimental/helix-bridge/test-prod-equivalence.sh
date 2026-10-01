#!/usr/bin/env bash
set -Eeuo pipefail

# Reproduce the legacy-path equivalence gate without vendoring OP25/mbelib.
#
# Required:
#   XUVD_BASELINE=/path/to/known-good/xuvd
#   OP25_LIB=/path/to/op25/gr-op25_repeater/lib
#
# Optional:
#   HELIX_DAEMON=/path/to/helix-daemon   # also proves shadow is bit-identical
#   BRIDGE_OUTPUT=/path/to/xuvd           # export the exact tested bridge binary
#
# The host must not already have UDP 127.0.0.1:10100 in use.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIDGE="$ROOT/experimental/helix-bridge"
BASELINE="${XUVD_BASELINE:-}"
OP25="${OP25_LIB:-}"
HELIX="${HELIX_DAEMON:-}"
BRIDGE_OUTPUT="${BRIDGE_OUTPUT:-}"

fail() { printf 'FAIL | %s\n' "$*" >&2; exit 1; }

[[ -n "$BASELINE" && -x "$BASELINE" ]] || fail "XUVD_BASELINE must point to an executable"
[[ -n "$OP25" && -d "$OP25" ]] || fail "OP25_LIB must point to gr-op25_repeater/lib"
[[ -f "$OP25/ambe_encoder.cc" && -f "$OP25/ambe.c" && -d "$OP25/imbe_vocoder" ]] ||
  fail "OP25_LIB is incomplete"
command -v g++ >/dev/null || fail "g++ is required"
command -v gcc >/dev/null || fail "gcc is required"
command -v ss >/dev/null || fail "ss is required"

if ss -lun 2>/dev/null | grep -qE '127\.0\.0\.1:10100\b'; then
  fail "127.0.0.1:10100 is already in use; run only in an isolated lab"
fi

WORK="$(mktemp -d)"
PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

gcc -O2 -I"$OP25" -c "$OP25/ambe.c" -o "$WORK/ambe.o"
mapfile -t IMBE_SRC < <(find "$OP25/imbe_vocoder" -maxdepth 1 -type f -name '*.cc' | sort)
[[ ${#IMBE_SRC[@]} -gt 0 ]] || fail "no IMBE sources found"

COMMON=(
  "$OP25/ambe_encoder.cc"
  "$OP25/p25p2_vf.cc"
  "$OP25/rs.cc"
  "$OP25/mbelib.c"
  "$WORK/ambe.o"
  "${IMBE_SRC[@]}"
)

g++ -std=c++17 -O2 -Wall -Wextra \
  -I"$BRIDGE" -I"$OP25" -I"$OP25/imbe_vocoder" \
  "$BRIDGE/xuvd.cpp" "$BRIDGE/adapter.cpp" \
  "$OP25/software_imbe_decoder.cc" "$OP25/imbe_decoder.cc" \
  "${COMMON[@]}" -lm -o "$WORK/xuvd-bridge"

g++ -std=c++17 -O2 \
  -I"$BRIDGE" -I"$OP25" -I"$OP25/imbe_vocoder" \
  "$BRIDGE/equivalence_corpus.cpp" "$BRIDGE/adapter.cpp" \
  "${COMMON[@]}" -lm -o "$WORK/corpus-client"

wait_port() {
  for _ in $(seq 1 100); do
    ss -lun 2>/dev/null | grep -qE '127\.0\.0\.1:10100\b' && return 0
    sleep 0.03
  done
  return 1
}

start_xuvd() {
  local mode="$1" bin="$2" log="$3"
  if [[ "$mode" == "baseline" ]]; then
    "$bin" >"$log" 2>&1 &
  else
    XLX_HELIX_MODE="$mode" "$bin" >"$log" 2>&1 &
  fi
  XUVD_PID=$!
  PIDS+=("$XUVD_PID")
  wait_port || fail "xuvd did not bind control port"
}

stop_xuvd() {
  kill "$XUVD_PID" 2>/dev/null || true
  wait "$XUVD_PID" 2>/dev/null || true
  PIDS=("${PIDS[@]/$XUVD_PID}")
  XUVD_PID=""
}

run_corpus() {
  local tag="$1"
  for spec in "2 1 A" "2 1 C" "1 2 A" "1 2 C"; do
    read -r input output module <<<"$spec"
    "$WORK/corpus-client" "$input" "$output" "$module" >"$WORK/$tag-$input-$output-$module.bin"
  done
}

start_xuvd baseline "$BASELINE" "$WORK/baseline.log"
run_corpus baseline
stop_xuvd

start_xuvd off "$WORK/xuvd-bridge" "$WORK/off.log"
run_corpus off
stop_xuvd

for spec in "2-1-A" "2-1-C" "1-2-A" "1-2-C"; do
  cmp -s "$WORK/baseline-$spec.bin" "$WORK/off-$spec.bin" ||
    fail "legacy output differs for $spec"
  printf 'BIT_IDENTICAL off %s %s\n' "$spec" "$(sha256sum "$WORK/off-$spec.bin" | awk '{print $1}')"
done

if [[ -n "$HELIX" ]]; then
  [[ -x "$HELIX" ]] || fail "HELIX_DAEMON is not executable"
  mkdir -p "$WORK/run"
  SOCKET="$WORK/run/observe.sock"
  "$HELIX" --pcm-observe "$SOCKET" >"$WORK/helix.log" 2>&1 &
  HELIX_PID=$!
  PIDS+=("$HELIX_PID")
  for _ in $(seq 1 100); do [[ -S "$SOCKET" ]] && break; sleep 0.02; done
  [[ -S "$SOCKET" ]] || fail "Helix observer socket did not appear"

  XLX_HELIX_OBSERVE_SOCKET="$SOCKET" XLX_HELIX_MODE=shadow     "$WORK/xuvd-bridge" >"$WORK/shadow.log" 2>&1 &
  XUVD_PID=$!
  PIDS+=("$XUVD_PID")
  wait_port || fail "shadow xuvd did not bind control port"
  run_corpus shadow
  stop_xuvd

  for spec in "2-1-A" "2-1-C" "1-2-A" "1-2-C"; do
    cmp -s "$WORK/baseline-$spec.bin" "$WORK/shadow-$spec.bin" ||
      fail "shadow output differs for $spec"
    printf 'BIT_IDENTICAL shadow %s %s\n' "$spec" "$(sha256sum "$WORK/shadow-$spec.bin" | awk '{print $1}')"
  done
fi

BASELINE_SHA="$(sha256sum "$BASELINE" | awk '{print $1}')"
BRIDGE_SHA="$(sha256sum "$WORK/xuvd-bridge" | awk '{print $1}')"
printf 'baseline_sha=%s\n' "$BASELINE_SHA"
printf 'bridge_sha=%s\n' "$BRIDGE_SHA"

if [[ -n "$BRIDGE_OUTPUT" ]]; then
  mkdir -p "$(dirname "$BRIDGE_OUTPUT")"
  install -m 0755 "$WORK/xuvd-bridge" "$BRIDGE_OUTPUT"
  EXPORTED_SHA="$(sha256sum "$BRIDGE_OUTPUT" | awk '{print $1}')"
  [[ "$EXPORTED_SHA" == "$BRIDGE_SHA" ]] || fail "exported bridge hash mismatch"
  printf 'bridge_output=%s\n' "$BRIDGE_OUTPUT"
fi

printf 'PROD_EQUIVALENCE_CORPUS=PASS\n'
