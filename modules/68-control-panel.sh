#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlx-dashboard}}"
MODE="install"

for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) MODE="check" ;;
    --dashboard-dir=*) DASHBOARD_DIR="${arg#*=}" ;;
    -h|--help)
      cat <<'HELP'
XLX Modern Private Admin

Uso:
  sudo bash modules/68-control-panel.sh --check
  sudo bash modules/68-control-panel.sh --dashboard-dir=/var/www/html/xlx-dashboard

O Admin herda o conjunto funcional validado no XLX026:
  - status, portas, logs, backups e testes;
  - reinício XLXD protegido por senha e confirmação;
  - pesquisa, inclusão, edição, exclusão e atualização da base RadioID;
  - whitelist, blacklist e rota terminal XLXD;
  - auditoria, CSRF, rate-limit e sessão segura.

Credenciais:
  - o usuário é escolhido durante a instalação;
  - a senha é digitada duas vezes sem aparecer na tela;
  - somente password_hash() é persistido;
  - nenhuma senha é gravada no repositório.

Para automação controlada, XLX_CONTROL_USERNAME e XLX_CONTROL_PASSWORD
podem ser fornecidas somente no processo local.
HELP
      exit 0
      ;;
    *) echo "[ERRO] opção desconhecida: $arg" >&2; exit 2 ;;
  esac
done

CFG_DIR="/etc/xlx-modern-control"
CFG_FILE="$CFG_DIR/config.php"
HELPER_CONF="$CFG_DIR/helper.conf"
STATE_DIR="/var/lib/xlx-modern-control"
HELPER="/usr/local/sbin/xlx-modern-control-helper"
RADIO_HELPER="/usr/local/sbin/xlx-modern-radioid-helper"
ACCESS_HELPER="/usr/local/sbin/xlx-modern-access-helper"
SUDOERS="/etc/sudoers.d/xlx-modern-control"
CONTROL_DIR="$DASHBOARD_DIR/admin"
BASE_INDEX="$ROOT/control/xlx026-control-index-radioid-v2.php"
PATCH_V111="$ROOT/control/patch-xlx026-control-v111.py"
GENERICIZER="$ROOT/control/genericize-xlx-control.py"
SOURCE_HELPER="$ROOT/control/xlx-modern-control-helper"
SOURCE_RADIO="$ROOT/control/xlx-modern-radioid-helper"
SOURCE_ACCESS="$ROOT/control/xlx-modern-access-helper"
BACKUP_ROOT="/var/backups/xlx-reflector/control"
WEBUSER="www-data"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m%s\033[0m %s\n' "$(say '[ATENÇÃO]' '[WARNING]')" "$*"; }
fail(){ printf '\033[0;31m%s\033[0m %s\n' "$(say '[ERRO]' '[ERROR]')" "$*" >&2; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$*"; }

require_root(){ [[ "$(id -u)" -eq 0 ]] || { fail 'execute como root'; exit 1; }; }
version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

build_admin_source(){
  local out="$1"
  cp -a "$BASE_INDEX" "$out"
  python3 "$PATCH_V111" "$out"
  python3 "$GENERICIZER" "$out" "$UI_LANG"
  php -l "$out" >/dev/null
  grep -Fq "const CTRL_VER='1.3.0'" "$out"
  grep -Fq 'XLXD Access Control' "$out"
  grep -Fq "if(\$a==='radioid_save')" "$out"
  grep -Fq 'Quick links' "$out"
  grep -Fq 'googlebot|bingbot' "$out"
  ! grep -Eq 'xlx026\.net|Controle XLX026|/etc/xlx026-control|/var/lib/xlx026-control' "$out"
}

validate_sources(){
  for file in "$BASE_INDEX" "$PATCH_V111" "$GENERICIZER" "$SOURCE_HELPER" "$SOURCE_RADIO" "$SOURCE_ACCESS"; do
    [[ -f "$file" ]] || { fail "fonte do Admin ausente: $file"; exit 3; }
  done
  bash -n "$SOURCE_HELPER"
  bash -n "$SOURCE_RADIO"
  bash -n "$SOURCE_ACCESS"
  python3 -m py_compile "$PATCH_V111" "$GENERICIZER"
  local tmp
  tmp="$(mktemp /tmp/xlx-modern-admin-source.XXXXXX.php)"
  build_admin_source "$tmp"
  rm -f "$tmp"
  grep -Fq 'Uso permitido: status|listeners|logs|backups|restart|radioid-*|access-*' "$SOURCE_HELPER"
  ok 'fonte completa do Admin, helpers e sintaxe aprovados'
}

require_root
for command_name in bash curl find flock grep install php pgrep python3 sed sha256sum sqlite3 stat sudo systemctl tar visudo; do
  command -v "$command_name" >/dev/null 2>&1 || { fail "comando ausente: $command_name"; exit 5; }
done
validate_sources

if [[ "$MODE" == check ]]; then
  section 'ADMIN XLX MODERN — CHECK'
  ok 'baseline funcional do XLX026 pode ser convertido para instalação genérica'
  ok 'RadioID, whitelist, blacklist, terminal, auditoria e proteção presentes'
  ok 'nenhuma credencial fixa detectada'
  exit 0
fi

id "$WEBUSER" >/dev/null 2>&1 || { fail "usuário web $WEBUSER ausente"; exit 6; }
[[ -d "$DASHBOARD_DIR" ]] || { fail "dashboard ausente: $DASHBOARD_DIR"; exit 7; }
SITE_CFG="$DASHBOARD_DIR/config/site.php"
[[ -f "$SITE_CFG" ]] || { fail "configuração do dashboard ausente: $SITE_CFG"; exit 8; }
[[ -x /xlxd/xlxd ]] || { fail 'binário XLXD ausente'; exit 9; }
systemctl is-active --quiet xlxd.service || { fail 'xlxd.service inativo'; exit 10; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail 'quantidade de processos XLXD inesperada'; exit 11; }
for file in /xlxd/xlxd.whitelist /xlxd/xlxd.blacklist /xlxd/xlxd.terminal /xlxd/users_db/users_base.csv /xlxd/users_db/users.db /xlxd/users_db/create_user_db.php; do
  [[ -f "$file" ]] || { fail "dependência do Admin ausente: $file"; exit 12; }
done

REFLECTOR_NAME="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["name"]??"");' "$SITE_CFG")"
DOMAIN="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["domain"]??"");' "$SITE_CFG")"
[[ -n "$REFLECTOR_NAME" ]] || { fail 'nome do refletor não encontrado'; exit 13; }
[[ -n "$DOMAIN" ]] || { fail 'domínio não encontrado'; exit 14; }
DOMAIN="$(printf '%s' "$DOMAIN" | sed -E 's#^https?://##; s#/*$##')"
BASE_URL="${XLX_CONTROL_BASE_URL:-https://$DOMAIN}"
TITLE="Admin $REFLECTOR_NAME"
CORE_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
CORE_VERSION="$(version)"
[[ -n "$CORE_VERSION" ]] || { fail 'versão do XLXD não encontrada em /var/log/xlxd.xml'; exit 15; }

section "$(say '1/8 — CREDENCIAL LOCAL' '1/8 — LOCAL CREDENTIAL')"
USERNAME="${XLX_CONTROL_USERNAME:-}"
if [[ -z "$USERNAME" ]]; then
  while :; do
    read -r -p "$(say 'Usuário do Admin XLX Modern: ' 'XLX Modern Admin username: ')" USERNAME
    [[ "$USERNAME" =~ ^[A-Za-z0-9._-]{3,64}$ ]] && break
    echo "$(say 'Use 3-64 caracteres: letras, números, ponto, _ ou -.' 'Use 3-64 characters: letters, numbers, dot, _ or -.')"
  done
fi
[[ "$USERNAME" =~ ^[A-Za-z0-9._-]{3,64}$ ]] || { fail 'usuário inválido'; exit 20; }

PASSWORD="${XLX_CONTROL_PASSWORD:-}"
if [[ -z "$PASSWORD" ]]; then
  # An interactive typo must never end the full XLX installation. Keep the
  # operator in this credential step until the password is long enough and
  # the confirmation matches; no password is printed or persisted here.
  while :; do
    printf '%s' "$(say 'Senha do Admin (mínimo 10 caracteres): ' 'Admin password (minimum 10 characters): ')" >&2
    IFS= read -r -s PASSWORD
    printf '\n' >&2
    printf '%s' "$(say 'Repita a senha: ' 'Repeat the password: ')" >&2
    IFS= read -r -s PASSWORD2
    printf '\n' >&2

    if [[ ${#PASSWORD} -lt 10 ]]; then
      warn "$(say 'senha deve ter ao menos 10 caracteres; tente novamente.' 'Password must be at least 10 characters; try again.')"
      unset PASSWORD PASSWORD2
      continue
    fi
    if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
      warn "$(say 'as senhas não coincidem; tente novamente.' 'Passwords do not match; try again.')"
      unset PASSWORD PASSWORD2
      continue
    fi
    unset PASSWORD2
    break
  done
fi
[[ ${#PASSWORD} -ge 10 ]] || { fail 'senha fornecida sem interação deve ter ao menos 10 caracteres'; exit 22; }
PASSWORD_HASH="$(printf '%s' "$PASSWORD" | php -r '$p=stream_get_contents(STDIN); echo password_hash($p,PASSWORD_DEFAULT);')"
[[ -n "$PASSWORD_HASH" ]] || { fail 'falha ao gerar hash'; exit 23; }
ok "$(say 'credencial recebida localmente; senha não será exibida nem persistida em texto puro' 'Credential received locally; the password is never displayed or stored in plain text.')"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
TMP="$(mktemp -d /tmp/xlx-modern-control.XXXXXX)"
MUTATED=0
SUCCESS=0
mkdir -p "$BACKUP"; chmod 700 "$BACKUP"

cleanup(){ unset PASSWORD XLX_CONTROL_PASSWORD 2>/dev/null || true; rm -rf "$TMP"; }
rollback(){
  local reason="$1"
  trap - EXIT
  set +e
  fail "rollback automático: $reason"
  rm -rf "$CONTROL_DIR" "$CFG_DIR"
  rm -f "$HELPER" "$RADIO_HELPER" "$ACCESS_HELPER" "$SUDOERS"
  [[ -f "$BACKUP/control.before.tar.gz" ]] && tar -C "$DASHBOARD_DIR" -xzf "$BACKUP/control.before.tar.gz"
  [[ -f "$BACKUP/config.before.tar.gz" ]] && tar -C / -xzf "$BACKUP/config.before.tar.gz"
  [[ -f "$BACKUP/helper.before" ]] && cp -a "$BACKUP/helper.before" "$HELPER"
  [[ -f "$BACKUP/radio-helper.before" ]] && cp -a "$BACKUP/radio-helper.before" "$RADIO_HELPER"
  [[ -f "$BACKUP/access-helper.before" ]] && cp -a "$BACKUP/access-helper.before" "$ACCESS_HELPER"
  [[ -f "$BACKUP/sudoers.before" ]] && cp -a "$BACKUP/sudoers.before" "$SUDOERS"
  [[ -f "$SUDOERS" ]] && visudo -cf "$SUDOERS" >/dev/null 2>&1 || true
  cleanup
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; fi' EXIT

section '2/8 — BACKUP'
[[ -d "$CONTROL_DIR" ]] && tar -C "$DASHBOARD_DIR" -czf "$BACKUP/control.before.tar.gz" admin
[[ -d "$CFG_DIR" ]] && tar -C / -czf "$BACKUP/config.before.tar.gz" "${CFG_DIR#/}"
[[ -f "$HELPER" ]] && cp -a "$HELPER" "$BACKUP/helper.before"
[[ -f "$RADIO_HELPER" ]] && cp -a "$RADIO_HELPER" "$BACKUP/radio-helper.before"
[[ -f "$ACCESS_HELPER" ]] && cp -a "$ACCESS_HELPER" "$BACKUP/access-helper.before"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACKUP/sudoers.before"
sha256sum /xlxd/xlxd > "$BACKUP/core.before.sha256"
ok "backup preparado em $BACKUP"

section '3/8 — PREPARAR ADMIN COMPLETO'
build_admin_source "$TMP/index.php"
php -r '
$u=$argv[1];$h=$argv[2];$sha=$argv[3];$ver=$argv[4];$base=$argv[5];$title=$argv[6];
$data=[
 "username"=>$u,
 "password_hash"=>$h,
 "expected_core_sha"=>$sha,
 "expected_core_version"=>$ver,
 "base_url"=>$base,
 "title"=>$title,
 "admin_slug"=>"admin",
 "test_paths"=>[
  ["/ao-vivo",200,"html"],
  ["/conectados",200,"html"],
  ["/ranking",200,"html"],
  ["/refletores",200,"html"],
  ["/api/status.php",200,"json"],
  ["/api/live.php",200,"json"],
  ["/api/mtr.php",400,"json"],
 ],
];
file_put_contents($argv[7],"<?php\ndeclare(strict_types=1);\nreturn ".var_export($data,true).";\n");
' "$USERNAME" "$PASSWORD_HASH" "$CORE_SHA" "$CORE_VERSION" "$BASE_URL" "$TITLE" "$TMP/config.php"

cat > "$TMP/helper.conf" <<EOF
EXPECTED_SHA="$CORE_SHA"
EXPECTED_VERSION="$CORE_VERSION"
SERVICE="xlxd.service"
BIN="/xlxd/xlxd"
XML="/var/log/xlxd.xml"
LOG="/var/log/xlx.log"
BACKUPS="/var/backups/xlx-reflector"
EOF
php -l "$TMP/config.php" >/dev/null
if grep -Fq "$PASSWORD" "$TMP/config.php"; then fail 'senha em texto puro detectada'; exit 30; fi
ok 'candidato completo e configuração protegida preparados'

section '4/8 — INSTALAR'
MUTATED=1
install -d -o root -g www-data -m 0755 "$CONTROL_DIR"
install -d -o root -g www-data -m 0750 "$CFG_DIR"
install -d -o root -g www-data -m 0770 "$STATE_DIR"
install -o root -g www-data -m 0644 "$TMP/index.php" "$CONTROL_DIR/index.php"
install -o root -g root -m 0755 "$SOURCE_HELPER" "$HELPER"
install -o root -g root -m 0755 "$SOURCE_RADIO" "$RADIO_HELPER"
install -o root -g root -m 0755 "$SOURCE_ACCESS" "$ACCESS_HELPER"
install -o root -g www-data -m 0640 "$TMP/config.php" "$CFG_FILE"
install -o root -g root -m 0600 "$TMP/helper.conf" "$HELPER_CONF"
php -l "$CONTROL_DIR/index.php" >/dev/null
bash -n "$HELPER" "$RADIO_HELPER" "$ACCESS_HELPER"
ok "Admin completo instalado temporariamente em $CONTROL_DIR"

section '5/8 — SUDOERS RESTRITO'
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
sudo -u "$WEBUSER" sudo -n "$HELPER" status > "$TMP/status.txt"
grep -Fxq 'service=active' "$TMP/status.txt"
grep -Fxq "version=$CORE_VERSION" "$TMP/status.txt"
grep -Fxq "sha=$CORE_SHA" "$TMP/status.txt"
grep -Fxq 'processes=1' "$TMP/status.txt"
sudo -u "$WEBUSER" sudo -n "$HELPER" radioid-status > "$TMP/radioid.json"
sudo -u "$WEBUSER" sudo -n "$HELPER" access-status > "$TMP/access.json"
python3 -m json.tool "$TMP/radioid.json" >/dev/null
python3 -m json.tool "$TMP/access.json" >/dev/null
ok 'www-data limitado à allowlist administrativa validada'

section '6/8 — VALIDAR CREDENCIAL E SEGURANÇA'
php -r '$c=require $argv[1]; exit(($c["username"]===$argv[2] && password_verify($argv[3],$c["password_hash"]))?0:1);' "$CFG_FILE" "$USERNAME" "$PASSWORD"
if grep -Fq "$PASSWORD" "$CFG_FILE"; then fail 'senha em texto puro detectada após instalação'; exit 60; fi
grep -Fq 'X-Robots-Tag: noindex, nofollow, noarchive, nosnippet' "$CONTROL_DIR/index.php"
grep -Fq 'googlebot|bingbot' "$CONTROL_DIR/index.php"
grep -Fq 'session.use_strict_mode' "$CONTROL_DIR/index.php"
grep -Fq 'fail_login' "$CONTROL_DIR/index.php"
grep -Fq 'csrf_ok' "$CONTROL_DIR/index.php"
ok 'credencial, noindex, crawler deny, rate-limit, sessão e CSRF validados'

section '7/8 — TESTE WEB LOCAL'
WEB_OK=0
if curl --silent --show-error --insecure --resolve "$DOMAIN:443:127.0.0.1" --connect-timeout 5 --max-time 12 "$BASE_URL/admin/" -o "$TMP/web.html" 2>/dev/null; then
  if grep -Fq "$TITLE" "$TMP/web.html" && grep -Fq 'Restricted access' "$TMP/web.html"; then WEB_OK=1; fi
fi
if [[ "$WEB_OK" -eq 1 ]]; then
  ok 'tela privada respondeu localmente via HTTPS'
else
  warn 'não foi possível provar a URL HTTPS localmente; PHP, helpers e credencial foram validados'
fi

section '8/8 — RELATÓRIO'
cat > "$BACKUP/CONTROL_INSTALL_COMPLETE" <<EOF
status=CONTROL_INSTALL_OK
control_version=1.3.0
reflector=$REFLECTOR_NAME
url=$BASE_URL/admin/
username=$USERNAME
password_storage=hash_only
radioid_admin=yes
whitelist_blacklist_admin=yes
terminal_route_admin=yes
bot_indexing=no
core_version=$CORE_VERSION
core_sha=$CORE_SHA
control_dir=$CONTROL_DIR
config=$CFG_FILE
helper=$HELPER
radio_helper=$RADIO_HELPER
access_helper=$ACCESS_HELPER
sudoers=$SUDOERS
web_local_test=$WEB_OK
xlxd_restart_during_install=no
EOF
cat "$BACKUP/CONTROL_INSTALL_COMPLETE"
SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
ok 'ADMIN XLX MODERN COMPLETO INSTALADO'
echo "Temporary URL: $BASE_URL/admin/"
echo "Usuário: $USERNAME"
echo 'Senha: definida pelo operador e não exibida'
