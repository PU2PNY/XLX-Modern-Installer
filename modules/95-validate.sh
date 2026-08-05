#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-read-only}"
case "$MODE" in read-only|dry-run|plan) ;; *) echo "ERROR: unsupported validation mode." >&2; exit 1;; esac
failures=0; warnings=0
echo "mode=READ_ONLY"
for service in ssh apache2 xlxd xlxecho; do state="$(systemctl is-active "$service" 2>/dev/null || true)"; echo "$service=$state"; [ "$state" = active ] || failures=$((failures+1)); done
apache2ctl configtest
for path in /xlxd/xlxd /xlxd/xlxecho /var/log/xlxd.xml /var/log/xlx.log /var/www/html/xlxd /var/www/html/xlxd-novo; do [ -e "$path" ] && stat -c 'EXISTS | %n | owner=%U:%G | mode=%a | size=%s' "$path" || { echo "MISSING | $path"; warnings=$((warnings+1)); }; done
echo "failures=$failures"
echo "warnings=$warnings"
echo "changes=NONE"
[ "$failures" -eq 0 ]
