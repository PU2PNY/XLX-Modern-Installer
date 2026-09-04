#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DEST="${INSTALL_DIR:-/var/www/html/xlxd}"
CERT_MODE="${XLX_CERTIFICATES_MODE:-no}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

say() {
  if [ "$UI_LANG" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}
fail() {
  printf '%s\n' "$(say "[ERRO] $1" "[ERROR] $2")" >&2
  exit 1
}

# Runtime data is intentionally independent from every dashboard implementation.
# This repairs/installs the callsign database, its daily timer and the
# TX/RX journal bridge before publishing the dashboard itself.
bash "$ROOT/modules/64-runtime-data.sh"

bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"

# Reinstall/validate CallingHome through the standalone implementation. This
# intentionally replaces any dashboard-coupled or legacy per-reflector timer.
INSTALL_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/63-callinghome.sh" --dashboard-dir="$DASH_DEST"

INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/post-install.sh"
bash "$ROOT/modules/65-callsign-directory.sh"

# Private administrative page. On a fresh interactive installation this asks:
# - route name (default: admin)
# - username
# - password + confirmation
# Existing installations reuse the protected credential and route.
XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/modules/69-admin-page.sh" --dashboard-dir="$DASH_DEST"

case "${CERT_MODE,,}" in
  yes|sim|s|y|1|true)
    CERT_MODE="yes"
    ;;
  no|nao|não|n|0|false|"")
    CERT_MODE="no"
    ;;
  ask)
    if [ -t 0 ]; then
      printf '\n%s' "$(say "Instalar também o módulo opcional de Certificados? [s/N]: " "Install the optional Certificate module too? [y/N]: ")"
      read -r answer || answer=""
      case "${answer,,}" in
        s|sim|y|yes) CERT_MODE="yes" ;;
        *) CERT_MODE="no" ;;
      esac
    else
      CERT_MODE="no"
    fi
    ;;
  *)
    fail "XLX_CERTIFICATES_MODE inválido: $CERT_MODE. Use ask, yes ou no." "Invalid XLX_CERTIFICATES_MODE: $CERT_MODE. Use ask, yes, or no."
    ;;
esac

if [ "$CERT_MODE" = "yes" ]; then
  printf '%s\n' "$(say "[INFO] Instalando o módulo opcional XLX Certificate Generator." "[INFO] Installing the optional XLX Certificate Generator module.")"
  XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/modules/66-certificates.sh" "--dashboard-dir=$DASH_DEST"
else
  printf '%s\n' "$(say "[INFO] Certificados não fazem parte da instalação pública padrão." "[INFO] Certificates are not part of the standard public installation.")"
fi

# Final Modern-layer validation. The independent core installer owns XLXD;
# this section proves every Modern runtime component before returning success.
printf '\n%s\n' "$(say '[INFO] Validando a camada moderna completa.' '[INFO] Validating the complete Modern layer.')"

for required in \
  "$DASH_DEST/index.php" \
  "$DASH_DEST/config/site.php" \
  "$DASH_DEST/api/status.php" \
  "$DASH_DEST/api/live.php" \
  /xlxd/users_db/users.db \
  /usr/local/sbin/xlx-modern-users-refresh \
  /usr/local/sbin/xlx-modern-log-bridge \
  /usr/local/sbin/xlx-modern-callinghome \
  /usr/local/lib/xlx-modern/xlx-callinghome.php \
  /etc/xlx-modern/callinghome.php \
  /etc/systemd/system/xlx-callinghome.service \
  /etc/systemd/system/xlx-callinghome.timer \
  /var/lib/xlx-modern-callinghome/last-success \
  /etc/systemd/system/update_XLX_db.timer \
  /etc/systemd/system/xlx_log.service
 do
  [ -s "$required" ] || fail "Componente obrigatório ausente: $required" "Required component missing: $required"
 done

systemctl is-active --quiet xlxd.service || fail 'xlxd.service não está ativo.' 'xlxd.service is not active.'
systemctl is-active --quiet apache2.service || fail 'apache2.service não está ativo.' 'apache2.service is not active.'
systemctl is-active --quiet xlx-callinghome.timer || fail 'xlx-callinghome.timer não está ativo.' 'xlx-callinghome.timer is not active.'
systemctl is-active --quiet update_XLX_db.timer || fail 'update_XLX_db.timer não está ativo.' 'update_XLX_db.timer is not active.'
systemctl is-active --quiet xlx_log.service || fail 'xlx_log.service não está ativo.' 'xlx_log.service is not active.'

if grep -Fq '/var/www/html' /usr/local/sbin/xlx-modern-callinghome /usr/local/lib/xlx-modern/xlx-callinghome.php; then
  fail 'CallingHome ainda depende do painel.' 'CallingHome still depends on the dashboard.'
fi

command -v sqlite3 >/dev/null 2>&1 || fail 'sqlite3 não encontrado.' 'sqlite3 was not found.'
DB_INTEGRITY="$(sqlite3 /xlxd/users_db/users.db 'PRAGMA integrity_check;' 2>/dev/null || true)"
[ "$DB_INTEGRITY" = ok ] || fail 'users.db falhou na verificação de integridade.' 'users.db failed its integrity check.'
DB_ROWS="$(sqlite3 /xlxd/users_db/users.db 'SELECT COUNT(*) FROM users;' 2>/dev/null || echo 0)"
[[ "$DB_ROWS" =~ ^[0-9]+$ ]] || DB_ROWS=0
[ "$DB_ROWS" -ge 1000 ] || fail "users.db possui poucos registros: $DB_ROWS" "users.db has too few records: $DB_ROWS"

MODULE_COUNT="$(php -r '$c=require $argv[1];echo (string)($c["radio"]["module_count"]??"");' "$DASH_DEST/config/site.php" 2>/dev/null || true)"
[[ "$MODULE_COUNT" =~ ^[0-9]+$ ]] || fail 'Quantidade de módulos não foi persistida no painel.' 'Module count was not persisted in the dashboard.'
[ "$MODULE_COUNT" -ge 1 ] && [ "$MODULE_COUNT" -le 26 ] || fail "Quantidade de módulos inválida: $MODULE_COUNT" "Invalid module count: $MODULE_COUNT"

[ -s /etc/xlx-modern-control/route ] || fail 'Rota privada do Admin não foi registrada.' 'Private Admin route was not recorded.'
ADMIN_SLUG="$(tr -d '\r\n' < /etc/xlx-modern-control/route)"
[[ "$ADMIN_SLUG" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || fail 'Slug do Admin é inválido.' 'Admin slug is invalid.'
[ -s "$DASH_DEST/$ADMIN_SLUG/index.php" ] || fail 'Tela privada do Admin está ausente.' 'Private Admin page is missing.'
[ -s /usr/local/sbin/xlx-modern-control-helper ] || fail 'Helper do Admin está ausente.' 'Admin helper is missing.'
[ -s /usr/local/sbin/xlx-modern-access-helper ] || fail 'Helper de acesso/Interlink está ausente.' 'Access/Interlink helper is missing.'
[ -s /usr/local/sbin/xlx-modern-radioid-helper ] || fail 'Helper RadioID está ausente.' 'RadioID helper is missing.'
[ -s /etc/sudoers.d/xlx-modern-control ] || fail 'sudoers restrito do Admin está ausente.' 'Restricted Admin sudoers file is missing.'
visudo -cf /etc/sudoers.d/xlx-modern-control >/dev/null || fail 'sudoers do Admin é inválido.' 'Admin sudoers file is invalid.'

grep -Fq '/var/www/html/xlxd-novo' "$DASH_DEST/config/site.php" && fail 'Caminho xlxd-novo reapareceu na configuração do painel.' 'xlxd-novo path reappeared in dashboard configuration.' || true

printf '%s\n' "$(say "[OK] Camada moderna validada: painel=$DASH_DEST, módulos=$MODULE_COUNT, RadioID=$DB_ROWS registros, Admin=/$ADMIN_SLUG/, CallingHome=independente." "[OK] Modern layer validated: dashboard=$DASH_DEST, modules=$MODULE_COUNT, RadioID=$DB_ROWS records, Admin=/$ADMIN_SLUG/, CallingHome=independent.")"
echo 'MODERN_DASHBOARD_STATUS=OK'
echo "MODERN_DASHBOARD_DIR=$DASH_DEST"
echo "MODERN_ADMIN_ROUTE=/$ADMIN_SLUG/"
echo "MODERN_USERS_DB_ROWS=$DB_ROWS"
echo "MODERN_MODULE_COUNT=$MODULE_COUNT"
echo 'MODERN_CALLINGHOME=INDEPENDENT'
