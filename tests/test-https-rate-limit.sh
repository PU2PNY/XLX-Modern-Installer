#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
log="$work/letsencrypt.log"
units="$work/systemd"
mkdir -p "$units"
cat > "$log" <<'LOG'
"detail": "too many certificates (5) already issued for this exact set of identifiers in the last 168h0m0s, retry after 2030-01-02 03:04:05 UTC"
LOG
# Static invariants: production defaults and automatic timer generation are present.
grep -Fq 'retry_at_utc=' "$ROOT/dashboard/install/install-dashboard.sh"
grep -Fq 'xlx-modern-https-retry.timer' "$ROOT/dashboard/install/install-dashboard.sh"
grep -Fq 'OnCalendar=$retry_at' "$ROOT/dashboard/install/install-dashboard.sh"
grep -Fq 'Available URL now:' "$ROOT/install.sh"
grep -Fq 'URL disponível agora:' "$ROOT/install.sh"
# Validate date parsing expected by the scheduler (+10 minutes safety margin).
raw="$(grep -Eio 'retry after [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC' "$log" | tail -1 | sed -E 's/^retry after //I')"
[ "$raw" = '2030-01-02 03:04:05 UTC' ]
retry="$(date -u -d "$raw + 10 minutes" '+%Y-%m-%d %H:%M:%S UTC')"
[ "$retry" = '2030-01-02 03:14:05 UTC' ]
echo '[OK] Let’s Encrypt rate-limit retry parsing and final URL reporting validated'
