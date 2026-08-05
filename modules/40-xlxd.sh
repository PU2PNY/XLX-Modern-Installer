#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"; CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: XLXD installation is blocked in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
REPOSITORY="${XLXD_REPOSITORY:-https://github.com/PP5PK/xlxd.git}"
INSTALL_DIR="${XLX_INSTALL_DIR:-/xlxd}"
SOURCE_DIR="${XLX_SOURCE_DIR:-/usr/src/xlxd}"
NUMBER="${XLX_NUMBER:-000}"
CALLSIGN="${XLX_CALLSIGN:-N0CALL}"
DOMAIN="${XLX_DOMAIN:-xlx.example.org}"
echo "mode=DRY_RUN"
echo "repository=$REPOSITORY"
echo "source_directory=$SOURCE_DIR"
echo "install_directory=$INSTALL_DIR"
echo "reflector_number=$NUMBER"
echo "sysop_callsign=$CALLSIGN"
echo "dashboard_domain=$DOMAIN"
[[ "$NUMBER" =~ ^[0-9]{3}$ ]] || { echo "XLX_NUMBER=INVALID"; exit 1; }
echo "XLX_NUMBER=VALID_FORMAT"
echo "repository_clone=NOT_EXECUTED"
echo "compilation=NOT_EXECUTED"
echo "installation=NOT_EXECUTED"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
