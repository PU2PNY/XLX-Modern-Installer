#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MODE="${1:-check}"
CONFIG="${2:-}"
case "$MODE" in check|dry-run|plan) ;; *) echo "ERROR: Apache changes are owned by dashboard/install/install-dashboard.sh." >&2; exit 20;; esac
[[ -z "$CONFIG" || -f "$CONFIG" ]] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[[ -z "$CONFIG" ]] || source "$CONFIG"

DOMAIN="${DOMAIN:-${XLX_DOMAIN:-xlx.example.org}}"
WEB_ROOT="${XLX_WEB_ROOT:-/var/www/html/xlxd}"
ENABLE_HTTPS="${ENABLE_HTTPS:-yes}"

echo "mode=CHECK"
echo "domain=$DOMAIN"
echo "web_root=$WEB_ROOT"
echo "https=$ENABLE_HTTPS"
if command -v apache2ctl >/dev/null 2>&1; then
  apache2ctl configtest 2>&1 | sed 's/^/apache_configtest=/'
else
  echo 'apache_configtest=apache2ctl_not_installed_yet'
fi
echo "configuration_owner=dashboard/install/install-dashboard.sh"
echo "changes=NONE"
echo "status=CHECK_COMPLETE"
