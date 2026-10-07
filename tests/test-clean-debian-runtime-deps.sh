#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE="$ROOT/modules/72-live-runtime.sh"
OBS="$ROOT/modules/71-observability.sh"

grep -Eq 'apt-get install .*\bfile\b' "$LIVE" || {
  echo 'FAIL | Live runtime must install file before observability on minimal Debian 12' >&2
  exit 1
}
grep -Fq 'timeout file' "$OBS" || {
  echo 'FAIL | observability no longer declares the file utility contract' >&2
  exit 1
}
printf '%s\n' 'CLEAN_DEBIAN_RUNTIME_DEPS=PASS'
