#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
command -v php >/dev/null 2>&1 || fail 'php is required'
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for locale in pt-BR en; do
  target="$tmp/$locale.php"
  cp "$ROOT/control/current-production-admin.php" "$target"
  python3 "$ROOT/control/build-admin.py" "$target" "$locale"
  php -l "$target" >/dev/null
  grep -Fq "const CTRL_VER='1.5.1'" "$target" || fail "Admin 1.5.1 missing in $locale"
  grep -Fq 'health-status' "$target" || fail "Health missing in $locale"
  grep -Fq 'access-interlink-add' "$target" || fail "Interlink add missing in $locale"
  grep -Fq 'access-interlink-delete' "$target" || fail "Interlink delete missing in $locale"
  grep -Fq 'radioid_api_search' "$target" || fail "RadioID.net lookup missing in $locale"
  ! grep -Eq 'Terminal XLXD|Terminal SSH|shell_exec\(\$_POST|passthru\(\$_POST' "$target" || fail "terminal marker leaked in $locale"
done
grep -Fq 'Acesso restrito' "$tmp/pt-BR.php" || fail 'Portuguese login marker missing'
grep -Fq 'Restricted access' "$tmp/en.php" || fail 'English login marker missing'
for phrase in 'Acesso restrito' 'Usuário ou senha inválidos.' 'Área técnica privada' 'Executar testes gerais' 'Pesquisar cadastro' 'Atualizar banco de indicativos' 'Reiniciar XLXD' 'Não foi possível salvar:' 'Gerencie visualmente a base local' 'Gerenciador protegido' 'Registro RadioID adicionado' 'confirmação ou senha inválida.'; do
  ! grep -Fq "$phrase" "$tmp/en.php" || fail "Portuguese Admin text remained in English build: $phrase"
done
for bad in '/etc/legacy-control' '/var/lib/legacy-control' '/usr/local/sbin/legacy-control-'; do
  ! grep -Fq "$bad" "$tmp/pt-BR.php" "$tmp/en.php" || fail "production marker leaked into Admin: $bad"
done
ok 'Admin 1.5.1 generator produces validated Portuguese and English interfaces'

# Admin crawler protection must survive both language builds.
for locale in pt-BR en; do
  tmp="$(mktemp /tmp/xlx-admin-crawler.XXXXXX.php)"
  cp control/current-production-admin.php "$tmp"
  python3 control/build-admin.py "$tmp" "$locale"
  grep -Fq 'googlebot|bingbot' "$tmp"
  rm -f "$tmp"
done
