#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/control/current-production-admin.php"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }

php -l "$F" >/dev/null || fail "Admin PHP syntax failed"
for marker in   "\$view=(string)(\$_GET['view']??'home')"   "['home','health','access','radioid']"   "?view=health"   "?view=access"   "?view=radioid"   "if(\$view==='home')"   "if(\$view==='health')"   "if(\$view==='access')"   "if(\$view==='radioid')"   "Navegação do Controle"
do
  grep -Fq "$marker" "$F" || fail "missing navigation marker: $marker"
done
grep -Fq "Ver saúde operacional</a>" "$F" || fail "health shortcut missing"
grep -Fq 'href="<?=h($adminPath)?>?view=health"' "$F" || fail "health shortcut must use private admin path"
grep -Fq "str_starts_with(\$postedAction,'access-')" "$F" || fail "access POST fallback missing"
grep -Fq "str_starts_with(\$postedAction,'radioid')" "$F" || fail "radioid POST fallback missing"
if grep -Fq "/index.php/controle/" "$F"; then fail "invalid legacy path reintroduced"; fi
printf 'admin_view_navigation=PASS\n'
