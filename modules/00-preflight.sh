#!/usr/bin/env bash
set -Eeuo pipefail
for cmd in bash awk sed grep find stat sha256sum tar systemctl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing_command=$cmd"; exit 1; }
done
[ -r /etc/os-release ] || { echo "os_release=missing"; exit 1; }
source /etc/os-release
case "${ID:-}" in
  debian|ubuntu) echo "operating_system=${ID}" ;;
  *) echo "unsupported_operating_system=${ID:-unknown}"; exit 1 ;;
esac
echo "preflight=OK"
echo "changes=NONE"
