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
info(){ printf '[INFO] %s\n' "$*"; }
warn(){ printf '[ATENCAO] %s\n' "$*"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }

exec > >(tee "$REPORT") 2>&1

printf '============================================================\n'
printf ' XLX026 — PREPARAR SINCRONIZACAO SELETIVA COM GITHUB\n'
printf ' SOMENTE PREPARACAO / SEM COMMIT / SEM PUSH\n'
printf '============================================================\n\n'

[ "$(id -u)" -eq 0 ] || fail 'Execute como root para conseguir ler todos os arquivos do painel.'
[ -d "$PROD" ] || fail "Painel de producao nao encontrado: $PROD"
command -v git >/dev/null 2>&1 || fail 'git nao encontrado.'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum nao encontrado.'
command -v rsync >/dev/null 2>&1 || fail 'rsync nao encontrado.'

umask 077
mkdir -p "$BASE" "$CANDIDATE" "$REVIEW"

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

printf '=== 5. BLOQUEANDO CONTEUDO FORA DO ESCOPO ===\n'
forbidden='certificado|diploma|ham-news|ham-weather|reflectors|refletores|support-native'
blocked=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  warn "Referencia fora do escopo: $hit"
  blocked=$((blocked+1))
done < <(grep -RniEI "$forbidden" "$CANDIDATE" 2>/dev/null || true)

printf '\nReferencias fora do escopo encontradas: %d\n' "$blocked"
printf '\n'

printf '=== 6. INDEX.PHP — SOMENTE PARA REVISAO ===\n'
if [ -f "$PROD/index.php" ]; then
  cp -a "$PROD/index.php" "$REVIEW/index.php.production"
  sha256sum "$REVIEW/index.php.production"
  if grep -niEI "$forbidden" "$REVIEW/index.php.production" > "$REVIEW/index-forbidden-references.txt" 2>/dev/null; then
    warn 'index.php contem recursos fora do escopo e NAO foi colocado em candidate.'
    printf 'Referencias registradas em: %s\n' "$REVIEW/index-forbidden-references.txt"
  else
    ok 'index.php nao apresentou referencias proibidas pelo filtro textual.'
  fi
else
  warn 'index.php nao encontrado em producao.'
fi
printf '\n'

printf '=== 7. COMPARANDO PRODUCAO COM A BRANCH ===\n'
{
  printf '%-58s %-12s\n' 'ARQUIVO' 'SITUACAO'
  printf '%-58s %-12s\n' '----------------------------------------------------------' '------------'
  for rel in "${files[@]}"; do
    src="$CANDIDATE/$rel"
    dst="$REPO/dashboard/$rel"
    [ -f "$src" ] || continue
    if [ ! -f "$dst" ]; then
      printf '%-58s %-12s\n' "$rel" 'NOVO'
      continue
    fi
    prod_sha="$(sha256sum "$src" | awk '{print $1}')"
    repo_sha="$(sha256sum "$dst" | awk '{print $1}')"
    if [ "$prod_sha" = "$repo_sha" ]; then
      printf '%-58s %-12s\n' "$rel" 'IGUAL'
    else
      printf '%-58s %-12s\n' "$rel" 'DIFERENTE'
      mkdir -p "$REVIEW/diffs/$(dirname "$rel")"
      diff -u "$dst" "$src" > "$REVIEW/diffs/$rel.diff" || true
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

printf '=== 9. RESUMO ===\n'
printf 'Workspace: %s\n' "$BASE"
printf 'Candidatos: %s\n' "$CANDIDATE"
printf 'Revisao/diffs: %s\n' "$REVIEW"
printf 'Relatorio: %s\n' "$REPORT"
printf '\n'
printf 'IMPORTANTE:\n'
printf '- producao NAO foi alterada;\n'
printf '- repositorio existente em /usr/src NAO foi alterado;\n'
printf '- nenhum git add foi executado;\n'
printf '- nenhum commit foi criado;\n'
printf '- nenhum push foi executado;\n'
printf '- index.php ficou separado para revisao porque mistura paginas/recursos.\n'
printf '\n'

if [ "$blocked" -gt 0 ]; then
  warn 'Existem referencias fora do escopo em arquivos compartilhados. Revisao obrigatoria antes de publicar.'
else
  ok 'Nenhuma referencia textual fora do escopo foi encontrada nos candidatos.'
fi

printf '\n============================================================\n'
printf '[OK] PREPARACAO CONCLUIDA — NENHUMA PUBLICACAO FOI FEITA\n'
printf '============================================================\n'
