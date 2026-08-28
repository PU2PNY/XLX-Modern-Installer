#!/usr/bin/env bash
set -Eeuo pipefail
LOG_FILE="${XLX_LOG_FILE:-/var/log/xlx.log}"

if [ ! -e "$LOG_FILE" ]; then
    install -m 0640 -o root -g www-data /dev/null "$LOG_FILE"
else
    chown root:www-data "$LOG_FILE"
    chmod 0640 "$LOG_FILE"
fi

exec journalctl -u xlxd.service -f -n 0 -o short-iso >> "$LOG_FILE"
