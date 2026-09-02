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
  python3 "$ROOT/control/patch-admin-interlink-v2.py" "$target" "$locale"
  php -l "$target" >/dev/null
  grep -Fq "const CTRL_VER='1.4.0'" "$target" || fail "wrong Admin version in $locale"
  grep -Fq 'radioid_save' "$target" || fail "missing RadioID save action in $locale Admin"
  grep -Fq 'interlink-save' "$target" || fail "missing Interlink save action in $locale Admin"
  grep -Fq 'interlink-delete' "$target" || fail "missing Interlink delete action in $locale Admin"
  grep -Fq 'name="interlink_peer"' "$target" || fail "missing peer field in $locale Admin"
  grep -Fq "($access['interlink']['entries']??[])" "$target" || fail "missing Interlink entries model in $locale Admin"
done

grep -Fq 'Acesso restrito' "$tmp/pt-BR.php" || fail 'Portuguese Admin login marker is missing'
grep -Fq 'Controle de acesso XLXD' "$tmp/pt-BR.php" || fail 'Portuguese access-control title is missing'
grep -Fq 'Acesso rápido' "$tmp/pt-BR.php" || fail 'Portuguese quick-links title is missing'
grep -Fq 'Salvar Interlink' "$tmp/pt-BR.php" || fail 'Portuguese Interlink action is missing'
if grep -Fq 'Restricted access' "$tmp/pt-BR.php"; then fail 'English login text leaked into Portuguese Admin'; fi

grep -Fq 'Restricted access' "$tmp/en.php" || fail 'English Admin login marker is missing'
grep -Fq 'XLXD Access Control' "$tmp/en.php" || fail 'English access-control title is missing'
grep -Fq 'Quick links' "$tmp/en.php" || fail 'English quick-links title is missing'
grep -Fq 'Save Interlink' "$tmp/en.php" || fail 'English Interlink action is missing'

for phrase in 'Acesso restrito' 'Usuário ou senha inválidos.' 'Área técnica privada' 'Executar testes gerais' 'Pesquisar cadastro' 'Atualizar banco de indicativos' 'Reiniciar XLXD' 'Não foi possível salvar:' 'Gerencie visualmente a base local' 'Gerenciador protegido' 'Registro RadioID adicionado' 'confirmação ou senha inválida.' 'Controle de acesso XLXD' 'Acesso rápido' 'Salvar Interlink' 'Nenhum peer Interlink ativo'; do
  if grep -Fq "$phrase" "$tmp/en.php"; then
    fail "Portuguese Admin text remained in English build: $phrase"
  fi
done

for phrase in 'XLXD Access Control' 'Quick links' 'After login only' 'No active Interlink peers.' 'Add or update peer' 'Confirm your password'; do
  if grep -Fq "$phrase" "$tmp/pt-BR.php"; then
    fail "English Admin text remained in Portuguese build: $phrase"
  fi
done

ok 'Admin generator produces complete Portuguese and English interfaces with peer-based Interlink'
