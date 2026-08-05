#!/usr/bin/env bash
set -Eeuo pipefail
CONFIG="${1:-}"
[ -n "$CONFIG" ] || { echo "configuration_file=not_provided"; exit 1; }
[ -f "$CONFIG" ] || { echo "configuration_file=not_found"; exit 1; }
source "$CONFIG"
for var in XLX_NUMBER XLX_CALLSIGN XLX_DOMAIN; do
  [ -n "${!var:-}" ] || { echo "missing_variable=$var"; exit 1; }
done
[[ "$XLX_NUMBER" =~ ^[0-9]{3}$ ]] || { echo "invalid_XLX_NUMBER=$XLX_NUMBER"; exit 1; }
echo "configuration=VALID"
echo "changes=NONE"
