#!/usr/bin/env bash
set -Eeuo pipefail
# XLX_ERROR_TRACE_V1 — never return silently to the shell on an unexpected failure.
_xlx_error_trace(){
  local rc=$?
  printf '\n[ERROR] file=%s line=%s rc=%s command=%q\n' \
    "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" \
    "${BASH_LINENO[0]:-$LINENO}" "$rc" "$BASH_COMMAND" >&2
  return "$rc"
}
trap _xlx_error_trace ERR
IFS=$'\n\t'; umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
MODE=install
UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ [[ "$UI_LANG" == en ]] && printf '%s' "$2" || printf '%s' "$1"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }
for a in "$@"; do case "$a" in --check|--dry-run) MODE=check;; --dashboard-dir=*) DASHBOARD="${a#*=}";; *) fail "$(say "Opção desconhecida: $a" "Unknown option: $a")";; esac; done
[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
required=(
  "$ROOT/dashboard/certificado-view.php"
  "$ROOT/dashboard/certificado-config.php"
  "$ROOT/dashboard/api/certificado.php"
  "$ROOT/dashboard/assets/certificado.css"
  "$ROOT/dashboard/assets/certificado.js"
  "$ROOT/dashboard/assets/vendor/qrcode.min.js"
  "$ROOT/dashboard/assets/vendor/qrcodejs-LICENSE"
)
for f in "${required[@]}"; do [[ -s "$f" ]] || fail "$(say "Arquivo nativo ausente: $f" "Native file missing: $f")"; done
php -l "$ROOT/dashboard/certificado-view.php" >/dev/null
php -l "$ROOT/dashboard/certificado-config.php" >/dev/null
php -l "$ROOT/dashboard/api/certificado.php" >/dev/null
if command -v node >/dev/null 2>&1; then node --check "$ROOT/dashboard/assets/certificado.js" >/dev/null; fi
if [[ "$MODE" == check ]]; then
  ok "$(say 'Certificados nativos validados; nenhuma alteração feita.' 'Native Certificates validated; no changes made.')"
  exit 0
fi
[[ -f "$DASHBOARD/index.php" && -f "$DASHBOARD/api/certificado.php" && -f "$DASHBOARD/certificado-view.php" ]] || fail "$(say 'Certificados não vieram integrados ao dashboard.' 'Certificates were not integrated into the dashboard.')"
grep -Fq "'certificado'" "$DASHBOARD/index.php" || fail "$(say 'Rota nativa de Certificados ausente.' 'Native Certificate route is missing.')"
grep -Fq "qrcode.min.js" "$DASHBOARD/index.php" || fail "$(say 'QR Code nativo não está carregado.' 'Native QR Code library is not loaded.')"
install -d -o www-data -g www-data -m 0750 /var/lib/xlx-certificates
install -d -o root -g www-data -m 0750 /etc/xlx-certificates
secret=/etc/xlx-certificates/secret
if [[ ! -s "$secret" ]]; then
  tmp="$(mktemp /etc/xlx-certificates/.secret.XXXXXX)"
  python3 - <<'PY' > "$tmp"
import secrets
print(secrets.token_urlsafe(48))
PY
  chown root:www-data "$tmp"; chmod 0640 "$tmp"; mv -f "$tmp" "$secret"
fi
chown root:www-data "$secret"; chmod 0640 "$secret"
runuser -u www-data -- test -r "$secret" || fail "$(say 'Apache não consegue ler o segredo HMAC.' 'Apache cannot read the HMAC secret.')"
php -l "$DASHBOARD/api/certificado.php" >/dev/null
ok "$(say 'Certificados nativos prontos: emissão, QR e validação HMAC.' 'Native Certificates ready: issuance, QR, and HMAC validation.')"
