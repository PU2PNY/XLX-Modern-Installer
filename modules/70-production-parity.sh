#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'; umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlxd}}"
CFG_DIR=/etc/xlx-modern-control
ROUTE_FILE="$CFG_DIR/route"
CONTROL_CFG="$CFG_DIR/config.php"
HELPER=/usr/local/sbin/xlx-modern-control-helper
RADIO_HELPER=/usr/local/sbin/xlx-modern-radioid-helper
ACCESS_HELPER=/usr/local/sbin/xlx-modern-access-helper
SUDOERS=/etc/sudoers.d/xlx-modern-control
UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ [[ "$UI_LANG" == en ]]&&printf '%s' "$2"||printf '%s' "$1"; }
ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" -eq 0 ]]||fail "$(say 'Execute como root.' 'Run as root.')"
[[ -s "$ROUTE_FILE" ]]||fail "$(say 'Rota Admin ausente.' 'Admin route missing.')"
slug="$(tr -d '\r\n' < "$ROUTE_FILE")"
[[ "$slug" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]]||fail "$(say 'Rota Admin inválida.' 'Invalid Admin route.')"
ADMIN_INDEX="$DASHBOARD_DIR/$slug/index.php"
for f in "$DASHBOARD_DIR/index.php" "$ADMIN_INDEX" "$CONTROL_CFG" "$HELPER" "$RADIO_HELPER" "$ACCESS_HELPER" "$SUDOERS";do [[ -f "$f" ]]||fail "$(say "Arquivo ausente: $f" "Missing file: $f")";done
php -l "$DASHBOARD_DIR/index.php" >/dev/null;php -l "$ADMIN_INDEX" >/dev/null
bash -n "$HELPER" "$RADIO_HELPER" "$ACCESS_HELPER";visudo -cf "$SUDOERS" >/dev/null
grep -Fq "'modulos' =>" "$DASHBOARD_DIR/index.php"||fail "$(say 'Menu Módulos separado ausente.' 'Separate Modules menu missing.')"
grep -Fq "<?php elseif (\$page === 'modulos'): ?>" "$DASHBOARD_DIR/index.php"||fail "$(say 'Página Módulos ausente.' 'Modules page missing.')"
! grep -Eq 'Terminal XLXD|Terminal SSH|shell_exec\(\$_POST|passthru\(\$_POST' "$ADMIN_INDEX"||fail "$(say 'Terminal proibido detectado.' 'Forbidden terminal detected.')"
grep -Fq 'access-interlink-add' "$ADMIN_INDEX"||fail "$(say 'Interlink completo ausente.' 'Complete Interlink missing.')"
grep -Fq 'health-status' "$ADMIN_INDEX"||fail "$(say 'Health Admin ausente.' 'Admin Health missing.')"
grep -Fq 'radioid_api_search' "$ADMIN_INDEX"||fail "$(say 'Consulta RadioID.net ausente.' 'RadioID.net lookup missing.')"
! grep -Fq "href=\"/$slug/\"" "$DASHBOARD_DIR/index.php"||fail "$(say 'Rota Admin apareceu no painel público.' 'Admin route leaked into public dashboard.')"
# Add Modules/APRS to protected self-tests if missing.
php -r '$f=$argv[1];$c=require $f;$p=is_array($c["test_paths"]??null)?$c["test_paths"]:[];$wanted=[["/ao-vivo",200,"html"],["/modulos",200,"html"],["/conectados",200,"html"],["/ranking",200,"html"],["/refletores",200,"html"],["/aprs-dprs/",200,"html"],["/api/status.php",200,"json"],["/api/live.php",200,"json"]];$seen=[];$out=[];foreach(array_merge($p,$wanted) as$r){if(!is_array($r)||count($r)<3)continue;$k=(string)$r[0];if(isset($seen[$k]))continue;$seen[$k]=1;$out[]=$r;}$c["test_paths"]=$out;file_put_contents($f,"<?php\ndeclare(strict_types=1);\nreturn ".var_export($c,true).";\n");' "$CONTROL_CFG"
chown root:www-data "$CONTROL_CFG";chmod 0640 "$CONTROL_CFG";php -l "$CONTROL_CFG" >/dev/null
ok "$(say 'Paridade final validada sem reiniciar o XLXD.' 'Final parity validated without restarting XLXD.')"
