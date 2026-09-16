#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XLX_INSTALL_STATE_FILE:-/opt/xlx-modern-installer/runtime/install-input.env}"
DASH="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
BACKUP_ROOT="/var/backups/xlx-reflector/recovery"
LOG_ROOT="/var/log/xlx-reflector/recovery"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail 'Execute como root.'
[[ -x /xlxd/xlxd ]] || fail 'XLXD existente não encontrado em /xlxd/xlxd; este recuperador é somente para instalação parcialmente concluída.'
[[ -r "$STATE" ]] || fail "Estado da instalação não encontrado: $STATE"
[[ "$(stat -c '%U' "$STATE")" == root ]] || fail 'O arquivo de estado não pertence ao root; recuperação cancelada por segurança.'

# O arquivo é gerado pelo próprio instalador com printf %q e contém a senha
# administrativa. Ele é carregado sem nunca imprimir seu conteúdo.
# shellcheck disable=SC1090
source "$STATE"
: "${DOMAIN:?DOMAIN ausente no estado da instalação}"
: "${XLX_CONTROL_USERNAME:?Usuário Admin ausente no estado da instalação}"
: "${XLX_CONTROL_PASSWORD:?Senha Admin ausente no estado da instalação}"
: "${XLX_ADMIN_SLUG:?Slug Admin ausente no estado da instalação}"

DASH_LANG='pt-BR'
if [[ -f "$DASH/config/site.php" ]] && command -v php >/dev/null 2>&1; then
  detected="$(php -r '$c=require $argv[1];echo (string)($c["locale"]["default"]??"");' "$DASH/config/site.php" 2>/dev/null || true)"
  case "$detected" in pt-BR|en|es|fr|de|it) DASH_LANG="$detected" ;; esac
fi
UI_LANG='pt-BR'
[[ "$DASH_LANG" == en ]] && UI_LANG='en'

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
LOG="$LOG_ROOT/recovery_$STAMP.log"
mkdir -p "$BACKUP" "$LOG_ROOT"
chmod 700 "$BACKUP" "$LOG_ROOT"
exec > >(tee -a "$LOG") 2>&1

repo_diff_hash(){
  git -C "$ROOT" diff --no-ext-diff --binary HEAD 2>/dev/null | sha256sum | awk '{print $1}'
}
REPO_DIFF_HASH_BEFORE="$(repo_diff_hash)"
REPO_TRACKED_STATUS_BEFORE="$(git -C "$ROOT" status --porcelain --untracked-files=no 2>/dev/null || true)"

echo '=== XLX MODERN — RECUPERAÇÃO DE INSTALAÇÃO INCOMPLETA ==='
echo "Commit: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
echo "Dashboard: $DASH"
echo "Idioma: $DASH_LANG"
echo 'Credenciais administrativas: preservadas e não exibidas.'

if [[ -d "$DASH" ]]; then
  tar -C "$(dirname "$DASH")" -czf "$BACKUP/dashboard.before.tar.gz" "$(basename "$DASH")"
  sha256sum "$BACKUP/dashboard.before.tar.gz" > "$BACKUP/dashboard.before.tar.gz.sha256"
  sha256sum -c "$BACKUP/dashboard.before.tar.gz.sha256" >/dev/null
  ok "Backup do dashboard verificado: $BACKUP/dashboard.before.tar.gz"
fi

export XLX_CONTROL_USERNAME XLX_CONTROL_PASSWORD XLX_ADMIN_SLUG

ok 'Retomando a instalação a partir do dashboard; o núcleo XLXD será preservado.'
XLX_INSTALL_STATE_FILE="$STATE" XLX_UI_LANG="$UI_LANG" \
XLX_CONTROL_USERNAME="$XLX_CONTROL_USERNAME" XLX_CONTROL_PASSWORD="$XLX_CONTROL_PASSWORD" XLX_ADMIN_SLUG="$XLX_ADMIN_SLUG" \
  bash "$ROOT/modules/60-dashboard-modern.sh" "--lang=$DASH_LANG"

ok 'Configurando Nginx + PHP-FPM.'
XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG="$UI_LANG" \
  bash "$ROOT/modules/70-nginx.sh" "--dashboard-dir=$DASH"

ok 'Provisionando APRS/D-PRS e observabilidade.'
XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG="$UI_LANG" \
  bash "$ROOT/modules/67-aprs-dprs.sh" "--dashboard-dir=$DASH"
XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG="$UI_LANG" \
  bash "$ROOT/modules/71-observability.sh" "--dashboard-dir=$DASH"

ok 'Executando paridade final.'
XLX_EXPECT_WEB_STACK=nginx XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG="$UI_LANG" \
  bash "$ROOT/dashboard/install/fresh-install-parity.sh"

for svc in xlxd.service nginx.service php8.2-fpm.service; do
  systemctl is-active --quiet "$svc" || fail "Serviço obrigatório inativo: $svc"
  ok "Serviço ativo: $svc"
done
if systemctl list-unit-files xlxecho.service --no-legend 2>/dev/null | grep -q .; then
  systemctl is-active --quiet xlxecho.service || fail 'XLX Echo instalado, porém inativo.'
  ok 'Serviço ativo: xlxecho.service'
fi
if systemctl is-active --quiet apache2.service; then
  fail 'Apache permaneceu ativo; Nginx deve ser o único servidor web.'
fi
ok 'Apache inativo, conforme arquitetura do painel.'
nginx -t

HTTP_CODE="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' -H "Host: $DOMAIN" http://127.0.0.1/ao-vivo || true)"
[[ "$HTTP_CODE" == 200 ]] || fail "Painel local via HTTP não respondeu 200 (HTTP=$HTTP_CODE)."
ok 'Painel local via HTTP respondeu 200.'

if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  HTTPS_CODE="$(curl --noproxy '*' -ksS --resolve "$DOMAIN:443:127.0.0.1" -o /dev/null -w '%{http_code}' "https://$DOMAIN/ao-vivo" || true)"
  [[ "$HTTPS_CODE" == 200 ]] || fail "Certificado existe, mas HTTPS local não respondeu 200 (HTTP=$HTTPS_CODE)."
  ok 'HTTPS local respondeu 200.'
else
  warn 'HTTPS ainda está pendente. Isso não invalida o painel HTTP quando o Let’s Encrypt estiver temporariamente limitado.'
  if systemctl is-enabled --quiet xlx-modern-https-retry.timer 2>/dev/null; then
    ok 'Timer automático de nova tentativa HTTPS está habilitado.'
  else
    warn 'Timer automático HTTPS não está habilitado; revise a etapa de certificado.'
  fi
fi

REPO_DIFF_HASH_AFTER="$(repo_diff_hash)"
REPO_TRACKED_STATUS_AFTER="$(git -C "$ROOT" status --porcelain --untracked-files=no 2>/dev/null || true)"
if [[ "$REPO_DIFF_HASH_AFTER" != "$REPO_DIFF_HASH_BEFORE" || "$REPO_TRACKED_STATUS_AFTER" != "$REPO_TRACKED_STATUS_BEFORE" ]]; then
  printf '%s\n' "$REPO_TRACKED_STATUS_AFTER" >&2
  fail 'A recuperação alterou arquivos rastreados do próprio instalador; execução interrompida para preservar a árvore Git.'
fi
ok 'A recuperação não alterou o código-fonte rastreado do instalador; alterações locais preexistentes foram preservadas.'

printf '\nRECOVERY_STATUS=OK\n'
printf 'ADMIN_ROUTE=/%s/\n' "$XLX_ADMIN_SLUG"
printf 'DASHBOARD_HTTP=http://%s/ao-vivo\n' "$DOMAIN"
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
  printf 'DASHBOARD_HTTPS=https://%s/ao-vivo\n' "$DOMAIN"
else
  printf 'DASHBOARD_HTTPS=PENDING\n'
fi
printf 'LOG=%s\n' "$LOG"
