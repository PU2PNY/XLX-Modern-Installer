#!/bin/bash
set -euo pipefail
TABLE=xlx026_dmrnorm
case "${1:-}" in
  start)
    /usr/sbin/nft delete table inet "$TABLE" 2>/dev/null || true
    /usr/sbin/nft -f - <<'NFT'
table inet xlx026_dmrnorm {
  chain input {
    type filter hook input priority -50; policy accept;
    ip daddr 82.152.175.30 udp dport { 62030, 8880 } counter queue num 26 bypass
  }
}
NFT
    ;;
  stop)
    /usr/sbin/nft delete table inet "$TABLE" 2>/dev/null || true
    ;;
  *) echo "uso: $0 start|stop" >&2; exit 2 ;;
esac
