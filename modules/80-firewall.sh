#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"; CONFIG="${2:-}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: firewall changes are blocked in this development build." >&2; exit 20;; esac
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[ -z "$CONFIG" ] || source "$CONFIG"
ENABLE_FIREWALL="${ENABLE_FIREWALL:-no}"
TCP_PORTS=(22 80 443 8080 40001)
UDP_PORTS=(8880 10001 10002 10100 12345 12346 20001 21110 30001 30051 40000 42000 62030)
echo "mode=DRY_RUN"
echo "enabled=$ENABLE_FIREWALL"
echo "required_tcp_ports=${TCP_PORTS[*]}"
echo "required_udp_ports=${UDP_PORTS[*]}"
echo "rules_written=NO"
echo "firewall_reloaded=NO"
echo "changes=NONE"
