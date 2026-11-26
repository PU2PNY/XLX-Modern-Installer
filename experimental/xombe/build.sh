#!/usr/bin/env bash
# Reproducible isolated Xombe/AMBED build. Does not install or start services.
set -Eeuo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ $# == 1 ]] || { echo 'Usage: build.sh NEW_OUTPUT_DIRECTORY' >&2; exit 2; }
[[ $EUID != 0 ]] || { echo 'Run unprivileged in Debian 12 lab.' >&2; exit 77; }
out="$1"; mkdir -- "$out"; out="$(cd "$out" && pwd)"
git clone --quiet https://github.com/PP5PK/XLX-SoftAMBE_Installer.git "$out/installer"
git -C "$out/installer" checkout --quiet --detach eff797298744f3b2e1db7bb5b9424db18a03827b
patch="$out/installer/patches/xlxd-ambed-softambe.patch"
[[ "$(git -C "$out/installer" hash-object "$patch")" == dca3f9015edf017458f192b744c5b78889769258 ]]
git clone --quiet https://github.com/PP5PK/xlxd.git "$out/xlxd"
git -C "$out/xlxd" checkout --quiet --detach f10f91bdc5c19ad5b435d96a6595f945403e093a
git -C "$out/xlxd" apply --check --whitespace=nowarn "$patch"
git -C "$out/xlxd" apply --whitespace=nowarn "$patch"
git -C "$out/xlxd" apply --check --whitespace=nowarn "$here/ambed-adapter-v4.patch"
git -C "$out/xlxd" apply --whitespace=nowarn "$here/ambed-adapter-v4.patch"
git clone --quiet https://github.com/x0rro/xombe.git "$out/src"
git -C "$out/src" checkout --quiet --detach 2f0a8e744645b51c1749a39c8a4ee581fef1f20a
git -C "$out/src" apply --check "$here/xombe-gain-v4.patch"
git -C "$out/src" apply "$here/xombe-gain-v4.patch"
python3 - "$out/src" "$out/xlxd/ambed/cstream.cpp" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]); adapter=Path(sys.argv[2])
def replace_once(path, old, new):
    text=path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"Expected one source anchor in {path}: {old!r}")
    path.write_text(text.replace(old,new))
replace_once(src/"include/xombe.h",
    "XOMBE_API void xombe_xc_set_dstar_to_dmr_gain(xombe_xc *x, float gain_log2);",
    "XOMBE_API void xombe_xc_set_dstar_to_dmr_gain(xombe_xc *x, float gain_log2);\nXOMBE_API void xombe_xc_set_dmr_to_dstar_gain(xombe_xc *x, float gain_log2);")
replace_once(src/"src/dstar/xc_state.h",
    "    int out;                  /* enum xombe_xc_out of the last frame */",
    "    int out;                  /* enum xombe_xc_out of the last frame */\n    float output_gain_log2; /* opt-in DMR -> D-STAR gain */")
replace_once(src/"src/dstar/xcode.c",
    "tgt[l] = (1.0f - fr) * a[i] + fr * a[i < L ? i + 1 : L];",
    "tgt[l] = (1.0f - fr) * a[i] + fr * a[i < L ? i + 1 : L] + x->output_gain_log2;")
with (src/"src/dstar/xc.c").open("a") as f:
    f.write("\n/* Optional per-stream DMR -> D-STAR gain. Zero preserves upstream behavior. */\n"
            "void xombe_xc_set_dmr_to_dstar_gain(xombe_xc *x, float gain_log2)\n"
            "{\n"
            "    if (x && x->from == XOMBE_DMR)\n"
            "        x->u.f.output_gain_log2 = gain_log2;\n"
            "}\n")
replace_once(adapter,
    "                    xombe_xc_set_dstar_to_dmr_gain(m_Xombe, -0.5f);",
    "                    xombe_xc_set_dstar_to_dmr_gain(m_Xombe, -0.5f);\n"
    "                else if (m_uiCodecIn == CODEC_AMBE2PLUS && m_uiCodecOut == CODEC_AMBEPLUS)\n"
    "                    xombe_xc_set_dmr_to_dstar_gain(m_Xombe, 1.329912f);")
PY
cmake -S "$out/src" -B "$out/build-release" -DCMAKE_BUILD_TYPE=Release -DXOMBE_WERROR=ON
cmake --build "$out/build-release" -j2
ctest --test-dir "$out/build-release" --output-on-failure
cp -a "$out/xlxd/ambed" "$out/ambed-xombe"
python3 - "$out/ambed-xombe/makefile" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
for old,new in [('CFLAGS=-c -std=c++11 -pthread','CFLAGS=-c -std=c++11 -pthread -I../src/include -I../build-release/include'),('$(FTDI_LIBS) -o $@','$(FTDI_LIBS) ../build-release/libxombe.a -lm -o $@')]:
    assert s.count(old)==1
    s=s.replace(old,new)
p.write_text(s)
PY
make -C "$out/ambed-xombe" clean
make -C "$out/ambed-xombe" -j2 NO_FTDI=1
sha256sum "$out/ambed-xombe/ambed"
echo 'Build and 88 upstream regression tests complete; no service started.'
