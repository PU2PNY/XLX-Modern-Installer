#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"; CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: XLX Echo installation is blocked in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
REPOSITORY="${XLXECHO_REPOSITORY:-https://github.com/PP5PK/XLXEcho.git}"
SERVICE_NAME="${XLXECHO_SERVICE_NAME:-xlxecho.service}"
ENABLED="${ENABLE_ECHO:-yes}"
echo "mode=DRY_RUN"
echo "enabled=$ENABLED"
echo "repository=$REPOSITORY"
echo "service=$SERVICE_NAME"
[ "$ENABLED" = yes ] || { echo "status=SKIPPED_BY_CONFIGURATION"; echo "changes=NONE"; exit 0; }
echo "existing_state=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)"
echo "repository_clone=NOT_EXECUTED"
echo "compilation=NOT_EXECUTED"
echo "service_restart=NOT_EXECUTED"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
