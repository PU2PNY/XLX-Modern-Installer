#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

WEBROOT="/var/www/html/xlxd-novo"
CONTROL_DIR="$WEBROOT/controle"
CFG_DIR="/etc/xlx026-control"
CFG_FILE="$CFG_DIR/config.php"
STATE_DIR="/var/lib/xlx026-control"
HELPER="/usr/local/sbin/xlx026-control-helper"
SUDOERS="/etc/sudoers.d/xlx026-control"
BACKUP_ROOT="/root/backups-xlx026"
BASE_URL="https://xlx026.net"
WEBUSER="www-data"
USERNAME="xlx026"
EXPECTED_CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
EXPECTED_CORE_VERSION="2.6.0"
SOURCE_COMMIT="ba01bf14857078129f42adb31694813fe6a4a7bd"
INDEX_BLOB="c615cb8068d5d9ce900fc193ea771642f2206e94"
HELPER_BLOB="dc78219b8a8a6fdfe6a364b2d422b5a5340e735c"
INDEX_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_COMMIT}/control/index.php"
HELPER_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_COMMIT}/control/xlx026-control-helper"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk bash cp curl date find git grep install mkdir openssl php pgrep sha256sum stat sudo systemctl tar visudo; do command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }; done
id "$WEBUSER" >/dev/null 2>&1 || { fail "usuário web $WEBUSER ausente"; exit 3; }
[[ -d "$WEBROOT" ]] || { fail "webroot ausente: $WEBROOT"; exit 4; }
[[ -x /xlxd/xlxd ]] || { fail "binário XLXD ausente"; exit 5; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "SHA do Core divergiu; nada será alterado"; exit 6; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "XML não reporta 2.6.0"; exit 7; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service inativo"; exit 8; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade de processos XLXD inesperada"; exit 9; }
php -r 'exit(function_exists("exec") ? 0 : 1);' || { fail "PHP exec() indisponível; controle não seria funcional"; exit 10; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_CONTROL_INSTALL_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-control-install.XXXXXX)"
INDEX_SRC="$TMP/index.php"
HELPER_SRC="$TMP/helper"
COOKIE="$TMP/cookie.jar"
POST="$TMP/login.post"
MUTATED=0
SUCCESS=0
mkdir -p "$OUT"; chmod 700 "$OUT"

CONTROL_EXISTED=0; CFG_EXISTED=0; HELPER_EXISTED=0; SUDOERS_EXISTED=0; STATE_EXISTED=0
[[ -e "$CONTROL_DIR" ]] && CONTROL_EXISTED=1
[[ -e "$CFG_DIR" ]] && CFG_EXISTED=1
[[ -e "$HELPER" ]] && HELPER_EXISTED=1
[[ -e "$SUDOERS" ]] && SUDOERS_EXISTED=1
[[ -e "$STATE_DIR" ]] && STATE_EXISTED=1

cleanup(){ rm -rf "$TMP"; }
rollback(){
 local reason="$1"; trap - EXIT; set +e
 fail "ROLLBACK AUTOMÁTICO DO CONTROLE: $reason"
 if [[ "$MUTATED" -eq 1 ]]; then
  rm -rf "$CONTROL_DIR" "$CFG_DIR"
  rm -f "$HELPER" "$SUDOERS"
  if [[ "$CONTROL_EXISTED" -eq 1 && -f "$OUT/control.before.tar.gz" ]]; then tar -C "$WEBROOT" -xzf "$OUT/control.before.tar.gz"; fi
  if [[ "$CFG_EXISTED" -eq 1 && -f "$OUT/config.before.tar.gz" ]]; then tar -C / -xzf "$OUT/config.before.tar.gz"; fi
  [[ "$HELPER_EXISTED" -eq 1 && -f "$OUT/helper.before" ]] && cp -a "$OUT/helper.before" "$HELPER"
  [[ "$SUDOERS_EXISTED" -eq 1 && -f "$OUT/sudoers.before" ]] && cp -a "$OUT/sudoers.before" "$SUDOERS"
  if [[ "$STATE_EXISTED" -eq 0 ]]; then rm -rf "$STATE_DIR"; fi
 fi
 if [[ -f "$SUDOERS" ]]; then visudo -cf "$SUDOERS" >/dev/null 2>&1 || fail "sudoers restaurado com erro"; fi
 if [[ "$(sha256sum /xlxd/xlxd 2>/dev/null | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] && systemctl is-active --quiet xlxd.service; then ok "Core 2.6.0 permaneceu intacto"; else fail "estado do Core precisa de inspeção"; fi
 cleanup; exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; else trap - EXIT; cleanup; exit "$rc"; fi; fi' EXIT

section "1/9 — BAIXAR FONTES IMUTÁVEIS"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$INDEX_URL" -o "$INDEX_SRC"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$HELPER_URL" -o "$HELPER_SRC"
[[ "$(git hash-object "$INDEX_SRC")" == "$INDEX_BLOB" ]] || { fail "blob index.php divergente"; exit 20; }
[[ "$(git hash-object "$HELPER_SRC")" == "$HELPER_BLOB" ]] || { fail "blob helper divergente"; exit 21; }
php -l "$INDEX_SRC"
bash -n "$HELPER_SRC"
ok "Fontes íntegras: index=$INDEX_BLOB helper=$HELPER_BLOB"

section "2/9 — BACKUP DO ESTADO ATUAL"
[[ "$CONTROL_EXISTED" -eq 1 ]] && tar -C "$WEBROOT" -czf "$OUT/control.before.tar.gz" controle
[[ "$CFG_EXISTED" -eq 1 ]] && tar -C / -czf "$OUT/config.before.tar.gz" "${CFG_DIR#/}"
[[ "$HELPER_EXISTED" -eq 1 ]] && cp -a "$HELPER" "$OUT/helper.before"
[[ "$SUDOERS_EXISTED" -eq 1 ]] && cp -a "$SUDOERS" "$OUT/sudoers.before"
sha256sum /xlxd/xlxd > "$OUT/core.before.sha256"
ok "Backup preparado em $OUT"

section "3/9 — GERAR CREDENCIAL"
PASSWORD="$(openssl rand -hex 12)"
HASH="$(printf '%s' "$PASSWORD" | php -r '$p=stream_get_contents(STDIN); echo password_hash($p, PASSWORD_DEFAULT);')"
[[ -n "$HASH" ]] || { fail "não foi possível gerar hash da senha"; exit 30; }
ok "Senha forte gerada; somente o hash será persistido"

section "4/9 — INSTALAR CONTROLE E HELPER"
MUTATED=1
mkdir -p "$CONTROL_DIR" "$CFG_DIR" "$STATE_DIR"
install -o root -g root -m 0644 "$INDEX_SRC" "$CONTROL_DIR/index.php"
install -o root -g root -m 0755 "$HELPER_SRC" "$HELPER"
chown root:"$WEBUSER" "$CFG_DIR" "$STATE_DIR"
chmod 0750 "$CFG_DIR"
chmod 0770 "$STATE_DIR"
cat > "$CFG_FILE" <<EOF
<?php
return [
 'username' => '$USERNAME',
 'password_hash' => '$HASH',
 'expected_core_sha' => '$EXPECTED_CORE_SHA',
 'expected_core_version' => '$EXPECTED_CORE_VERSION',
];
EOF
chown root:"$WEBUSER" "$CFG_FILE"; chmod 0640 "$CFG_FILE"
php -l "$CONTROL_DIR/index.php"; php -l "$CFG_FILE"
ok "Página e configuração instaladas"

section "5/9 — SUDOERS RESTRITO"
cat > "$SUDOERS" <<EOF
$WEBUSER ALL=(root) NOPASSWD: $HELPER status
$WEBUSER ALL=(root) NOPASSWD: $HELPER listeners
$WEBUSER ALL=(root) NOPASSWD: $HELPER logs
$WEBUSER ALL=(root) NOPASSWD: $HELPER backups
$WEBUSER ALL=(root) NOPASSWD: $HELPER restart
EOF
chmod 0440 "$SUDOERS"
visudo -cf "$SUDOERS"
sudo -u "$WEBUSER" sudo -n "$HELPER" status | tee "$OUT/helper-status.txt"
grep -Fxq 'service=active' "$OUT/helper-status.txt"
grep -Fxq 'version=2.6.0' "$OUT/helper-status.txt"
grep -Fxq "sha=$EXPECTED_CORE_SHA" "$OUT/helper-status.txt"
grep -Fxq 'processes=1' "$OUT/helper-status.txt"
ok "Privilégios limitados aos 5 comandos fixos"

section "6/9 — TESTAR URL E LOGIN REAL"
BODY="$TMP/public.html"; HDR="$TMP/headers.txt"
CODE="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -D "$HDR" -o "$BODY" -w '%{http_code}' "$BASE_URL/controle/")"
[[ "$CODE" == "200" ]] || { fail "/controle/ HTTP $CODE"; exit 60; }
grep -Fq 'Controle XLX026' "$BODY"; grep -Fq 'Acesso restrito' "$BODY"
grep -iq '^X-Robots-Tag:.*noindex' "$HDR" || { fail "header noindex ausente"; exit 61; }
printf 'action=login&username=%s&password=%s' "$USERNAME" "$PASSWORD" > "$POST"; chmod 0600 "$POST"
curl --silent --show-error --location --connect-timeout 8 --max-time 25 -c "$COOKIE" -b "$COOKIE" --data-binary "@$POST" "$BASE_URL/controle/" -o "$TMP/auth.html"
grep -Fq 'Integridade e testes' "$TMP/auth.html" || { fail "login automático não chegou ao painel"; exit 62; }
grep -Fq 'Reiniciar XLXD' "$TMP/auth.html" || { fail "controle de reinício ausente"; exit 63; }
rm -f "$POST" "$COOKIE"
ok "Login HTTPS real aprovado"

section "7/9 — REGRESSÃO DO PAINEL PÚBLICO"
PAGES=(/ao-vivo /conectados /suporte /aprs-dprs /ranking /certificado /simulado-anatel/ /refletores /noticias)
for path in "${PAGES[@]}"; do code="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o /dev/null -w '%{http_code}' "$BASE_URL$path")"; [[ "$code" == "200" ]] || { fail "$path HTTP $code"; exit 70; }; done
S="$(curl --silent --show-error --location -o "$TMP/status.json" -w '%{http_code}' "$BASE_URL/api/status.php")"; [[ "$S" == "200" ]] && php -r 'json_decode(file_get_contents($argv[1]),true,512,JSON_THROW_ON_ERROR);' "$TMP/status.json"
L="$(curl --silent --show-error --location -o "$TMP/live.json" -w '%{http_code}' "$BASE_URL/api/live.php")"; [[ "$L" == "200" ]] && php -r 'json_decode(file_get_contents($argv[1]),true,512,JSON_THROW_ON_ERROR);' "$TMP/live.json"
M="$(curl --silent --show-error --location -o "$TMP/mtr.json" -w '%{http_code}' "$BASE_URL/api/mtr.php")"; [[ "$M" == "400" ]] && grep -Fq 'invalid_request' "$TMP/mtr.json"
ok "9 páginas + status/live + contrato MTR preservados"

section "8/9 — CONFIRMAR CORE INALTERADO"
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "Core mudou"; exit 80; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "versão XML mudou"; exit 81; }
systemctl is-active --quiet xlxd.service || { fail "serviço ficou inativo"; exit 82; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "processos XLXD divergiram"; exit 83; }
ok "Core 2.6.0 permaneceu intacto; nenhum restart foi feito na instalação"

section "9/9 — RELATÓRIO FINAL"
INDEX_SHA="$(sha256sum "$CONTROL_DIR/index.php" | awk '{print $1}')"
HELPER_SHA="$(sha256sum "$HELPER" | awk '{print $1}')"
cat > "$OUT/CONTROL_INSTALL_COMPLETE" <<EOF
status=CONTROL_INSTALL_OK
url=$BASE_URL/controle/
username=$USERNAME
control_version=1.0.0
core_version=$EXPECTED_CORE_VERSION
core_sha=$EXPECTED_CORE_SHA
index_git_blob=$INDEX_BLOB
helper_git_blob=$HELPER_BLOB
index_sha256=$INDEX_SHA
helper_sha256=$HELPER_SHA
sudoers=$SUDOERS
state_dir=$STATE_DIR
pages_regression=9
apis_regression=status_200_live_200_mtr_400
xlxd_restart_during_install=no
backup=$OUT
EOF
cat "$OUT/CONTROL_INSTALL_COMPLETE"
SUCCESS=1; MUTATED=0; trap - EXIT; cleanup

echo
echo "======================================================================"
echo " [OK] CONTROLE XLX026 INSTALADO"
echo " URL     : $BASE_URL/controle/"
echo " Usuário : $USERNAME"
echo " Senha   : $PASSWORD"
echo "======================================================================"
echo "[ATENÇÃO] Guarde a senha agora. O servidor conserva somente o hash."
echo "[OK] Área não indexada, login protegido e restart restrito ao xlxd.service."
