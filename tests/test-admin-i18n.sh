#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
command -v php >/dev/null 2>&1 || fail 'php is required'
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
locales=(pt-BR en es fr de it)
for locale in "${locales[@]}"; do
  f="$tmp/$locale.php"
  cp "$ROOT/control/current-production-admin.php" "$f"
  python3 "$ROOT/control/build-admin.py" "$f" "$locale"
  php -l "$f" >/dev/null || fail "PHP syntax broken in $locale"
  grep -Fq "lang=\"$locale\"" "$f" || fail "HTML lang mismatch in $locale"
  for marker in "const CTRL_VER='1.5.1'" health-status access-interlink-add access-interlink-delete radioid_api_search radioid_save; do
    grep -Fq "$marker" "$f" || fail "$marker missing in $locale"
  done
  ! grep -Eq 'Terminal XLXD|Terminal SSH|shell_exec\(\$_POST|passthru\(\$_POST' "$f" || fail "terminal marker leaked in $locale"
done
grep -Fq 'Acesso restrito' "$tmp/pt-BR.php" || fail 'pt-BR login marker missing'
grep -Fq 'Restricted access' "$tmp/en.php" || fail 'English login marker missing'
grep -Fq 'Acceso restringido' "$tmp/es.php" || fail 'Spanish login marker missing'
grep -Fq 'Accès restreint' "$tmp/fr.php" || fail 'French login marker missing'
grep -Fq 'Eingeschränkter Zugriff' "$tmp/de.php" || fail 'German login marker missing'
grep -Fq 'Accesso riservato' "$tmp/it.php" || fail 'Italian login marker missing'
python3 - "$ROOT" "$tmp" <<'PY'
import json,re,sys
from pathlib import Path
root=Path(sys.argv[1]); tmp=Path(sys.argv[2])
en_catalog=json.loads((root/'control/admin-en.json').read_text(encoding='utf-8'))
for loc in ('es','fr','de','it'):
    cat=json.loads((root/f'control/admin-{loc}.json').read_text(encoding='utf-8'))
    if set(cat)!=set(en_catalog): raise SystemExit(f'{loc}: catalog key mismatch')
def fingerprint(path):
    s=path.read_text(encoding='utf-8')
    return {
      'id':sorted(set(re.findall(r'\bid=["\']([^"\']+)["\']',s))),
      'name':sorted(set(re.findall(r'\bname=["\']([^"\']+)["\']',s))),
      'actions':sorted(set(re.findall(r"(?:action|op|cmd)\s*===?\s*['\"]([^'\"]+)['\"]",s))),
      'helpers':sorted(set(re.findall(r'(?:health-status|access-[a-z-]+|radioid[-_][a-z-]+|restart|listeners|logs|backups)',s)))
    }
ref=fingerprint(tmp/'pt-BR.php')
for loc in ('en','es','fr','de','it'):
    if fingerprint(tmp/f'{loc}.php') != ref:
        raise SystemExit(f'{loc}: functional structure changed by translation')
for loc in ('en','es','fr','de','it'):
    built=(tmp/f'{loc}.php').read_text(encoding='utf-8')
    cat=en_catalog if loc=='en' else json.loads((root/f'control/admin-{loc}.json').read_text(encoding='utf-8'))
    leaks=[]
    for source,target in cat.items():
        if source != target and len(source) >= 8 and source in built:
            leaks.append(source)
    if leaks:
        raise SystemExit(f'{loc}: untranslated Admin strings remain: {leaks[:8]}')
PY
for bad in '/etc/legacy-control' '/var/lib/legacy-control' '/usr/local/sbin/legacy-control-'; do
  ! grep -Fq "$bad" "$tmp"/*.php || fail "production marker leaked: $bad"
done
ok 'Admin has six locale-faithful builds with identical functional structure'
