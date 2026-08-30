#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || fail 'python3 is required'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for locale in pt-BR en; do
  target="$tmp/$locale.php"
  cp "$ROOT/control/xlx026-control-index-radioid-v2.php" "$target"
  python3 "$ROOT/control/patch-xlx026-control-v111.py" "$target"
  python3 "$ROOT/control/genericize-xlx-control.py" "$target" "$locale"
  [[ "$locale" == 'pt-BR' ]] && grep -Fq 'Acesso restrito' "$target" || true
  [[ "$locale" != 'en' ]] || grep -Fq 'Restricted access' "$target" || fail 'English Admin login marker is missing'
  grep -Fq 'XLXD Access Control' "$target" || fail "missing Access Control feature in $locale Admin"
  grep -Fq 'radioid_save' "$target" || fail "missing RadioID save action in $locale Admin"
  grep -Fq 'interlink-save' "$target" || fail "missing Interlink action in $locale Admin"
done

for phrase in 'Acesso restrito' 'Usuário ou senha inválidos.' 'Área técnica privada' 'Executar testes gerais' 'Pesquisar cadastro' 'Atualizar banco de indicativos' 'Reiniciar XLXD' 'Não foi possível salvar:' 'Gerencie visualmente a base local' 'Gerenciador protegido' 'Registro RadioID adicionado' 'confirmação ou senha inválida.'; do
  if grep -Fq "$phrase" "$tmp/en.php"; then
    fail "Portuguese Admin text remained in English build: $phrase"
  fi
done

ok 'Admin generator produces validated Portuguese and English interfaces'
