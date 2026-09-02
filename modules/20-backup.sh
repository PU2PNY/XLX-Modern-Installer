#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MODE="${1:-check}"
CONFIG="${2:-}"
case "$MODE" in check|dry-run|plan) ;; *) echo "ERROR: this helper is read-only; the main installer owns real backups." >&2; exit 20;; esac
[[ -z "$CONFIG" || -f "$CONFIG" ]] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[[ -z "$CONFIG" ]] || source "$CONFIG"

WEB_ROOT="${XLX_WEB_ROOT:-/var/www/html/xlxd}"
TARGETS=(
  "${XLX_INSTALL_DIR:-/xlxd}"
  "$WEB_ROOT"
  "/usr/src/xlxd"
  "/usr/src/XLXEcho"
  "/etc/xlx-modern"
  "/etc/xlx-modern-control"
  "/etc/apache2"
  "/etc/systemd/system"
)

echo "mode=CHECK"
echo "backup_root=/var/backups/xlx-reflector/<timestamp>"
echo "manifest=ENABLED"
echo "hashes=ENABLED"
for target in "${TARGETS[@]}"; do
  if [[ -e "$target" ]]; then
    size="$(du -sh "$target" 2>/dev/null | awk '{print $1}')"
    echo "WOULD_BACKUP | exists=yes | size=${size:-unknown} | $target"
  else
    echo "WOULD_BACKUP | exists=no | $target"
  fi
done
echo "changes=NONE"
echo "status=CHECK_COMPLETE"
