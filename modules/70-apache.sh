#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"; CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: Apache and SSL changes are blocked in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
DOMAIN="${XLX_DOMAIN:-xlx.example.org}"
WEB_ROOT="${XLX_WEB_ROOT:-${XLX_NEW_DASHBOARD_ROOT:-/var/www/html/xlxd}}"
ENABLE_HTTPS="${ENABLE_HTTPS:-yes}"
echo "mode=DRY_RUN"
echo "domain=$DOMAIN"
echo "web_root=$WEB_ROOT"
echo "https=$ENABLE_HTTPS"
apache2ctl configtest 2>&1 | sed 's/^/apache_configtest=/'
echo "vhost_written=NO"
echo "modules_changed=NO"
echo "certificate_requested=NO"
echo "apache_reloaded=NO"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
