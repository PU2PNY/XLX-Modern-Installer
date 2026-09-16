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
! grep -Fq 'Uso / Usage' "$ROOT/install.sh" || fail 'bilingual main help remains'
! grep -Fq 'ERRO / ERROR:' "$ROOT/install.sh" || fail 'bilingual main error remains'
! grep -Fq 'fatal "Arquivo de respostas da interface visual' "$ROOT/install.sh" || fail 'hard-coded Portuguese visual-answer error remains'
! grep -Fq 'Perguntas em Português + English' "$ROOT/start.sh" || fail 'entry point still advertises bilingual flow'

grep -Fq 'UI_LANG="${XLX_UI_LANG:-pt-BR}"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'dashboard installer does not consume installer UI language'
grep -Fq 'case "$UI_LANG:$key"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'operator prompts are still tied to dashboard content language'
! grep -Fq 'Dashboard Language / Idioma do Painel' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard language heading remains'
! grep -Fq 'Usage / Uso' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard help remains'
! grep -Fq 'ERROR / ERRO:' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard installer error remains'
! grep -Fq 'Manual retry / tentativa manual' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual HTTPS retry remains'

main_en="$(bash "$ROOT/install.sh" --ui-lang=en --help)"
main_pt="$(bash "$ROOT/install.sh" --ui-lang=pt-BR --help)"
dash_en="$(XLX_UI_LANG=en bash "$ROOT/dashboard/install/install-dashboard.sh" --help)"
dash_pt="$(XLX_UI_LANG=pt-BR bash "$ROOT/dashboard/install/install-dashboard.sh" --help)"

printf '%s' "$main_en" | grep -Fq 'Usage:' || fail 'English main help missing'
printf '%s' "$main_en" | grep -Eq '(^|[[:space:]])(Uso|Opções|Apenas|Define|Atualiza|Permite)(:|[[:space:]])' && fail 'Portuguese leaked into English main help'
printf '%s' "$main_pt" | grep -Fq 'Uso:' || fail 'Portuguese main help missing'
printf '%s' "$main_pt" | grep -Eq '(^|[[:space:]])(Usage|Options|Checks|Sets|Updates|Allows)(:|[[:space:]])' && fail 'English leaked into Portuguese main help'

printf '%s' "$dash_en" | grep -Fq 'Supported dashboard languages:' || fail 'English dashboard help missing'
printf '%s' "$dash_en" | grep -Eq '(Uso:|Idiomas disponíveis|Português \(Brasil\)|Espanhol|Francês|Alemão)' && fail 'Portuguese leaked into English dashboard help'
printf '%s' "$dash_pt" | grep -Fq 'Idiomas disponíveis para o painel:' || fail 'Portuguese dashboard help missing'
printf '%s' "$dash_pt" | grep -Eq '(Usage:|Supported dashboard languages:|Portuguese \(Brazil\)|Spanish|French|German)' && fail 'English leaked into Portuguese dashboard help'

ok 'installer/operator language is isolated from dashboard content language'
ok 'main and dashboard help are monolingual in pt-BR/en'
