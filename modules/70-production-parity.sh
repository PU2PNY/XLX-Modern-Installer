#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlxd}}"
CFG_DIR="/etc/xlx-modern-control"
ROUTE_FILE="$CFG_DIR/route"
CONTROL_CFG="$CFG_DIR/config.php"
HELPER="/usr/local/sbin/xlx-modern-control-helper"
ACCESS_HELPER="/usr/local/sbin/xlx-modern-access-helper"
SUDOERS="/etc/sudoers.d/xlx-modern-control"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
BACKUP_ROOT="/var/backups/xlx-reflector/production-parity"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
MUTATED=0
SUCCESS=0

say(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m%s\033[0m %s\n' "$(say '[ATENÇÃO]' '[WARNING]')" "$*"; }
fail(){ printf '\033[0;31m%s\033[0m %s\n' "$(say '[ERRO]' '[ERROR]')" "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
for cmd in bash install php python3 visudo sha256sum; do command -v "$cmd" >/dev/null 2>&1 || fail "$(say "Comando ausente: $cmd" "Missing command: $cmd")"; done
[[ -f "$DASHBOARD_DIR/index.php" ]] || fail "$(say 'index.php do painel ausente.' 'Dashboard index.php missing.')"
[[ -s "$ROUTE_FILE" ]] || fail "$(say 'Rota administrativa ausente.' 'Admin route missing.')"
slug="$(tr -d '\r\n' < "$ROUTE_FILE")"
[[ "$slug" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || fail "$(say 'Rota administrativa inválida.' 'Invalid admin route.')"
ADMIN_INDEX="$DASHBOARD_DIR/$slug/index.php"
[[ -f "$ADMIN_INDEX" ]] || fail "$(say 'Página administrativa ausente.' 'Admin page missing.')"

mkdir -p "$BACKUP"; chmod 0700 "$BACKUP"
cp -a "$DASHBOARD_DIR/index.php" "$BACKUP/dashboard-index.before"
cp -a "$ADMIN_INDEX" "$BACKUP/admin-index.before"
[[ -f "$HELPER" ]] && cp -a "$HELPER" "$BACKUP/control-helper.before"
[[ -f "$ACCESS_HELPER" ]] && cp -a "$ACCESS_HELPER" "$BACKUP/access-helper.before"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACKUP/sudoers.before"
[[ -f "$CONTROL_CFG" ]] && cp -a "$CONTROL_CFG" "$BACKUP/control-config.before"
sha256sum "$BACKUP"/* > "$BACKUP/SHA256_BEFORE.txt" 2>/dev/null || true
ok "$(say "Backup criado: $BACKUP" "Backup created: $BACKUP")"

rollback(){
  local rc="${1:-90}"
  trap - EXIT
  set +e
  warn "$(say 'Falha detectada; restaurando estado anterior.' 'Failure detected; restoring previous state.')"
  cp -a "$BACKUP/dashboard-index.before" "$DASHBOARD_DIR/index.php"
  cp -a "$BACKUP/admin-index.before" "$ADMIN_INDEX"
  [[ -f "$BACKUP/control-helper.before" ]] && cp -a "$BACKUP/control-helper.before" "$HELPER"
  [[ -f "$BACKUP/access-helper.before" ]] && cp -a "$BACKUP/access-helper.before" "$ACCESS_HELPER"
  if [[ -f "$BACKUP/sudoers.before" ]]; then cp -a "$BACKUP/sudoers.before" "$SUDOERS"; else rm -f "$SUDOERS"; fi
  [[ -f "$BACKUP/control-config.before" ]] && cp -a "$BACKUP/control-config.before" "$CONTROL_CFG"
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "$rc"; fi' EXIT
MUTATED=1

install -o root -g root -m 0755 "$ROOT/control/xlx-modern-control-helper-v2" "$HELPER"
install -o root -g root -m 0755 "$ROOT/control/xlx-modern-access-helper-v2" "$ACCESS_HELPER"
bash -n "$HELPER" "$ACCESS_HELPER"

cat > "$SUDOERS" <<'EOF'
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper status
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper listeners
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper logs
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper backups
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper restart
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper radioid-status
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper radioid-check
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper radioid-refresh
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper radioid-search *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper radioid-save *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper radioid-delete *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper access-status
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper access-add-white *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper access-delete-white *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper access-add-black *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper access-delete-black *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper interlink-save *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx-modern-control-helper interlink-delete *
EOF
chmod 0440 "$SUDOERS"
visudo -cf "$SUDOERS" >/dev/null

python3 "$ROOT/control/finalize-production-parity-v14.py" "$DASHBOARD_DIR/index.php" "$ADMIN_INDEX" "$UI_LANG"
php -l "$DASHBOARD_DIR/index.php" >/dev/null
php -l "$ADMIN_INDEX" >/dev/null

# Make the protected test runner aware that Modules is a real independent page.
if [[ -f "$CONTROL_CFG" ]]; then
  php -r '
$f=$argv[1];$c=require $f;$paths=is_array($c["test_paths"]??null)?$c["test_paths"]:[];
$out=[];$seen=false;
foreach($paths as $row){if(!is_array($row)||count($row)<3)continue;if(($row[0]??"")==="/modulos")$seen=true;if(($row[0]??"")==="/conectados"&&!$seen){$out[]=["/modulos",200,"html"];$seen=true;}$out[]=$row;}
if(!$seen)$out[]=["/modulos",200,"html"];
$c["test_paths"]=$out;file_put_contents($f,"<?php\ndeclare(strict_types=1);\nreturn ".var_export($c,true).";\n");
' "$CONTROL_CFG"
  chown root:www-data "$CONTROL_CFG"; chmod 0640 "$CONTROL_CFG"; php -l "$CONTROL_CFG" >/dev/null
fi

# Security invariants: private admin is not advertised and no terminal is added.
! grep -Eq 'Terminal XLXD|Terminal SSH|shell_exec\(\$_POST|passthru\(\$_POST' "$ADMIN_INDEX" || fail "$(say 'Marcador de terminal proibido encontrado.' 'Forbidden terminal marker found.')"
! grep -Fq "href=\"/$slug/\"" "$DASHBOARD_DIR/index.php" || fail "$(say 'A rota Admin apareceu no menu público.' 'Admin route leaked into public navigation.')"
grep -Fq "'modulos' =>" "$DASHBOARD_DIR/index.php" || fail "$(say 'Página Módulos não foi separada.' 'Modules page was not separated.')"
grep -Fq 'interlink_reflector' "$ADMIN_INDEX" || fail "$(say 'Formulário Interlink de três campos ausente.' 'Three-field Interlink form missing.')"
grep -Fq 'interlink-save *' "$SUDOERS" || fail "$(say 'Autorização protegida do Interlink ausente.' 'Protected Interlink authorization missing.')"

sha256sum "$DASHBOARD_DIR/index.php" "$ADMIN_INDEX" "$HELPER" "$ACCESS_HELPER" "$SUDOERS" > "$BACKUP/SHA256_AFTER.txt"
SUCCESS=1
ok "$(say 'Paridade validada: Admin corrigido, Módulos/Conectados separados e nenhuma reinicialização do XLXD executada.' 'Parity validated: Admin fixed, Modules/Connected separated, and XLXD was not restarted.')"
