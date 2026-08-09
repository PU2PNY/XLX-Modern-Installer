#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROD="/var/www/html/xlxd-novo"
REMOTE="https://github.com/PU2PNY/XLX-Modern-Installer.git"
BRANCH="sync-xlx026-20260809"
STAMP="$(date +%Y%m%d_%H%M%S)"
BASE="/root/xlx026-github-sync-${STAMP}"
REPO="${BASE}/repo"
CANDIDATE="${BASE}/candidate"
REVIEW="${BASE}/review"
REPORT="${BASE}/report.txt"

ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[ATENCAO] %s\n' "$*"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail 'Execute como root para conseguir ler todos os arquivos do painel.'
[ -d "$PROD" ] || fail "Painel de producao nao encontrado: $PROD"
command -v git >/dev/null 2>&1 || fail 'git nao encontrado.'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum nao encontrado.'
command -v diff >/dev/null 2>&1 || fail 'diff nao encontrado.'
command -v grep >/dev/null 2>&1 || fail 'grep nao encontrado.'

umask 077
mkdir -p "$BASE" "$CANDIDATE" "$REVIEW"
touch "$REPORT"
exec > >(tee -a "$REPORT") 2>&1

printf '============================================================\n'
printf ' XLX026 — PREPARAR SINCRONIZACAO SELETIVA COM GITHUB\n'
printf ' SOMENTE PREPARACAO / SEM COMMIT / SEM PUSH\n'
printf '============================================================\n\n'

printf '=== 1. CLONANDO BRANCH ISOLADA ===\n'
git clone --quiet --single-branch --branch "$BRANCH" "$REMOTE" "$REPO"
ok "Branch clonada em copia separada: $REPO"
printf '\n'

printf '=== 2. CONFIRMANDO BASE DO GITHUB ===\n'
git -C "$REPO" status --short --branch
git -C "$REPO" log -1 --oneline --decorate
printf '\n'

printf '=== 3. DEFININDO WHITELIST ===\n'
mapfile -t files < <(
  {
    printf '%s\n' \
      'api/common.php' \
      'api/live.php' \
      'api/status.php' \
      'api/ranking-v2.php' \
      'api/mtr.php' \
      'ranking-v2-view.php' \
      'assets/app.js' \
      'assets/app.css' \
      'assets/mtr.css' \
      'assets/mtr.js'

    find "$PROD/assets" -maxdepth 1 -type f \
      \( -name 'ao-vivo-*.css' -o -name 'ao-vivo-*.js' \
         -o -name 'history-*.css' -o -name 'history-*.js' \
         -o -name 'header-*.css' -o -name 'header-*.js' \
         -o -name 'mobile-menu-*.css' -o -name 'mobile-menu-*.js' \
         -o -name 'table-row-hover-*.css' -o -name 'table-row-hover-*.js' \) \
      -printf 'assets/%f\n'
  } | sort -u
)

printf 'Arquivos candidatos encontrados: %d\n' "${#files[@]}"
printf '%s\n' "${files[@]}"
printf '\n'

printf '=== 4. COPIANDO SOMENTE CANDIDATOS AUTORIZADOS ===\n'
for rel in "${files[@]}"; do
  src="$PROD/$rel"
  [ -f "$src" ] || { warn "Ausente em producao: $rel"; continue; }
  mkdir -p "$CANDIDATE/$(dirname "$rel")"
  cp -a "$src" "$CANDIDATE/$rel"
done
ok 'Copia candidata criada sem alterar producao nem repositorio Git.'
printf '\n'

printf '=== 5. IDENTIFICANDO CONTEUDO FORA DO ESCOPO ===\n'
forbidden='certificado|diploma|ham-news|ham-weather|reflectors|refletores|support-native'
: > "$REVIEW/forbidden-references.txt"
: > "$REVIEW/blocked-files.txt"

while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  printf '%s\n' "$hit" >> "$REVIEW/forbidden-references.txt"
done < <(grep -RniEI "$forbidden" "$CANDIDATE" 2>/dev/null || true)

if [ -s "$REVIEW/forbidden-references.txt" ]; then
  while IFS= read -r hit; do
    warn "Referencia fora do escopo: $hit"
    path="${hit%%:*}"
    rel="${path#${CANDIDATE}/}"
    printf '%s\n' "$rel"
  done < "$REVIEW/forbidden-references.txt" | sort -u > "$REVIEW/blocked-files.txt"
fi

blocked_refs="$(wc -l < "$REVIEW/forbidden-references.txt" | tr -d ' ')"
blocked_files="$(wc -l < "$REVIEW/blocked-files.txt" | tr -d ' ')"
printf '\nReferencias fora do escopo: %s\n' "$blocked_refs"
printf 'Arquivos bloqueados: %s\n' "$blocked_files"
if [ -s "$REVIEW/blocked-files.txt" ]; then
  printf '%s\n' 'Arquivos que NAO podem ser publicados sem tratamento:'
  cat "$REVIEW/blocked-files.txt"
fi
printf '\n'

printf '=== 6. INDEX.PHP — MAPA DE DEPENDENCIAS ===\n'
if [ -f "$PROD/index.php" ]; then
  cp -a "$PROD/index.php" "$REVIEW/index.php.production"
  sha256sum "$REVIEW/index.php.production"

  grep -oE 'assets/[A-Za-z0-9._/-]+\.(css|js)' "$PROD/index.php" 2>/dev/null | sort -u > "$REVIEW/index-assets-production.txt" || true

  if [ -f "$REPO/dashboard/index.php" ]; then
    grep -oE 'assets/[A-Za-z0-9._/-]+\.(css|js)' "$REPO/dashboard/index.php" 2>/dev/null | sort -u > "$REVIEW/index-assets-github.txt" || true
    diff -u "$REVIEW/index-assets-github.txt" "$REVIEW/index-assets-production.txt" > "$REVIEW/index-assets.diff" || true
  else
    : > "$REVIEW/index-assets-github.txt"
    : > "$REVIEW/index-assets.diff"
  fi

  if grep -niEI "$forbidden" "$REVIEW/index.php.production" > "$REVIEW/index-forbidden-references.txt" 2>/dev/null; then
    warn 'index.php contem recursos fora do escopo e NAO foi colocado em candidate.'
  else
    ok 'index.php nao apresentou referencias proibidas pelo filtro textual.'
  fi

  printf '%s\n' 'Assets carregados pela producao:'
  cat "$REVIEW/index-assets-production.txt"
  printf '\n%s\n' 'Diferenca de assets: GitHub atual -> producao'
  if [ -s "$REVIEW/index-assets.diff" ]; then
    cat "$REVIEW/index-assets.diff"
  else
    printf '%s\n' '[OK] Nenhuma diferenca de referencias CSS/JS detectada.'
  fi
else
  warn 'index.php nao encontrado em producao.'
fi
printf '\n'

printf '=== 7. COMPARANDO PRODUCAO COM A BRANCH ===\n'
: > "$REVIEW/comparison.txt"
: > "$REVIEW/ready-files.txt"
{
  printf '%-58s %-12s %-12s\n' 'ARQUIVO' 'CONTEUDO' 'ESCOPO'
  printf '%-58s %-12s %-12s\n' '----------------------------------------------------------' '------------' '------------'
  for rel in "${files[@]}"; do
    src="$CANDIDATE/$rel"
    dst="$REPO/dashboard/$rel"
    [ -f "$src" ] || continue

    scope='LIBERADO'
    if grep -Fxq "$rel" "$REVIEW/blocked-files.txt" 2>/dev/null; then
      scope='BLOQUEADO'
    fi

    if [ ! -f "$dst" ]; then
      state='NOVO'
    else
      prod_sha="$(sha256sum "$src" | awk '{print $1}')"
      repo_sha="$(sha256sum "$dst" | awk '{print $1}')"
      if [ "$prod_sha" = "$repo_sha" ]; then
        state='IGUAL'
      else
        state='DIFERENTE'
        mkdir -p "$REVIEW/diffs/$(dirname "$rel")"
        diff -u "$dst" "$src" > "$REVIEW/diffs/$rel.diff" || true
      fi
    fi

    printf '%-58s %-12s %-12s\n' "$rel" "$state" "$scope"

    if [ "$scope" = 'LIBERADO' ] && [ "$state" != 'IGUAL' ]; then
      printf '%s\n' "$rel" >> "$REVIEW/ready-files.txt"
    fi
  done
} | tee "$REVIEW/comparison.txt"
printf '\n'

printf '=== 8. GARANTINDO QUE CERTIFICADOS NAO ENTRARAM ===\n'
if find "$CANDIDATE" -type f \( -iname '*certif*' -o -iname '*diploma*' -o -iname '*qrcode*' -o -iname '*qr-code*' \) -print -quit | grep -q .; then
  fail 'Arquivo de certificado/diploma entrou na candidata. Nenhuma sincronizacao deve prosseguir.'
fi
ok 'Nenhum arquivo de certificado/diploma foi copiado para a candidata.'
printf '\n'

printf '=== 9. ARQUIVOS LIBERADOS QUE TEM MUDANCA ===\n'
ready_count="$(wc -l < "$REVIEW/ready-files.txt" | tr -d ' ')"
printf 'Quantidade: %s\n' "$ready_count"
if [ -s "$REVIEW/ready-files.txt" ]; then
  cat "$REVIEW/ready-files.txt"
else
  printf '%s\n' '[OK] Nenhum arquivo liberado pendente.'
fi
printf '\n'

printf '=== 10. RESUMO ===\n'
printf 'Workspace: %s\n' "$BASE"
printf 'Candidatos: %s\n' "$CANDIDATE"
printf 'Revisao/diffs: %s\n' "$REVIEW"
printf 'Relatorio: %s\n' "$REPORT"
printf '\n'
printf '%s\n' 'IMPORTANTE:'
printf '%s\n' '- producao NAO foi alterada;'
printf '%s\n' '- repositorio existente em /usr/src NAO foi alterado;'
printf '%s\n' '- nenhum git add foi executado;'
printf '%s\n' '- nenhum commit foi criado;'
printf '%s\n' '- nenhum push foi executado;'
printf '%s\n' '- index.php ficou separado para revisao porque mistura paginas/recursos.'
printf '\n'

if [ "$blocked_files" -gt 0 ]; then
  warn 'Existem arquivos compartilhados bloqueados. Eles exigem separacao cirurgica antes de qualquer publicacao.'
else
  ok 'Nenhum arquivo candidato contem referencia textual fora do escopo.'
fi

printf '\n============================================================\n'
printf '[OK] PREPARACAO CONCLUIDA — NENHUMA PUBLICACAO FOI FEITA\n'
printf '============================================================\n'
