#!/usr/bin/env bash
# Rebuild the experimental AMBED only. Never install or start a service.
set -Eeuo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ $# == 1 ]] || { echo 'Usage: build.sh NEW_OUTPUT_DIRECTORY' >&2; exit 2; }
[[ $EUID != 0 ]] || { echo 'Run as an unprivileged user in a lab.' >&2; exit 77; }
out="$1"
mkdir -- "$out"
out="$(cd "$out" && pwd)"
git clone --quiet https://github.com/PP5PK/XLX-SoftAMBE_Installer.git "$out/installer"
git -C "$out/installer" checkout --quiet --detach eff797298744f3b2e1db7bb5b9424db18a03827b
patch="$out/installer/patches/xlxd-ambed-softambe.patch"
[[ "$(git -C "$out/installer" hash-object "$patch")" == dca3f9015edf017458f192b744c5b78889769258 ]]
git clone --quiet https://github.com/PP5PK/xlxd.git "$out/xlxd"
git -C "$out/xlxd" checkout --quiet --detach f10f91bdc5c19ad5b435d96a6595f945403e093a
git -C "$out/xlxd" apply --check --whitespace=nowarn "$patch"
git -C "$out/xlxd" apply --whitespace=nowarn "$patch"
git -C "$out/xlxd" apply --check --whitespace=nowarn "$here/ambed-adapter.patch"
git -C "$out/xlxd" apply --whitespace=nowarn "$here/ambed-adapter.patch"
git clone --quiet https://github.com/x0rro/xombe.git "$out/src"
git -C "$out/src" checkout --quiet --detach 2f0a8e744645b51c1749a39c8a4ee581fef1f20a
git -C "$out/src" apply --check "$here/xombe-gain-v3.patch"
git -C "$out/src" apply "$here/xombe-gain-v3.patch"
cmake -S "$out/src" -B "$out/build-release" -DCMAKE_BUILD_TYPE=Release -DXOMBE_WERROR=ON
cmake --build "$out/build-release" -j2
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
echo 'Build only; no service started. Run UDP and RF validation separately.'
