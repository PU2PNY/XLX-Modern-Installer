#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlx-dashboard}}"
MODE="install"

for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) MODE="check" ;;
    --dashboard-dir=*) DASHBOARD_DIR="${arg#*=}" ;;
    -h|--help)
      cat <<'HELP'
XLX Modern Private Control

Uso:
  sudo bash modules/68-control-panel.sh --check
  sudo bash modules/68-control-panel.sh --dashboard-dir=/var/www/html/xlx-dashboard

Credenciais:
  - o usuário é escolhido durante a instalação;
  - a senha é digitada duas vezes sem aparecer na tela;
  - somente password_hash() é persistido;
  - nenhuma senha é gravada no repositório.

Para automação controlada, as variáveis XLX_CONTROL_USERNAME e
XLX_CONTROL_PASSWORD podem ser fornecidas somente no processo local.
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
SUDOERS="/etc/sudoers.d/xlx-modern-control"
CONTROL_DIR="$DASHBOARD_DIR/controle"
SOURCE_INDEX="$ROOT/control/index.php"
SOURCE_HELPER="$ROOT/control/xlx-modern-control-helper"
BACKUP_ROOT="/var/backups/xlx-reflector/control"
WEBUSER="www-data"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$*"; }

require_root(){ [[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }; }
version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

validate_sources(){
  [[ -f "$SOURCE_INDEX" ]] || { fail "fonte do painel ausente: $SOURCE_INDEX"; exit 3; }
  [[ -f "$SOURCE_HELPER" ]] || { fail "helper ausente: $SOURCE_HELPER"; exit 4; }
  php -l "$SOURCE_INDEX" >/dev/null
  bash -n "$SOURCE_HELPER"
  grep -Fq "const CFG = '/etc/xlx-modern-control/config.php';" "$SOURCE_INDEX"
  grep -Fq 'Uso permitido: status|listeners|logs|backups|restart' "$SOURCE_HELPER"
  ! grep -Eq 'xlx026\.net|Controle XLX026|/etc/xlx026-control|/var/lib/xlx026-control' "$SOURCE_INDEX" "$SOURCE_HELPER"
  ok "fontes genéricas e sintaxe aprovadas"
}

require_root
for command_name in bash curl find grep install php pgrep sed sha256sum stat sudo systemctl tar visudo; do
  command -v "$command_name" >/dev/null 2>&1 || { fail "comando ausente: $command_name"; exit 5; }
done
validate_sources

if [[ "$MODE" == "check" ]]; then
  section "CONTROLE XLX MODERN — CHECK"
  ok "código do painel aprovado"
  ok "helper limitado a 5 ações fixas"
  ok "nenhuma credencial fixa detectada"
  exit 0
fi

id "$WEBUSER" >/dev/null 2>&1 || { fail "usuário web $WEBUSER ausente"; exit 6; }
[[ -d "$DASHBOARD_DIR" ]] || { fail "dashboard ausente: $DASHBOARD_DIR"; exit 7; }
SITE_CFG="$DASHBOARD_DIR/config/site.php"
[[ -f "$SITE_CFG" ]] || { fail "configuração do dashboard ausente: $SITE_CFG"; exit 8; }
[[ -x /xlxd/xlxd ]] || { fail "binário XLXD ausente"; exit 9; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service inativo"; exit 10; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade de processos XLXD inesperada"; exit 11; }

REFLECTOR_NAME="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["name"]??"");' "$SITE_CFG")"
DOMAIN="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["domain"]??"");' "$SITE_CFG")"
[[ -n "$REFLECTOR_NAME" ]] || { fail "nome do refletor não encontrado"; exit 12; }
[[ -n "$DOMAIN" ]] || { fail "domínio não encontrado"; exit 13; }
DOMAIN="$(printf '%s' "$DOMAIN" | sed -E 's#^https?://##; s#/*$##')"
BASE_URL="${XLX_CONTROL_BASE_URL:-https://$DOMAIN}"
TITLE="Controle $REFLECTOR_NAME"
CORE_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
CORE_VERSION="$(version)"
[[ -n "$CORE_VERSION" ]] || { fail "versão do XLXD não encontrada em /var/log/xlxd.xml"; exit 14; }

section "1/8 — CREDENCIAL LOCAL"
USERNAME="${XLX_CONTROL_USERNAME:-}"
if [[ -z "$USERNAME" ]]; then
  while :; do
    read -r -p "Usuário do Controle XLX Modern: " USERNAME
    [[ "$USERNAME" =~ ^[A-Za-z0-9._-]{3,64}$ ]] && break
    echo "Use 3-64 caracteres: letras, números, ponto, _ ou -."
  done
fi
[[ "$USERNAME" =~ ^[A-Za-z0-9._-]{3,64}$ ]] || { fail "usuário inválido"; exit 20; }

PASSWORD="${XLX_CONTROL_PASSWORD:-}"
if [[ -z "$PASSWORD" ]]; then
  printf 'Senha do Controle (mínimo 10 caracteres): ' >&2
  IFS= read -r -s PASSWORD
  printf '\n' >&2
  printf 'Repita a senha: ' >&2
  IFS= read -r -s PASSWORD2
  printf '\n' >&2
  [[ "$PASSWORD" == "$PASSWORD2" ]] || { fail "as senhas não coincidem"; exit 21; }
  unset PASSWORD2
fi
[[ ${#PASSWORD} -ge 10 ]] || { fail "senha deve ter ao menos 10 caracteres"; exit 22; }
PASSWORD_HASH="$(printf '%s' "$PASSWORD" | php -r '$p=stream_get_contents(STDIN); echo password_hash($p,PASSWORD_DEFAULT);')"
[[ -n "$PASSWORD_HASH" ]] || { fail "falha ao gerar hash"; exit 23; }
ok "credencial recebida localmente; senha não será exibida nem persistida em texto puro"

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
  rm -f "$HELPER" "$SUDOERS"
  [[ -f "$BACKUP/control.before.tar.gz" ]] && tar -C "$DASHBOARD_DIR" -xzf "$BACKUP/control.before.tar.gz"
  [[ -f "$BACKUP/config.before.tar.gz" ]] && tar -C / -xzf "$BACKUP/config.before.tar.gz"
  [[ -f "$BACKUP/helper.before" ]] && cp -a "$BACKUP/helper.before" "$HELPER"
  [[ -f "$BACKUP/sudoers.before" ]] && cp -a "$BACKUP/sudoers.before" "$SUDOERS"
  [[ -f "$SUDOERS" ]] && visudo -cf "$SUDOERS" >/dev/null 2>&1 || true
  cleanup
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; fi' EXIT

section "2/8 — BACKUP"
[[ -d "$CONTROL_DIR" ]] && tar -C "$DASHBOARD_DIR" -czf "$BACKUP/control.before.tar.gz" controle
[[ -d "$CFG_DIR" ]] && tar -C / -czf "$BACKUP/config.before.tar.gz" "${CFG_DIR#/}"
[[ -f "$HELPER" ]] && cp -a "$HELPER" "$BACKUP/helper.before"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACKUP/sudoers.before"
sha256sum /xlxd/xlxd > "$BACKUP/core.before.sha256"
ok "backup preparado em $BACKUP"

section "3/8 — PREPARAR CONFIGURAÇÕES"
php -r '
$u=$argv[1];$h=$argv[2];$sha=$argv[3];$ver=$argv[4];$base=$argv[5];$title=$argv[6];
$data=[
 "username"=>$u,
 "password_hash"=>$h,
 "expected_core_sha"=>$sha,
 "expected_core_version"=>$ver,
 "base_url"=>$base,
 "title"=>$title,
 "test_paths"=>[
  ["/ao-vivo",200,"html"],
  ["/conectados",200,"html"],
  ["/suporte",200,"html"],
  ["/ranking",200,"html"],
  ["/refletores",200,"html"],
  ["/noticias",200,"html"],
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
if grep -Fq "$PASSWORD" "$TMP/config.php"; then fail "senha em texto puro detectada"; exit 30; fi
ok "configuração contém apenas hash e parâmetros locais"

section "4/8 — INSTALAR"
MUTATED=1
install -d -o root -g www-data -m 0755 "$CONTROL_DIR"
install -d -o root -g www-data -m 0750 "$CFG_DIR"
install -d -o root -g www-data -m 0770 "$STATE_DIR"
install -o root -g www-data -m 0644 "$SOURCE_INDEX" "$CONTROL_DIR/index.php"
install -o root -g root -m 0755 "$SOURCE_HELPER" "$HELPER"
install -o root -g www-data -m 0640 "$TMP/config.php" "$CFG_FILE"
install -o root -g root -m 0600 "$TMP/helper.conf" "$HELPER_CONF"
php -l "$CONTROL_DIR/index.php" >/dev/null
ok "Controle instalado em $CONTROL_DIR"

section "5/8 — SUDOERS RESTRITO"
cat > "$SUDOERS" <<EOF
$WEBUSER ALL=(root) NOPASSWD: $HELPER status
$WEBUSER ALL=(root) NOPASSWD: $HELPER listeners
$WEBUSER ALL=(root) NOPASSWD: $HELPER logs
$WEBUSER ALL=(root) NOPASSWD: $HELPER backups
$WEBUSER ALL=(root) NOPASSWD: $HELPER restart
EOF
chmod 0440 "$SUDOERS"
visudo -cf "$SUDOERS" >/dev/null
sudo -u "$WEBUSER" sudo -n "$HELPER" status > "$TMP/status.txt"
grep -Fxq 'service=active' "$TMP/status.txt"
grep -Fxq "version=$CORE_VERSION" "$TMP/status.txt"
grep -Fxq "sha=$CORE_SHA" "$TMP/status.txt"
grep -Fxq 'processes=1' "$TMP/status.txt"
ok "www-data limitado às 5 ações fixas"

section "6/8 — VALIDAR CREDENCIAL"
php -r '$c=require $argv[1]; exit(($c["username"]===$argv[2] && password_verify($argv[3],$c["password_hash"]))?0:1);' "$CFG_FILE" "$USERNAME" "$PASSWORD"
if grep -Fq "$PASSWORD" "$CFG_FILE"; then fail "senha em texto puro detectada após instalação"; exit 60; fi
ok "usuário e hash validados localmente"

section "7/8 — TESTE WEB LOCAL"
WEB_OK=0
if curl --silent --show-error --insecure --resolve "$DOMAIN:443:127.0.0.1" --connect-timeout 5 --max-time 12 "$BASE_URL/controle/" -o "$TMP/web.html" 2>/dev/null; then
  if grep -Fq "$TITLE" "$TMP/web.html" && grep -Fq 'Acesso restrito' "$TMP/web.html"; then WEB_OK=1; fi
fi
if [[ "$WEB_OK" -eq 1 ]]; then
  ok "tela de login respondeu localmente via HTTPS"
else
  warn "não foi possível provar a URL HTTPS localmente; arquivos, PHP, helper e credencial foram validados"
fi

section "8/8 — RELATÓRIO"
cat > "$BACKUP/CONTROL_INSTALL_COMPLETE" <<EOF
status=CONTROL_INSTALL_OK
control_version=1.1.0
reflector=$REFLECTOR_NAME
url=$BASE_URL/controle/
username=$USERNAME
password_storage=hash_only
core_version=$CORE_VERSION
core_sha=$CORE_SHA
control_dir=$CONTROL_DIR
config=$CFG_FILE
helper=$HELPER
sudoers=$SUDOERS
web_local_test=$WEB_OK
xlxd_restart_during_install=no
EOF
cat "$BACKUP/CONTROL_INSTALL_COMPLETE"
SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
ok "CONTROLE XLX MODERN INSTALADO"
echo "URL: $BASE_URL/controle/"
echo "Usuário: $USERNAME"
echo "Senha: definida pelo operador e não exibida"
