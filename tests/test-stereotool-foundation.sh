#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/experimental/stereotool/artifact_validator.py"
UNIT="$ROOT/experimental/stereotool/systemd/xlx-stereotoold.service.example"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for cmd in python3 gcc readelf getconf; do
  command -v "$cmd" >/dev/null || { echo "SKIP | missing $cmd"; exit 77; }
done

cat >"$TMP/good.c" <<'EOF'
const char *stereoTool_GetSoftwareVersion(void) { return "mock-0"; }
int stereoTool_GetApiVersion(void) { return 0; }
EOF
gcc -shared -fPIC -Wl,-soname,libStereoTool_mock.so -o "$TMP/libStereoTool_mock.so" "$TMP/good.c"

python3 "$VALIDATOR" "$TMP/libStereoTool_mock.so" >"$TMP/direct.json"
grep -F '"status": "READY_FOR_SANDBOX"' "$TMP/direct.json" >/dev/null
grep -F '"artifact_kind": "shared_library"' "$TMP/direct.json" >/dev/null

cat >"$TMP/bad.c" <<'EOF'
int not_stereotool(void) { return 1; }
EOF
gcc -shared -fPIC -o "$TMP/libbad.so" "$TMP/bad.c"
if python3 "$VALIDATOR" "$TMP/libbad.so" >"$TMP/bad.out" 2>"$TMP/bad.err"; then
  echo "FAIL | library missing identity symbols was accepted"
  exit 1
fi
grep -F 'missing required identity symbol' "$TMP/bad.err" >/dev/null

python3 - "$TMP" <<'PY'
import stat
import sys
import zipfile
from pathlib import Path
root = Path(sys.argv[1])
with zipfile.ZipFile(root / "good.zip", "w", compression=zipfile.ZIP_DEFLATED) as z:
    z.write(root / "libStereoTool_mock.so", arcname="plugin/libStereoTool_mock.so")
with zipfile.ZipFile(root / "traversal.zip", "w") as z:
    z.writestr("../escape.so", b"not-elf")
with zipfile.ZipFile(root / "symlink.zip", "w") as z:
    info = zipfile.ZipInfo("plugin/libStereoTool_link.so")
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    z.writestr(info, "../../outside")
PY

python3 "$VALIDATOR" "$TMP/good.zip" >"$TMP/zip.json"
grep -F '"status": "READY_FOR_SANDBOX"' "$TMP/zip.json" >/dev/null
grep -F '"artifact_kind": "zip"' "$TMP/zip.json" >/dev/null

if python3 "$VALIDATOR" "$TMP/traversal.zip" >"$TMP/trav.out" 2>"$TMP/trav.err"; then
  echo "FAIL | ZIP traversal was accepted"
  exit 1
fi
grep -F 'unsafe ZIP path' "$TMP/trav.err" >/dev/null

if python3 "$VALIDATOR" "$TMP/symlink.zip" >"$TMP/link.out" 2>"$TMP/link.err"; then
  echo "FAIL | ZIP symlink was accepted"
  exit 1
fi
grep -F 'ZIP symlink is not allowed' "$TMP/link.err" >/dev/null

# Static validator must remain non-executing: reject actual loader call patterns,
# not documentation that merely mentions dlopen.
if grep -En 'dlopen[[:space:]]*\(|ctypes\.(CDLL|PyDLL)[[:space:]]*\(' "$VALIDATOR"; then
  echo "FAIL | validator gained a runtime library load path"
  exit 1
fi

# Worker reference unit must stay local-only and hardened.
grep -Fx 'RestrictAddressFamilies=AF_UNIX' "$UNIT" >/dev/null
if grep -E '^RestrictAddressFamilies=.*AF_INET' "$UNIT" >/dev/null; then
  echo "FAIL | worker reference unit permits Internet address families"
  exit 1
fi
grep -Fx 'NoNewPrivileges=yes' "$UNIT" >/dev/null
grep -Fx 'ProtectSystem=strict' "$UNIT" >/dev/null

# Public repo must never contain a vendor binary in this foundation directory.
if find "$ROOT/experimental/stereotool" -type f \( -name 'libStereoTool*.so' -o -name 'stereo_tool_cmd*' \) -print -quit | grep -q .; then
  echo "FAIL | proprietary Stereo Tool artifact present in repository"
  exit 1
fi

echo "PASS | stereotool static artifact validation and hostile ZIP gates"
