#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for file in "$ROOT/modules/30-packages.sh" "$ROOT/modules/40-xlxd.sh" "$ROOT/modules/50-echo.sh"; do
  bash -n "$file"
done

grep -Fq 'https://github.com/LX3JL/xlxd.git' "$ROOT/modules/40-xlxd.sh"
grep -Fq 'bf5d0148dbdf2534af129ca3cc034c5051dcfc8d' "$ROOT/modules/40-xlxd.sh"
grep -Fq 'https://github.com/narspt/XLXEcho.git' "$ROOT/modules/50-echo.sh"
grep -Fq '8a54cce758cc81ce593822142a32429b07740193' "$ROOT/modules/50-echo.sh"
grep -Fq '//#define RUN_AS_DAEMON' "$ROOT/modules/40-xlxd.sh"
grep -Fq 'runtime/xlxd.service.in' "$ROOT/modules/40-xlxd.sh"
grep -Fq 'runtime/xlxecho.service' "$ROOT/modules/50-echo.sh"
grep -Fq 'systemctl enable --now xlxd.service' "$ROOT/modules/40-xlxd.sh"
grep -Fq 'systemctl enable --now xlxecho.service' "$ROOT/modules/50-echo.sh"
grep -Fq 'ECHO 127.0.0.1' "$ROOT/modules/50-echo.sh"

bash "$ROOT/tests/test-no-pp5pk-runtime.sh"
echo '[OK] independent XLXD/Echo installation sources and guards validated'
