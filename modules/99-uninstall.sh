#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: uninstall execution is disabled in this development build." >&2; exit 20;; esac
TARGETS=(/etc/systemd/system/xlxd.service /etc/systemd/system/xlxecho.service /var/www/html/xlxd /usr/src/xlxd /usr/src/XLXEcho /usr/src/XLX_Dark_Dashboard /xlxd)
echo "mode=DRY_RUN"
echo "execution=DISABLED"
for target in "${TARGETS[@]}"; do [ -e "$target" ] && echo "WOULD_REVIEW | exists=yes | $target" || echo "WOULD_REVIEW | exists=no | $target"; done
echo "files_removed=0"
echo "services_stopped=0"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
