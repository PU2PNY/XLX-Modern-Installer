#!/usr/bin/env bash
# Build preserved recovery references without changing any installed service.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-}"
[[ -n "$OUT" && ! -e "$OUT" ]] || { echo 'usage: build-audio-recovery.sh NEW_OUTPUT_DIRECTORY' >&2; exit 2; }
for command in git gcc g++; do command -v "$command" >/dev/null || { echo "Missing dependency: $command" >&2; exit 2; }; done
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
git init -q "$OUT/op25"
git -C "$OUT/op25" remote add origin https://github.com/boatbod/op25.git
git -C "$OUT/op25" fetch --depth 1 origin 28f2c40645deca3f8c2d529d27d0df2555ed287a
git -C "$OUT/op25" checkout --detach FETCH_HEAD
OP25="$OUT/op25/op25/gr-op25_repeater/lib"
[[ -f "$OP25/ambe_encoder.cc" ]] || { echo 'Pinned OP25 layout unavailable' >&2; exit 1; }
gcc -O2 -I"$OP25" -c "$OP25/ambe.c" -o "$OUT/ambe.o"
mapfile -t IMBE_SRC < <(find "$OP25/imbe_vocoder" -maxdepth 1 -type f -name '*.cc' | sort)
g++ -std=c++17 -O2 -Wall -Wextra \
  -I"$ROOT/runtime/audio-recovery" -I"$OP25" -I"$OP25/imbe_vocoder" \
  "$ROOT/runtime/audio-recovery/xuvd.cpp" "$ROOT/runtime/audio-recovery/adapter.cpp" \
  "$OP25/software_imbe_decoder.cc" "$OP25/imbe_decoder.cc" \
  "$OP25/ambe_encoder.cc" "$OP25/p25p2_vf.cc" "$OP25/rs.cc" "$OP25/mbelib.c" \
  "$OUT/ambe.o" "${IMBE_SRC[@]}" -lm -o "$OUT/xuvd"
sha256sum "$OUT/xuvd" > "$OUT/xuvd.sha256"
bash "$ROOT/runtime/prepare-xlxd-source.sh" "$OUT/xlxd"
XLXD="$OUT/xlxd/src"
# Preserve the observed file while making its include independent of /usr/src.
sed 's|"/usr/src/xlxd/src/cysffich.h"|"cysffich.h"|' \
  "$ROOT/runtime/audio-vu/xlx-vu-tap.cpp" > "$OUT/xlx-vu-tap.cpp"
g++ -std=c++17 -O2 -ffunction-sections -fdata-sections -Wl,--gc-sections \
  -I"$ROOT/runtime/audio-recovery" -I"$OP25" -I"$OP25/imbe_vocoder" -I"$XLXD" \
  "$OUT/xlx-vu-tap.cpp" "$ROOT/runtime/audio-recovery/adapter.cpp" \
  "$XLXD/cysffich.cpp" "$XLXD/cysfutils.cpp" "$XLXD/ccrc.cpp" \
  "$XLXD/cgolay24128.cpp" "$XLXD/cysfconvolution.cpp" \
  "$OP25/software_imbe_decoder.cc" "$OP25/imbe_decoder.cc" \
  "$OP25/ambe_encoder.cc" "$OP25/p25p2_vf.cc" "$OP25/rs.cc" "$OP25/mbelib.c" \
  "$OUT/ambe.o" "${IMBE_SRC[@]}" -lm -o "$OUT/xlx-vu-tap"
sha256sum "$OUT/xlx-vu-tap" > "$OUT/xlx-vu-tap.sha256"
printf 'AUDIO_REFERENCE_BUILD=PASS output=%s\n' "$OUT/xuvd"
printf 'No service installed or restarted. Helix process remains prohibited for this reference.\n'
