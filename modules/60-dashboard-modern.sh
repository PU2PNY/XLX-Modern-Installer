#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"

bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"
XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/post-install.sh"
bash "$ROOT/modules/65-callsign-directory.sh"
XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/modules/66-certificates.sh"
