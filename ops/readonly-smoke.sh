#!/usr/bin/env bash
# XLX026-MAINT-JOB-V1
set -Eeuo pipefail
export LANG=C
umask 077

echo "XLX026 READ-ONLY SMOKE TEST"
echo "time=$(date --iso-8601=seconds)"
echo "hostname=$(hostname -f 2>/dev/null || hostname)"
echo "kernel=$(uname -r)"
echo "uptime=$(uptime -p 2>/dev/null || true)"
echo "xlxd_process=$(pgrep -x xlxd >/dev/null 2>&1 && echo active || echo not_detected)"
if [[ -x /xlxd/xlxd ]]; then
  echo "xlxd_sha256=$(sha256sum /xlxd/xlxd | awk '{print $1}')"
fi
if [[ -f /var/log/xlxd.xml ]]; then
  echo "xml_mtime=$(stat -c %y /var/log/xlxd.xml)"
  echo "xml_sha256=$(sha256sum /var/log/xlxd.xml | awk '{print $1}')"
  grep -m1 '<Version>' /var/log/xlxd.xml || true
fi
printf 'listeners_sample='; ss -lntuH 2>/dev/null | wc -l || true
printf 'disk_root='; df -P / | awk 'NR==2 {print $5}'
printf 'memory='; free -m | awk '/^Mem:/ {print $3"MB_used/"$2"MB_total"}'
echo "READ_ONLY_SMOKE_COMPLETE"
