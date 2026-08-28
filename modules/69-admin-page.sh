#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlx-dashboard}}"
CFG_DIR="/etc/xlx-modern-control"
ROUTE_FILE="$CFG_DIR/route"
CONTROL_CFG="$CFG_DIR/config.php"
LEGACY_DIR="$DASHBOARD_DIR/controle"
BACKUP_ROOT="/var/backups/xlx-reflector/admin"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

say(){ if [[ "$UI_LANG" == "en" ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
[[ -d "$DASHBOARD_DIR" ]] || fail "$(say "Dashboard ausente: $DASHBOARD_DIR" "Dashboard not found: $DASHBOARD_DIR")"
[[ -f "$DASHBOARD_DIR/index.php" ]] || fail "$(say 'index.php do dashboard ausente.' 'Dashboard index.php not found.')"
[[ -f "$ROOT/modules/68-control-panel.sh" ]] || fail "$(say 'Módulo administrativo base ausente.' 'Base admin module not found.')"

# The hardened base control uses sudo/visudo only for a fixed allowlist helper.
# A minimal Debian installation may not have sudo yet, so install it here when
# the Admin component is being created for the first time.
if [[ ! -f "$CONTROL_CFG" ]] && { ! command -v sudo >/dev/null 2>&1 || ! command -v visudo >/dev/null 2>&1; }; then
  command -v apt-get >/dev/null 2>&1 || fail "$(say 'sudo/visudo ausentes e apt-get indisponível.' 'sudo/visudo missing and apt-get unavailable.')"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y sudo
fi

reserved='^(ao-vivo|conectados|ranking|refletores|assets|api|config|flags|install|controle|certificado|digital-lab|aprs|aprs-dprs)$'
validate_slug(){
  local value="$1"
  [[ "$value" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || return 1
  [[ ! "$value" =~ $reserved ]] || return 1
}

slug="${XLX_ADMIN_SLUG:-}"
existing_slug=""
[[ -s "$ROUTE_FILE" ]] && existing_slug="$(tr -d '\r\n' < "$ROUTE_FILE")"

if [[ -z "$slug" && -n "$existing_slug" ]]; then
  slug="$existing_slug"
  printf '%s: %s [reaproveitado]\n' "$(say 'Página administrativa' 'Administrative page')" "$slug"
fi

if [[ -z "$slug" ]]; then
  if [[ -t 0 ]]; then
    while :; do
      printf '%s' "$(say 'Nome da página administrativa [admin]: ' 'Administrative page name [admin]: ')"
      read -r slug || slug=""
      slug="${slug:-admin}"
      slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
      if validate_slug "$slug"; then break; fi
      warn "$(say 'Use 2-32 caracteres: letras minúsculas, números e hífen; escolha outro nome.' 'Use 2-32 characters: lowercase letters, numbers and hyphen; choose another name.')"
    done
  elif [[ -n "${XLX_CONTROL_USERNAME:-}" && -n "${XLX_CONTROL_PASSWORD:-}" ]]; then
    slug="admin"
  else
    warn "$(say 'Instalação não interativa sem credenciais administrativas; página Admin não foi criada.' 'Non-interactive install without admin credentials; Admin page was not created.')"
    exit 0
  fi
fi

validate_slug "$slug" || fail "$(say "Nome de página administrativa inválido: $slug" "Invalid administrative page name: $slug")"
ADMIN_DIR="$DASHBOARD_DIR/$slug"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"

[[ -f "$DASHBOARD_DIR/index.php" ]] && cp -a "$DASHBOARD_DIR/index.php" "$BACKUP/index.php.before"
[[ -d "$ADMIN_DIR" ]] && tar -C "$DASHBOARD_DIR" -czf "$BACKUP/admin-dir.before.tar.gz" "$slug"
[[ -d "$LEGACY_DIR" && "$LEGACY_DIR" != "$ADMIN_DIR" ]] && tar -C "$DASHBOARD_DIR" -czf "$BACKUP/controle.before.tar.gz" controle
[[ -d "$CFG_DIR" ]] && tar -C / -czf "$BACKUP/config.before.tar.gz" "${CFG_DIR#/}"

# First installation: reuse the hardened control module to ask for username and
# password, generate password_hash(), install rate limiting, CSRF, audit log,
# restricted sudo helper and rollback support.
if [[ ! -f "$CONTROL_CFG" ]]; then
  XLX_DASHBOARD_DIR="$DASHBOARD_DIR" bash "$ROOT/modules/68-control-panel.sh" --dashboard-dir="$DASHBOARD_DIR"
fi

[[ -f "$CONTROL_CFG" ]] || fail "$(say 'Configuração administrativa não foi criada.' 'Administrative configuration was not created.')"
[[ -f "$ROOT/control/index.php" ]] || fail "$(say 'Fonte da página administrativa ausente.' 'Administrative page source not found.')"

# Always publish the newest source. The legacy module uses /controle/ internally;
# patch only the route literals in the deployed copy, never the repository source.
rm -rf "$ADMIN_DIR"
install -d -o root -g www-data -m 0755 "$ADMIN_DIR"
sed "s#/controle/#/$slug/#g" "$ROOT/control/index.php" > "$ADMIN_DIR/index.php"
chown root:www-data "$ADMIN_DIR/index.php"
chmod 0644 "$ADMIN_DIR/index.php"
php -l "$ADMIN_DIR/index.php" >/dev/null

if [[ "$LEGACY_DIR" != "$ADMIN_DIR" ]]; then
  rm -rf "$LEGACY_DIR"
fi

install -d -o root -g www-data -m 0750 "$CFG_DIR"
printf '%s\n' "$slug" > "$ROUTE_FILE"
chown root:root "$ROUTE_FILE"
chmod 0600 "$ROUTE_FILE"

SITE_CFG="$DASHBOARD_DIR/config/site.php"
REFLECTOR_NAME="XLX Modern"
if [[ -f "$SITE_CFG" ]]; then
  REFLECTOR_NAME="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["name"]??"XLX Modern");' "$SITE_CFG")"
fi

# Keep the private control tests aligned with the public installer routes.
php -r '
$f=$argv[1];$slug=$argv[2];$reflector=$argv[3];$c=require $f;
$c["title"]="Admin ".$reflector;
$c["admin_slug"]=$slug;
$c["test_paths"]=[
 ["/ao-vivo",200,"html"],
 ["/conectados",200,"html"],
 ["/ranking",200,"html"],
 ["/refletores",200,"html"],
 ["/api/status.php",200,"json"],
 ["/api/live.php",200,"json"],
 ["/api/mtr.php",400,"json"],
];
file_put_contents($f,"<?php\ndeclare(strict_types=1);\nreturn ".var_export($c,true).";\n");
' "$CONTROL_CFG" "$slug" "$REFLECTOR_NAME"
chown root:www-data "$CONTROL_CFG"
chmod 0640 "$CONTROL_CFG"
php -l "$CONTROL_CFG" >/dev/null

# Insert one Admin link in the public navigation. The marker allows idempotent
# reinstallation after dashboard rsync --delete.
php -r '
$f=$argv[1];$slug=$argv[2];
$s=file_get_contents($f); if($s===false) exit(2);
$s=preg_replace("~\\n?<!-- XLX_MODERN_ADMIN_NAV_START -->.*?<!-- XLX_MODERN_ADMIN_NAV_END -->\\n?~s","\n",$s);
$needle="  <a href=\"#acessibilidade\" class=\"xlx-a11y-menu-icon\"";
$block="  <!-- XLX_MODERN_ADMIN_NAV_START -->\n  <a class=\"xlx-admin-menu-link\" href=\"/".$slug."/\" rel=\"nofollow\">Admin</a>\n  <!-- XLX_MODERN_ADMIN_NAV_END -->\n";
if(strpos($s,$needle)===false) exit(3);
$s=str_replace($needle,$block.$needle,$s,$count);
if($count!==1) exit(4);
file_put_contents($f,$s);
' "$DASHBOARD_DIR/index.php" "$slug" || fail "$(say 'Falha ao integrar Admin ao menu.' 'Failed to integrate Admin into the menu.')"
php -l "$DASHBOARD_DIR/index.php" >/dev/null

# Validation: route, auth config and menu must all agree.
grep -Fq "href=\"/$slug/\"" "$DASHBOARD_DIR/index.php" || fail "$(say 'Link Admin não encontrado no menu.' 'Admin menu link not found.')"
php -r '$c=require $argv[1]; $i=password_get_info((string)($c["password_hash"]??"")); exit((!empty($c["username"])&&!empty($c["password_hash"])&&!empty($i["algoName"])&&$i["algoName"]!=="unknown")?0:1);' "$CONTROL_CFG" || fail "$(say 'Credencial administrativa inválida.' 'Invalid administrative credential.')"

ok "$(say "Página administrativa pronta: /$slug/" "Administrative page ready: /$slug/")"
ok "$(say 'Usuário e senha protegidos; senha armazenada somente como hash.' 'Username/password protected; password stored only as a hash.')"
echo "ADMIN_ROUTE=/$slug/"
echo "ADMIN_STATUS=OK"
