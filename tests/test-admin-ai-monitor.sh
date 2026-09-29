#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }

F="$ROOT/control/current-production-admin.php"
php -l "$F" >/dev/null || fail "Admin PHP syntax failed"
grep -Fq "\$api['ai_monitor']" "$F" || fail "ai_monitor sanitized status is not consumed"
grep -Fq 'id="ia-server"' "$F" || fail "AI Server section is missing"
grep -Fq 'Última ação da IA' "$F" || fail "last AI action is not visible"
grep -Fq 'Análise automática por IA ainda não está habilitada nesta versão.' "$F" || fail "truthful inference notice is missing"
grep -Fq '?refresh=1#ia-server' "$F" || fail "AI status refresh action is missing"
grep -Fq '?view=health">Ver saúde operacional</a>' "$F" || fail "operational health shortcut is missing"
if grep -Fq 'OPENAI_API_KEY' "$F"; then fail "secret variable name must not be read by Admin PHP"; fi
if grep -Fq 'api.openai.com' "$F"; then fail "Admin must reuse sanitized status instead of calling OpenAI directly"; fi
printf 'admin_ai_monitor_contract=PASS\n'
