#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROD="/var/www/html/xlxd-novo"
REMOTE="https://github.com/PU2PNY/XLX-Modern-Installer.git"
BRANCH="sync-xlx026-20260809"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="/root/XLX026_SHARED_REVIEW_${STAMP}"
REPO="$OUT/repo"
BASE="$OUT/github-base/dashboard"
CURRENT="$OUT/production/dashboard"
DIFFS="$OUT/diffs"
MANIFEST="$OUT/MANIFEST.txt"
ARCHIVE="${OUT}.tar.gz"

ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[ATENCAO] %s\n' "$*"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail 'Execute como root.'
[ -d "$PROD" ] || fail "Painel nao encontrado: $PROD"
command -v git >/dev/null 2>&1 || fail 'git nao encontrado.'
command -v diff >/dev/null 2>&1 || fail 'diff nao encontrado.'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum nao encontrado.'
command -v tar >/dev/null 2>&1 || fail 'tar nao encontrado.'

umask 077
mkdir -p "$OUT" "$BASE" "$CURRENT" "$DIFFS"

printf '============================================================\n'
printf ' XLX026 — REVISAO CIRURGICA DOS ARQUIVOS COMPARTILHADOS\n'
printf ' SOMENTE LEITURA / SEM COMMIT / SEM PUSH\n'
printf '============================================================\n\n'

printf '=== 1. CLONANDO A BRANCH ATUAL EM AREA TEMPORARIA ===\n'
git clone --quiet --depth 1 --single-branch --branch "$BRANCH" "$REMOTE" "$REPO"
ok "Branch clonada: $(git -C "$REPO" rev-parse --short HEAD)"
printf '\n'

files=(
  'api/common.php'
  'assets/app.css'
  'assets/app.js'
  'index.php'
)

printf '=== 2. COPIANDO AS DUAS VERSOES DOS 4 ARQUIVOS ===\n'
for rel in "${files[@]}"; do
  github="$REPO/dashboard/$rel"
  production="$PROD/$rel"

  [ -f "$github" ] || fail "Ausente no GitHub clonado: dashboard/$rel"
  [ -f "$production" ] || fail "Ausente em producao: $production"

  mkdir -p "$BASE/$(dirname "$rel")" "$CURRENT/$(dirname "$rel")" "$DIFFS/$(dirname "$rel")"
  cp -a "$github" "$BASE/$rel"
  cp -a "$production" "$CURRENT/$rel"

  diff -u \
    --label "github/dashboard/$rel" \
    --label "production/dashboard/$rel" \
    "$github" "$production" \
    > "$DIFFS/$rel.diff" || true
done
ok 'Versoes e diffs copiados.'
printf '\n'

printf '=== 3. GERANDO RESUMO DOS DIFFS ===\n'
for rel in "${files[@]}"; do
  d="$DIFFS/$rel.diff"
  additions="$(grep -c '^+' "$d" 2>/dev/null || true)"
  deletions="$(grep -c '^-' "$d" 2>/dev/null || true)"
  hunks="$(grep -c '^@@' "$d" 2>/dev/null || true)"
  printf '%-22s hunks=%-4s +%-5s -%-5s\n' "$rel" "$hunks" "$additions" "$deletions"
done
printf '\n'

printf '=== 4. MAPA DE REFERENCIAS FORA DO ESCOPO NA PRODUCAO ===\n'
forbidden='certificado|diploma|ham-news|ham-weather|reflectors|refletores|support-native'
grep -RniEI "$forbidden" "$CURRENT" > "$OUT/forbidden-production.txt" 2>/dev/null || true
printf 'Referencias encontradas: %s\n' "$(wc -l < "$OUT/forbidden-production.txt")"
printf '\n'

printf '=== 5. MANIFESTO SHA256 ===\n'
{
  printf 'XLX026 shared-file surgical review\n'
  printf 'Created: %s\n' "$(date -Is)"
  printf 'Branch: %s\n' "$BRANCH"
  printf 'Commit: %s\n\n' "$(git -C "$REPO" rev-parse HEAD)"

  printf '[GITHUB-BASE]\n'
  for rel in "${files[@]}"; do
    sha256sum "$BASE/$rel"
  done

  printf '\n[PRODUCTION]\n'
  for rel in "${files[@]}"; do
    sha256sum "$CURRENT/$rel"
  done

  printf '\n[DIFFS]\n'
  find "$DIFFS" -type f -name '*.diff' -print0 | sort -z | xargs -0 sha256sum
} > "$MANIFEST"
ok "Manifesto: $MANIFEST"
printf '\n'

printf '=== 6. CRIANDO PACOTE ===\n'
rm -rf "$REPO"
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"
chmod 600 "$ARCHIVE"
ok "Pacote: $ARCHIVE"
printf 'SHA256: %s\n' "$(sha256sum "$ARCHIVE" | awk '{print $1}')"
printf '\n'

printf 'IMPORTANTE:\n'
printf '%s\n' '- producao NAO foi alterada;'
printf '%s\n' '- branch GitHub NAO foi alterada por este script;'
printf '%s\n' '- nenhum git add, commit ou push foi executado;'
printf '%s\n' '- o pacote serve apenas para separar as mudancas autorizadas das proibidas.'
printf '\n============================================================\n'
printf '[OK] PACOTE DE REVISAO PRONTO\n'
printf '============================================================\n'
