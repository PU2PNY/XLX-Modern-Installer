#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROD="/var/www/html/xlxd-novo"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="/root/XLX026_GITHUB_SYNC_BUNDLE_${STAMP}"
ALLOWED="$OUT/allowed/dashboard"
REVIEW="$OUT/review-only/dashboard"
MANIFEST="$OUT/MANIFEST.txt"
ARCHIVE="${OUT}.tar.gz"

ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[ATENCAO] %s\n' "$*"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail 'Execute como root.'
[ -d "$PROD" ] || fail "Painel nao encontrado: $PROD"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum nao encontrado.'
command -v tar >/dev/null 2>&1 || fail 'tar nao encontrado.'
command -v php >/dev/null 2>&1 || warn 'PHP nao encontrado; validacao PHP sera ignorada.'

umask 077
mkdir -p "$ALLOWED" "$REVIEW"

allowed_files=(
  'api/live.php'
  'api/mtr.php'
  'api/ranking-v2.php'
  'api/status.php'
  'assets/ao-vivo-clean-v1.css'
  'assets/ao-vivo-compact-v3.css'
  'assets/ao-vivo-gif-anchor-v12.css'
  'assets/ao-vivo-gif-position-v9.css'
  'assets/ao-vivo-gif-scale-v8.css'
  'assets/ao-vivo-top-layout-v2.css'
  'assets/ao-vivo-tx-embed-v5.css'
  'assets/ao-vivo-tx-embed-v5.js'
  'assets/ao-vivo-tx-finetune-v6.css'
  'assets/ao-vivo-visual-fix-v7.css'
  'assets/header-neon-finetune-v1.css'
  'assets/header-unificado-v1.css'
  'assets/header-unificado-v1.js'
  'assets/history-mobile-fit-v2.css'
  'assets/mobile-menu-v4.css'
  'assets/mtr.js'
  'assets/table-row-hover-v1.css'
  'ranking-v2-view.php'
)

review_files=(
  'api/common.php'
  'assets/app.css'
  'assets/app.js'
  'index.php'
)

printf '============================================================\n'
printf ' XLX026 — EXPORTAR PACOTE PARA SINCRONIZACAO GITHUB\n'
printf ' PRODUCAO SOMENTE LEITURA\n'
printf '============================================================\n\n'

printf '=== 1. COPIANDO ARQUIVOS LIBERADOS ===\n'
for rel in "${allowed_files[@]}"; do
  src="$PROD/$rel"
  [ -f "$src" ] || fail "Arquivo liberado ausente: $src"
  mkdir -p "$ALLOWED/$(dirname "$rel")"
  cp -a "$src" "$ALLOWED/$rel"
done
ok "${#allowed_files[@]} arquivos liberados copiados."
printf '\n'

printf '=== 2. COPIANDO ARQUIVOS BLOQUEADOS SOMENTE PARA REVISAO ===\n'
for rel in "${review_files[@]}"; do
  src="$PROD/$rel"
  [ -f "$src" ] || fail "Arquivo de revisao ausente: $src"
  mkdir -p "$REVIEW/$(dirname "$rel")"
  cp -a "$src" "$REVIEW/$rel"
done
ok "${#review_files[@]} arquivos separados em review-only."
printf '\n'

printf '=== 3. VALIDANDO ESCOPO DOS LIBERADOS ===\n'
forbidden='certificado|diploma|ham-news|ham-weather|reflectors|refletores|support-native'
if grep -RniEI "$forbidden" "$ALLOWED" > "$OUT/forbidden-allowed.txt" 2>/dev/null; then
  cat "$OUT/forbidden-allowed.txt"
  fail 'Referencia fora do escopo encontrada nos arquivos liberados. Pacote nao sera criado.'
fi
ok 'Nenhuma referencia textual proibida nos arquivos liberados.'
printf '\n'

printf '=== 4. VALIDANDO PHP DOS ARQUIVOS LIBERADOS ===\n'
if command -v php >/dev/null 2>&1; then
  while IFS= read -r file; do
    php -l "$file" >/dev/null || fail "Falha de sintaxe PHP: $file"
  done < <(find "$ALLOWED" -type f -name '*.php' | sort)
  ok 'Sintaxe PHP dos liberados validada.'
else
  warn 'Validacao PHP ignorada porque php nao esta instalado.'
fi
printf '\n'

printf '=== 5. GERANDO MANIFESTO E HASHES ===\n'
{
  printf 'XLX026 GitHub selective sync bundle\n'
  printf 'Created: %s\n\n' "$(date -Is)"
  printf '[ALLOWED]\n'
  for rel in "${allowed_files[@]}"; do
    sha256sum "$ALLOWED/$rel"
  done
  printf '\n[REVIEW-ONLY]\n'
  for rel in "${review_files[@]}"; do
    sha256sum "$REVIEW/$rel"
  done
} > "$MANIFEST"
ok "Manifesto criado: $MANIFEST"
printf '\n'

printf '=== 6. GARANTINDO AUSENCIA DE CERTIFICADOS NO BLOCO LIBERADO ===\n'
if find "$ALLOWED" -type f \( -iname '*certif*' -o -iname '*diploma*' -o -iname '*qrcode*' -o -iname '*qr-code*' \) -print -quit | grep -q .; then
  fail 'Arquivo de certificado/diploma encontrado em allowed.'
fi
ok 'Nenhum certificado/diploma em allowed.'
printf '\n'

printf '=== 7. CRIANDO PACOTE ===\n'
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"
chmod 600 "$ARCHIVE"
ARCHIVE_SHA="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
ok "Pacote criado: $ARCHIVE"
printf 'SHA256: %s\n' "$ARCHIVE_SHA"
printf '\n'

printf '=== 8. RESUMO ===\n'
printf 'Arquivos liberados: %d\n' "${#allowed_files[@]}"
printf 'Arquivos somente revisao: %d\n' "${#review_files[@]}"
printf 'Pacote: %s\n' "$ARCHIVE"
printf 'Manifesto: %s\n' "$MANIFEST"
printf '\n'
printf '%s\n' '- Nenhum arquivo de producao foi alterado.'
printf '%s\n' '- Nenhum commit foi criado.'
printf '%s\n' '- Nenhum push foi executado.'
printf '%s\n' '- Certificados nao foram incluidos em allowed.'
printf '%s\n' '- api/common.php, app.css, app.js e index.php ficaram somente em review-only.'
printf '\n============================================================\n'
printf '[OK] PACOTE PRONTO PARA REVISAO E SINCRONIZACAO\n'
printf '============================================================\n'
