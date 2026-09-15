#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
STATE="${XLX_INSTALL_STATE_FILE:-/opt/xlx-modern-installer/runtime/install-input.env}"
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail 'Execute como root: sudo bash scripts/resume-incomplete-install.sh'
[[ -x /xlxd/xlxd ]] || fail 'XLXD existente não encontrado em /xlxd/xlxd.'
systemctl is-active --quiet xlxd || fail 'O serviço xlxd não está ativo; o reparo foi interrompido sem reiniciar o refletor.'
[[ -s "$STATE" ]] || fail "Estado da instalação não encontrado: $STATE"
# shellcheck disable=SC1090
source "$STATE"
export XLX_CONTROL_USERNAME="${XLX_CONTROL_USERNAME:-}"
export XLX_CONTROL_PASSWORD="${XLX_CONTROL_PASSWORD:-}"
export XLX_ADMIN_SLUG="${XLX_ADMIN_SLUG:-admin}"

LANG_CODE="pt-BR"
if [[ -s "$DASH/config/site.php" ]]; then
  detected="$(php -r '$s=require $argv[1]; echo (string)($s["locale"]["default"]??"");' "$DASH/config/site.php" 2>/dev/null || true)"
  case "$detected" in pt-BR|en|es|fr|de|it) LANG_CODE="$detected" ;; esac
fi
printf '[INFO] Idioma preservado / Preserved language: %s\n' "$LANG_CODE"
printf '[INFO] XLXD será preservado; nenhuma reinstalação do núcleo será executada.\n'

XLX_INSTALL_STATE_FILE="$STATE" XLX_UI_LANG=pt-BR \
  XLX_CONTROL_USERNAME="$XLX_CONTROL_USERNAME" \
  XLX_CONTROL_PASSWORD="$XLX_CONTROL_PASSWORD" \
  XLX_ADMIN_SLUG="$XLX_ADMIN_SLUG" \
  INSTALL_DIR="$DASH" \
  bash "$ROOT/modules/60-dashboard-modern.sh" "--lang=$LANG_CODE"
ok 'Dashboard, Admin e Certificado concluídos.'

XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG=pt-BR \
  bash "$ROOT/modules/70-nginx.sh" "--dashboard-dir=$DASH"
ok 'Nginx + PHP-FPM ativados; Apache retirado da borda web.'

XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG=pt-BR \
  bash "$ROOT/modules/67-aprs-dprs.sh" "--dashboard-dir=$DASH"
ok 'APRS/D-PRS concluído.'

XLX_DASHBOARD_DIR="$DASH" XLX_UI_LANG=pt-BR \
  bash "$ROOT/modules/71-observability.sh" "--dashboard-dir=$DASH"
ok 'Observabilidade concluída.'

bash "$ROOT/modules/95-validate.sh" read-only

DOMAIN="$(php -r '$s=require $argv[1]; echo strtolower((string)($s["reflector"]["domain"]??""));' "$DASH/config/site.php")"
[[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || fail 'Domínio inválido no site.php após reparo.'
SCHEME=http; PORT=80
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then SCHEME=https; PORT=443; fi
for endpoint in / /api/status.php /api/live.php '/?page=digital-lab' '/?page=certificado'; do
  curl --noproxy '*' -kfsS --max-time 20 --resolve "$DOMAIN:$PORT:127.0.0.1" "$SCHEME://$DOMAIN$endpoint" >/dev/null \
    || fail "Falha na validação HTTP final: $endpoint"
done
ok "Reparo concluído. Painel validado em $SCHEME://$DOMAIN"
