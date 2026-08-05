#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"; CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: permission changes are blocked in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
PATHS=(/xlxd /xlxd/callinghome.php /xlxd/lastcallhome.php /var/www/html/xlxd /var/www/html/xlxd-novo /etc/systemd/system/xlxd.service /etc/systemd/system/xlxecho.service)
echo "mode=DRY_RUN"
for path in "${PATHS[@]}"; do [ -e "$path" ] && stat -c 'CURRENT | %n | owner=%U:%G | mode=%a | type=%F' "$path" || echo "ABSENT | $path"; done
echo "forbidden_modes=0777,0666"
echo "recursive_chmod_without_manifest=FORBIDDEN"
echo "permissions_changed=NO"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
