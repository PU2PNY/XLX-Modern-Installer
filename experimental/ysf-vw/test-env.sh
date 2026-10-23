#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" == 0 ]] || { echo 'Run only as root in disposable LAB'; exit 77; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${1:?Usage: test-env.sh /path/to/patched/xlxd}/src"
TMP="$(mktemp -d)"
KEY=/etc/xlx-modern/ysf-vw.conf
[[ ! -L "$KEY" ]] || exit 77
mkdir -p /etc/xlx-modern
HAD_KEY=0
if [[ -e "$KEY" ]]; then cp -p "$KEY" "$TMP/key"; HAD_KEY=1; fi
cleanup(){ if [[ "$HAD_KEY" == 1 ]]; then cp -p "$TMP/key" "$KEY"; else rm -f "$KEY"; fi; rm -rf "$TMP"; }
trap cleanup EXIT
g++ -c -std=c++11 -pthread -iquote "$BUILD" -Dmain=xlxd_original_main "$BUILD/main.cpp" -o "$TMP/main.o"
g++ -c -std=c++11 -pthread -iquote "$BUILD" "$ROOT/test-env.cpp" -o "$TMP/test.o"
objects=()
for obj in "$BUILD"/*.o; do [[ "$(basename "$obj")" == main.o ]] || objects+=("$obj"); done
g++ -std=c++11 -pthread "$TMP/test.o" "$TMP/main.o" "${objects[@]}" -o "$TMP/test"
# No packets can reach existing services or external stations.
unshare -n -- bash -c 'ip link set lo up; exec timeout 30 "$1"' _ "$TMP/test"
