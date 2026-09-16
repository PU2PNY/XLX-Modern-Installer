#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n "$ROOT/install.sh"
bash -n "$ROOT/start.sh"
bash -n "$ROOT/dashboard/install/install-dashboard.sh"

grep -Fq 'Strict language isolation.' "$ROOT/install.sh" || fail 'strict installer-language contract missing'
! grep -Fq 'Questionário clássico bilíngue' "$ROOT/install.sh" || fail 'legacy bilingual base-installer mode still present'
! grep -Fq 'native and mandatory / nativo e obrigatório' "$ROOT/install.sh" || fail 'mixed-language install-plan line remains'
! grep -Fq 'Perguntas em Português + English' "$ROOT/start.sh" || fail 'entry point still advertises bilingual flow'

grep -Fq 'UI_LANG="${XLX_UI_LANG:-pt-BR}"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'dashboard installer does not consume installer UI language'
grep -Fq 'case "$UI_LANG:$key"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'operator prompts are still tied to dashboard content language'
! grep -Fq 'Dashboard Language / Idioma do Painel' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard language heading remains'
! grep -Fq 'ERROR / ERRO:' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard installer error remains'
! grep -Fq 'Manual retry / tentativa manual' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual HTTPS retry remains'

ok 'installer/operator language is isolated from dashboard content language'
