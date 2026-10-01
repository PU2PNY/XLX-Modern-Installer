#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIDGE="$ROOT/experimental/helix-bridge"
: "${OP25_LIB:?external reviewed OP25 lib directory required}"
: "${HELIX_DAEMON:?Helix daemon executable required}"
: "${XUVD_BASELINE:?known-good xuvd executable required}"
: "${LAB_OUTPUT:?new lab output directory required}"
[[ ! -e "$LAB_OUTPUT" ]] || { echo 'FAIL | LAB_OUTPUT already exists'; exit 1; }
mkdir -p "$LAB_OUTPUT"
export BRIDGE_OUTPUT="$LAB_OUTPUT/xuvd"
bash "$BRIDGE/test-prod-equivalence.sh" > "$LAB_OUTPUT/equivalence.log" 2>&1
OP25="$OP25_LIB"
gcc -O2 -I"$OP25" -c "$OP25/ambe.c" -o "$LAB_OUTPUT/ambe.o"
mapfile -t IMBE_SRC < <(find "$OP25/imbe_vocoder" -maxdepth 1 -type f -name '*.cc' | sort)
g++ -std=c++17 -O2 -I"$BRIDGE" -I"$OP25" -I"$OP25/imbe_vocoder" \
    "$BRIDGE/e2e_client.cpp" "$BRIDGE/adapter.cpp" "$OP25/ambe_encoder.cc" \
    "$OP25/p25p2_vf.cc" "$OP25/rs.cc" "$OP25/mbelib.c" \
    "$LAB_OUTPUT/ambe.o" "${IMBE_SRC[@]}" -lm -o "$LAB_OUTPUT/e2e-client"
timeout 90 python3 "$BRIDGE/e2e_lab.py" --xuvd "$BRIDGE_OUTPUT" \
    --helix "$HELIX_DAEMON" --client "$LAB_OUTPUT/e2e-client" --output "$LAB_OUTPUT/runs"
