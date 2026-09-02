#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"
CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: only dry-run mode is enabled in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
WEB_ROOT="${XLX_WEB_ROOT:-${XLX_NEW_DASHBOARD_ROOT:-/var/www/html/xlxd}}"
TARGETS=("${XLX_INSTALL_DIR:-/xlxd}" "$WEB_ROOT" "/etc/apache2" "/etc/systemd/system" "/etc/nftables.conf")
echo "mode=DRY_RUN"
echo "backup_root=/root/xlx-modern-installer-backups/<timestamp>"
echo "manifest=ENABLED"
echo "hashes=ENABLED"
echo "rollback_script=PLANNED"
for target in "${TARGETS[@]}"; do
  if [ -e "$target" ]; then size="$(du -sh "$target" 2>/dev/null | awk '{print $1}')"; echo "WOULD_BACKUP | exists=yes | size=${size:-unknown} | $target"; else echo "WOULD_BACKUP | exists=no | $target"; fi
done
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
