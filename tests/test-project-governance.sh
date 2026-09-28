#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

for f in \
  PROJECT_START_HERE.md PROJECT_MASTER_SPEC.md PROJECT_RELEASE_STATUS.md PROJECT_TEST_MATRIX.md \
  CHANGELOG.md ARCHITECTURE.md SECURITY.md \
  docs/OPERATIONS.md docs/RECOVERY.md docs/DECISIONS.md docs/RESEARCH_BACKLOG.md; do
  [[ -s "$ROOT/$f" ]] || fail "missing canonical document: $f"
done

version="$(tr -d '\r\n' < "$ROOT/VERSION")"
grep -Fq "**Current release: v$version**" "$ROOT/README.md" || fail "README version differs from VERSION"
grep -Fq "Version: **$version**" "$ROOT/docs/FEATURES.md" || fail "docs/FEATURES version differs from VERSION"

grep -Fq 'modules/70-nginx.sh' "$ROOT/ARCHITECTURE.md" || fail "architecture does not identify authoritative Nginx module"
grep -Fq 'Nginx + PHP-FPM' "$ROOT/ARCHITECTURE.md" || fail "architecture does not identify Nginx + PHP-FPM"
! grep -Fq 'Apache/PHP dashboard stack' "$ROOT/docs/FEATURES.md" || fail "features still claim Apache as dashboard stack"
! grep -Fq 'sudo systemctl status apache2 --no-pager' "$ROOT/BETA-TESTING.md" || fail "beta guide still validates Apache as active stack"
! grep -Fq 'sudo apache2ctl configtest' "$ROOT/BETA-TESTING.md" || fail "beta guide still uses apache2ctl"
! grep -Fq 'Nenhum módulo que altere produção está habilitado' "$ROOT/STATUS.md" || fail "status still claims production-changing modules are disabled"
! grep -Fq '[ ] Real installation enabled' "$ROOT/RELEASE_CHECKLIST.md" || fail "release checklist still claims real install is disabled"

grep -Fq 'GOV-001' "$ROOT/PROJECT_MASTER_SPEC.md" || fail "governance requirement GOV-001 missing"
grep -Fq 'TEST-015' "$ROOT/PROJECT_TEST_MATRIX.md" || fail "governance test matrix row missing"

ok 'canonical project governance and Nginx documentation are coherent'
