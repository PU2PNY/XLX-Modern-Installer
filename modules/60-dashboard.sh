#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"; CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: dashboard installation is blocked in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
REPOSITORY="${DASHBOARD_REPOSITORY:-https://github.com/PP5PK/XLX_Dark_Dashboard.git}"
WEB_ROOT="${XLX_WEB_ROOT:-${XLX_NEW_DASHBOARD_ROOT:-/var/www/html/xlxd}}"
ENABLED="${ENABLE_DASHBOARD:-yes}"
echo "mode=DRY_RUN"
echo "enabled=$ENABLED"
echo "repository=$REPOSITORY"
echo "web_root=$WEB_ROOT"
[ "$ENABLED" = yes ] || { echo "status=SKIPPED_BY_CONFIGURATION"; echo "changes=NONE"; exit 0; }
echo "php_version=$(php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
echo "repository_clone=NOT_EXECUTED"
echo "web_files_changed=NO"
echo "apache_changed=NO"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
