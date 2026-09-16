#!/usr/bin/env bash
set -Eeuo pipefail
# Final regression contract for clean and recovered installations.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }

grep -Fq 'FINAL_ADMIN_EDGE_READY=0' "$ROOT/modules/69-admin-page.sh" || fail 'Admin installer must distinguish the pre-Nginx stage'
grep -Fq 'HTTP proof deferred until final Nginx/PHP-FPM activation' "$ROOT/modules/69-admin-page.sh" || fail 'pre-edge Admin route deferral marker is missing'
grep -Fq "ADMIN_ROUTE_FILE='/etc/xlx-modern-control/route'" "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'final Admin route probe is missing'
grep -Fq '/ranking /refletores /certificado /aprs-dprs' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'canonical public route gate is incomplete'
grep -Fq '["/aprs-dprs",200,"html"]' "$ROOT/modules/70-production-parity.sh" || fail 'APRS self-test path must use canonical no-slash URL'
if grep -Fq '["/aprs-dprs/",200,"html"]' "$ROOT/modules/70-production-parity.sh"; then fail 'non-canonical APRS self-test path remains'; fi
printf 'OK | private Admin and canonical public route readiness contracts are enforced\n'
