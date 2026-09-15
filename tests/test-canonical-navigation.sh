#!/usr/bin/env bash
set -Eeuo pipefail
# Final canonical-route regression gate.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }
INDEX="$ROOT/dashboard/index.php"
NGINX="$ROOT/modules/70-nginx.sh"
grep -Fq "if (\$p === 'digital-lab') return '/aprs-dprs';" "$INDEX" || fail 'APRS clean-route mapping missing from navigation'
grep -Fq "return '/' . rawurlencode(\$p);" "$INDEX" || fail 'clean-route navigation helper missing'
grep -Fq "\$canonical = 'https://{{REFLECTOR_DOMAIN}}' . page_url(\$page);" "$INDEX" || fail 'canonical metadata does not use the clean route'
if grep -Fq "return '?page=' . rawurlencode(\$p)" "$INDEX"; then fail 'query-string navigation remains'; fi
[ "$(grep -Fc 'Preserve old /?page=... links while making clean routes canonical.' "$NGINX")" -eq 2 ] || fail 'legacy root query redirects are not covered in HTTP and HTTPS sites'
grep -Fq 'digital-lab /aprs-dprs;' "$NGINX" || fail 'legacy APRS route mapping missing'
printf 'OK | clean navigation, canonical metadata and legacy query compatibility are aligned\n'
