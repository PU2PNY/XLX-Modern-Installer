#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MODE="${1:-dry-run}"
case "$MODE" in dry-run|plan|check) ;; *) echo "ERROR: uninstall execution is intentionally disabled; review the plan first." >&2; exit 20;; esac

TARGETS=(
  /etc/systemd/system/xlxd.service
  /etc/systemd/system/xlxecho.service
  /etc/systemd/system/update_XLX_db.service
  /etc/systemd/system/update_XLX_db.timer
  /etc/systemd/system/xlx_log.service
  /etc/systemd/system/xlx-callinghome.service
  /etc/systemd/system/xlx-callinghome.timer
  /etc/xlx-modern
  /etc/xlx-modern-control
  /etc/sudoers.d/xlx-modern-control
  /var/www/html/xlxd
  /usr/src/xlxd
  /usr/src/XLXEcho
  /xlxd
)

echo "mode=DRY_RUN"
echo "execution=DISABLED"
for target in "${TARGETS[@]}"; do
  [[ -e "$target" ]] && echo "WOULD_REVIEW | exists=yes | $target" || echo "WOULD_REVIEW | exists=no | $target"
done
echo "files_removed=0"
echo "services_stopped=0"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
