#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MODE="${1:-read-only}"
case "$MODE" in read-only|check|dry-run|plan) ;; *) echo "ERROR: unsupported validation mode." >&2; exit 1;; esac

failures=0
warnings=0
echo "mode=READ_ONLY"

for service in ssh apache2 xlxd; do
  state="$(systemctl is-active "$service" 2>/dev/null || true)"
  echo "$service=$state"
  [[ "$state" == active ]] || failures=$((failures+1))
done

if systemctl list-unit-files xlxecho.service --no-legend 2>/dev/null | grep -q '^xlxecho\.service'; then
  echo_state="$(systemctl is-active xlxecho.service 2>/dev/null || true)"
  echo "xlxecho=$echo_state"
  [[ "$echo_state" == active ]] || warnings=$((warnings+1))
else
  echo 'xlxecho=not-installed-optional'
fi

if command -v apache2ctl >/dev/null 2>&1; then
  apache2ctl configtest || failures=$((failures+1))
else
  echo 'apache_configtest=apache2ctl-missing'
  failures=$((failures+1))
fi

for path in \
  /xlxd/xlxd \
  /xlxd/xlxd.interlink \
  /xlxd/xlxd.whitelist \
  /xlxd/xlxd.blacklist \
  /var/log/xlxd.xml \
  /var/log/xlx.log \
  /var/www/html/xlxd \
  /var/www/html/xlxd/config/site.php
do
  if [[ -e "$path" ]]; then
    stat -c 'EXISTS | %n | owner=%U:%G | mode=%a | size=%s' "$path"
  else
    echo "MISSING | $path"
    failures=$((failures+1))
  fi
done

if [[ -f /xlxd/users_db/users.db ]] && command -v sqlite3 >/dev/null 2>&1; then
  integrity="$(sqlite3 /xlxd/users_db/users.db 'PRAGMA integrity_check;' 2>/dev/null || true)"
  echo "users_db_integrity=${integrity:-failed}"
  [[ "$integrity" == ok ]] || failures=$((failures+1))
else
  echo 'users_db_integrity=unavailable'
  failures=$((failures+1))
fi

echo "failures=$failures"
echo "warnings=$warnings"
echo "changes=NONE"
[[ "$failures" -eq 0 ]]
