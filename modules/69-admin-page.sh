#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlx-dashboard}}"
CFG_DIR="/etc/xlx-modern-control"
ROUTE_FILE="$CFG_DIR/route"
CONTROL_CFG="$CFG_DIR/config.php"
HELPER_CONF="$CFG_DIR/helper.conf"
LEGACY_DIR="$DASHBOARD_DIR/controle"
HELPER="/usr/local/sbin/xlx-modern-control-helper"
RADIO_HELPER="/usr/local/sbin/xlx-modern-radioid-helper"
ACCESS_HELPER="/usr/local/sbin/xlx-modern-access-helper"
SUDOERS="/etc/sudoers.d/xlx-modern-control"
BACKUP_ROOT="/var/backups/xlx-reflector/admin"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
WEBUSER="www-data"

say(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
[[ -d "$DASHBOARD_DIR" ]] || fail "$(say "Dashboard ausente: $DASHBOARD_DIR" "Dashboard not found: $DASHBOARD_DIR")"
[[ -f "$DASHBOARD_DIR/index.php" ]] || fail "$(say 'index.php do dashboard ausente.' 'Dashboard index.php not found.')"
for file in \
  "$ROOT/modules/68-control-panel.sh" \
  "$ROOT/control/xlx026-control-index-radioid-v2.php" \
  "$ROOT/control/patch-xlx026-control-v111.py" \
  "$ROOT/control/genericize-xlx-control.py" \
  "$ROOT/control/xlx-modern-control-helper" \
  "$ROOT/control/xlx-modern-radioid-helper" \
  "$ROOT/control/xlx-modern-access-helper"
do
  [[ -f "$file" ]] || fail "$(say "Componente administrativo ausente: $file" "Admin component missing: $file")"
done

if ! command -v sudo >/dev/null 2>&1 || ! command -v visudo >/dev/null 2>&1; then
  command -v apt-get >/dev/null 2>&1 || fail "$(say 'sudo/visudo ausentes e apt-get indisponível.' 'sudo/visudo missing and apt-get unavailable.')"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y sudo
fi
for command_name in bash grep install php python3 sudo visudo tar sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$(say "Comando ausente: $command_name" "Missing command: $command_name")"
done

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
  printf '%s: %s [reaproveitado]\n' "$(say 'Página administrativa oculta' 'Hidden administrative page')" "$slug"
fi

if [[ -z "$slug" ]]; then
  if [[ -t 0 ]]; then
    while :; do
      printf '%s' "$(say 'Nome da página administrativa oculta [admin]: ' 'Hidden administrative page name [admin]: ')"
      read -r slug || slug=''
      slug="${slug:-admin}"
      slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
      if validate_slug "$slug"; then break; fi
      warn "$(say 'Use 2-32 caracteres: letras minúsculas, números e hífen; escolha outro nome.' 'Use 2-32 characters: lowercase letters, numbers and hyphen; choose another name.')"
    done
  elif [[ -n "${XLX_CONTROL_USERNAME:-}" && -n "${XLX_CONTROL_PASSWORD:-}" ]]; then
    slug='admin'
  else
    warn "$(say 'Instalação não interativa sem credenciais administrativas; Admin não foi criado.' 'Non-interactive install without admin credentials; Admin was not created.')"
    exit 0
  fi
fi
validate_slug "$slug" || fail "$(say "Nome de página administrativa inválido: $slug" "Invalid administrative page name: $slug")"
ADMIN_DIR="$DASHBOARD_DIR/$slug"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
WORK="$(mktemp -d /tmp/xlx-modern-admin.XXXXXX)"
MUTATED=0
SUCCESS=0
mkdir -p "$BACKUP"; chmod 700 "$BACKUP"

cleanup(){ rm -rf "$WORK"; }
rollback(){
  local rc="${1:-90}"
  trap - EXIT
  set +e
  warn "$(say 'Falha detectada; restaurando Admin anterior.' 'Failure detected; restoring previous Admin.')"
  rm -rf "$ADMIN_DIR" "$LEGACY_DIR"
  [[ -f "$BACKUP/admin-dir.before.tar.gz" ]] && tar -C "$DASHBOARD_DIR" -xzf "$BACKUP/admin-dir.before.tar.gz"
  [[ -f "$BACKUP/controle.before.tar.gz" ]] && tar -C "$DASHBOARD_DIR" -xzf "$BACKUP/controle.before.tar.gz"
  [[ -f "$BACKUP/index.php.before" ]] && cp -a "$BACKUP/index.php.before" "$DASHBOARD_DIR/index.php"
  [[ -f "$BACKUP/config.before.tar.gz" ]] && { rm -rf "$CFG_DIR"; tar -C / -xzf "$BACKUP/config.before.tar.gz"; }
  [[ -f "$BACKUP/helper.before" ]] && cp -a "$BACKUP/helper.before" "$HELPER"
  [[ -f "$BACKUP/radio-helper.before" ]] && cp -a "$BACKUP/radio-helper.before" "$RADIO_HELPER"
  [[ -f "$BACKUP/access-helper.before" ]] && cp -a "$BACKUP/access-helper.before" "$ACCESS_HELPER"
  [[ -f "$BACKUP/sudoers.before" ]] && cp -a "$BACKUP/sudoers.before" "$SUDOERS"
  [[ -f "$SUDOERS" ]] && visudo -cf "$SUDOERS" >/dev/null 2>&1 || true
  cleanup
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "$rc"; else cleanup; fi' EXIT

cp -a "$DASHBOARD_DIR/index.php" "$BACKUP/index.php.before"
[[ -d "$ADMIN_DIR" ]] && tar -C "$DASHBOARD_DIR" -czf "$BACKUP/admin-dir.before.tar.gz" "$slug"
[[ -d "$LEGACY_DIR" && "$LEGACY_DIR" != "$ADMIN_DIR" ]] && tar -C "$DASHBOARD_DIR" -czf "$BACKUP/controle.before.tar.gz" controle
[[ -d "$CFG_DIR" ]] && tar -C / -czf "$BACKUP/config.before.tar.gz" "${CFG_DIR#/}"
[[ -f "$HELPER" ]] && cp -a "$HELPER" "$BACKUP/helper.before"
[[ -f "$RADIO_HELPER" ]] && cp -a "$RADIO_HELPER" "$BACKUP/radio-helper.before"
[[ -f "$ACCESS_HELPER" ]] && cp -a "$ACCESS_HELPER" "$BACKUP/access-helper.before"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACKUP/sudoers.before"
ok "$(say "Backup: $BACKUP" "Backup: $BACKUP")"

# First install still owns credential creation and the strict base configuration.
if [[ ! -f "$CONTROL_CFG" ]]; then
  XLX_DASHBOARD_DIR="$DASHBOARD_DIR" bash "$ROOT/modules/68-control-panel.sh" --dashboard-dir="$DASHBOARD_DIR"
fi
[[ -f "$CONTROL_CFG" && -f "$HELPER_CONF" ]] || fail "$(say 'Configuração administrativa não foi criada.' 'Administrative configuration was not created.')"

MUTATED=1

# Existing installations are upgraded without asking for the password again.
install -o root -g root -m 0755 "$ROOT/control/xlx-modern-control-helper" "$HELPER"
install -o root -g root -m 0755 "$ROOT/control/xlx-modern-radioid-helper" "$RADIO_HELPER"
install -o root -g root -m 0755 "$ROOT/control/xlx-modern-access-helper" "$ACCESS_HELPER"
bash -n "$HELPER" "$RADIO_HELPER" "$ACCESS_HELPER"

cat > "$SUDOERS" <<EOF
$WEBUSER ALL=(root) NOPASSWD: $HELPER status
$WEBUSER ALL=(root) NOPASSWD: $HELPER listeners
$WEBUSER ALL=(root) NOPASSWD: $HELPER logs
$WEBUSER ALL=(root) NOPASSWD: $HELPER backups
$WEBUSER ALL=(root) NOPASSWD: $HELPER restart
$WEBUSER ALL=(root) NOPASSWD: $HELPER radioid-status
$WEBUSER ALL=(root) NOPASSWD: $HELPER radioid-check
$WEBUSER ALL=(root) NOPASSWD: $HELPER radioid-refresh
$WEBUSER ALL=(root) NOPASSWD: $HELPER radioid-search *
$WEBUSER ALL=(root) NOPASSWD: $HELPER radioid-save *
$WEBUSER ALL=(root) NOPASSWD: $HELPER radioid-delete *
$WEBUSER ALL=(root) NOPASSWD: $HELPER access-status
$WEBUSER ALL=(root) NOPASSWD: $HELPER access-add-white *
$WEBUSER ALL=(root) NOPASSWD: $HELPER access-delete-white *
$WEBUSER ALL=(root) NOPASSWD: $HELPER access-add-black *
$WEBUSER ALL=(root) NOPASSWD: $HELPER access-delete-black *
$WEBUSER ALL=(root) NOPASSWD: $HELPER access-save-terminal *
EOF
chmod 0440 "$SUDOERS"
visudo -cf "$SUDOERS" >/dev/null

# Build from the audited XLX026 control baseline, then remove every production-
# specific identity/path and add the generic access/quick-links layer.
cp -a "$ROOT/control/xlx026-control-index-radioid-v2.php" "$WORK/index.php"
python3 "$ROOT/control/patch-xlx026-control-v111.py" "$WORK/index.php"
python3 "$ROOT/control/genericize-xlx-control.py" "$WORK/index.php"
php -l "$WORK/index.php" >/dev/null

rm -rf "$ADMIN_DIR"
install -d -o root -g www-data -m 0755 "$ADMIN_DIR"
install -o root -g www-data -m 0644 "$WORK/index.php" "$ADMIN_DIR/index.php"
if [[ "$LEGACY_DIR" != "$ADMIN_DIR" ]]; then rm -rf "$LEGACY_DIR"; fi

install -d -o root -g www-data -m 0750 "$CFG_DIR"
printf '%s\n' "$slug" > "$ROUTE_FILE"
chown root:root "$ROUTE_FILE"; chmod 0600 "$ROUTE_FILE"

SITE_CFG="$DASHBOARD_DIR/config/site.php"
REFLECTOR_NAME='XLX Modern'
if [[ -f "$SITE_CFG" ]]; then
  REFLECTOR_NAME="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["name"]??"XLX Modern");' "$SITE_CFG")"
fi
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
chown root:www-data "$CONTROL_CFG"; chmod 0640 "$CONTROL_CFG"; php -l "$CONTROL_CFG" >/dev/null

# Remove any Admin link left by an older installer. Do NOT add a replacement.
php -r '
$f=$argv[1];$slug=$argv[2];$s=file_get_contents($f);if($s===false)exit(2);
$s=preg_replace("~\\n?<!-- XLX_MODERN_ADMIN_NAV_START -->.*?<!-- XLX_MODERN_ADMIN_NAV_END -->\\n?~s","\n",$s);
$s=preg_replace("~\\s*<a[^>]+href=[\"\']/".preg_quote($slug,"~")."/[\"\'][^>]*>\\s*Admin\\s*</a>~i","",$s);
file_put_contents($f,$s);
' "$DASHBOARD_DIR/index.php" "$slug" || fail "$(say 'Falha ao remover referência pública antiga do Admin.' 'Failed to remove old public Admin reference.')"
php -l "$DASHBOARD_DIR/index.php" >/dev/null

# The private URL must not be advertised by public files.
if grep -Fq "href=\"/$slug/\"" "$DASHBOARD_DIR/index.php"; then fail "$(say 'A rota Admin ainda aparece no menu público.' 'Admin route is still present in public navigation.')"; fi
for public_file in "$DASHBOARD_DIR/sitemap.xml" "$DASHBOARD_DIR/robots.txt" "$DASHBOARD_DIR/llms.txt" "$DASHBOARD_DIR/ai-context.json"; do
  [[ -f "$public_file" ]] || continue
  if grep -Fq "/$slug/" "$public_file"; then fail "$(say "Rota Admin exposta em $public_file" "Admin route exposed in $public_file")"; fi
done

# Validate auth, security and all privileged read paths with the Apache user.
php -r '$c=require $argv[1];$i=password_get_info((string)($c["password_hash"]??""));exit((!empty($c["username"])&&!empty($c["password_hash"])&&!empty($i["algoName"])&&$i["algoName"]!=="unknown"&&($c["admin_slug"]??"")===$argv[2])?0:1);' "$CONTROL_CFG" "$slug" || fail "$(say 'Credencial/rota administrativa inválida.' 'Invalid Admin credential/route.')"
sudo -u "$WEBUSER" sudo -n "$HELPER" status > "$WORK/status.txt"
sudo -u "$WEBUSER" sudo -n "$HELPER" radioid-status > "$WORK/radioid.json"
sudo -u "$WEBUSER" sudo -n "$HELPER" access-status > "$WORK/access.json"
python3 -m json.tool "$WORK/radioid.json" >/dev/null
python3 -m json.tool "$WORK/access.json" >/dev/null
grep -Fq 'X-Robots-Tag: noindex, nofollow, noarchive, nosnippet' "$ADMIN_DIR/index.php"
grep -Fq 'googlebot|bingbot' "$ADMIN_DIR/index.php"
grep -Fq 'Controle de Acesso XLXD' "$ADMIN_DIR/index.php"
grep -Fq "if(\$a==='radioid_save')" "$ADMIN_DIR/index.php"
grep -Fq 'Links rápidos' "$ADMIN_DIR/index.php"

SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
ok "$(say 'Admin privado instalado sem link no painel público.' 'Private Admin installed with no public dashboard link.')"
ok "$(say 'Bots conhecidos recebem 404; mecanismos de busca também recebem noindex/nofollow/noarchive.' 'Known crawlers receive 404; search engines also receive noindex/nofollow/noarchive.')"
ok "$(say 'RadioID, whitelist, blacklist, terminal, logs, backups, testes e reinício protegido disponíveis.' 'RadioID, whitelist, blacklist, terminal, logs, backups, tests and protected restart are available.')"
echo "ADMIN_ROUTE=/$slug/"
echo 'ADMIN_PUBLIC_NAV=HIDDEN'
echo 'ADMIN_BOT_POLICY=404+NOINDEX'
echo 'ADMIN_STATUS=OK'
