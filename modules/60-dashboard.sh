#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Compatibility entry point kept for older automation. The XLX Modern
# Dashboard is shipped inside this repository and is never cloned from an
# external dashboard installer.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-check}"
CONFIG="${2:-}"

case "$MODE" in
  check|dry-run|plan)
    echo 'mode=CHECK'
    echo 'dashboard_source=LOCAL_REPOSITORY'
    echo 'web_root=/var/www/html/xlxd'
    echo 'installer=modules/60-dashboard-modern.sh'
    echo 'changes=NONE'
    echo 'status=CHECK_COMPLETE'
    ;;
  install)
    [[ -z "$CONFIG" || -f "$CONFIG" ]] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
    [[ -z "$CONFIG" ]] || source "$CONFIG"
    export INSTALL_DIR="${INSTALL_DIR:-/var/www/html/xlxd}"
    exec bash "$ROOT/modules/60-dashboard-modern.sh"
    ;;
  *)
    echo "ERROR: invalid mode: $MODE" >&2
    exit 2
    ;;
esac
