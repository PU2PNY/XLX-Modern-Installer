#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

BASE="/var/www/html/xlxd-novo"
INDEX="$BASE/controle/index.php"
HELPER="/usr/local/sbin/xlx026-control-helper"
CORE_HELPER="/usr/local/sbin/xlx026-control-helper-core-v110"
RADIO_HELPER="/usr/local/sbin/xlx026-radioid-helper-v111"
SUDOERS="/etc/sudoers.d/xlx026-control"
CFG="/etc/xlx026-control/config.php"
STATE="/var/lib/xlx026-control"
CORE="/xlxd/xlxd"

CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
OLD_INDEX_BLOB="a617b6e359620834ffefc9d71c2632949aa6fe70"
OLD_HELPER_BLOB="a40de58d5359d1d2f4250a22fcd884cde59f6477"
NEW_INDEX_BLOB="6e7c5a8abf9ae91945ca2481c0f53fb55ad85bfa"
RADIO_BLOB="efeede5601331788a9f90d7f794d37c9ff584f6d"
DISPATCH_BLOB="949a9f9deb561fc129062d3762e51198f89b38c7"
PATCHER_BLOB="297c3d3e0ddb31bebaef2a5f2f4b6b34a44d9317"

RADIO_COMMIT="9dac9cdf588efe2ee63db36464f1e9e29b4340f6"
DISPATCH_COMMIT="a448c2eb844e4a9ae3c19dbaef3a4a958a6ae9c9"
PATCHER_COMMIT="6fcc7d4657d22ca18c6ecfd01725f6d6befdaa40"
RADIO_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${RADIO_COMMIT}/control/xlx026-radioid-helper-v111"
DISPATCH_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${DISPATCH_COMMIT}/control/xlx026-control-dispatch-v111"
PATCHER_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${PATCHER_COMMIT}/control/patch-xlx026-control-v111.py"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACK="/root/backups-xlx026/XLX026_CONTROL_RADIOID_V111_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-control-v111.XXXXXX)"
CANDIDATE="$TMP/index.php"
RADIO_SRC="$TMP/radio-helper"
DISPATCH_SRC="$TMP/dispatch"
PATCHER="$TMP/patcher.py"
MUTATED=0
SUCCESS=0

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
cleanup(){ rm -rf "$TMP"; }
restore_optional(){
  local live="$1" saved="$2" existed="$3"
  if [[ -f "$existed" && "$(cat "$existed")" == yes && -f "$saved" ]]; then cp -a "$saved" "$live"; else rm -f "$live"; fi
}
rollback(){
  local why="$1"
  trap - EXIT
  set +e
  fail "rollback automático: $why"
  [[ -f "$BACK/index.php.before" ]] && cp -a "$BACK/index.php.before" "$INDEX"
  [[ -f "$BACK/helper.before" ]] && cp -a "$BACK/helper.before" "$HELPER"
  restore_optional "$CORE_HELPER" "$BACK/core-helper.before" "$BACK/core-helper.existed"
  restore_optional "$RADIO_HELPER" "$BACK/radio-helper.before" "$BACK/radio-helper.existed"
  [[ -f "$SUDOERS" ]] && visudo -cf "$SUDOERS" >/dev/null 2>&1 || true
  cleanup
  echo "[ATENÇÃO] Estado anterior do Controle restaurado."
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; else cleanup; fi' EXIT

section "XLX026 — CONTROLE v1.1.1 — CORREÇÃO RADIOID ATÔMICA"
[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl git php python3 sqlite3 flock visudo sudo systemctl sha256sum grep stat; do command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }; done

section "1/9 — PRÉ-CHECAGEM SEM ALTERAÇÃO"
[[ -f "$INDEX" && -x "$HELPER" && -f "$CFG" && -f "$SUDOERS" && -x "$CORE" ]] || { fail "Controle/Core incompleto"; exit 3; }
[[ "$(git hash-object "$INDEX")" == "$OLD_INDEX_BLOB" ]] || { fail "index.php não é o Controle v1.1.0 esperado; nada alterado"; exit 4; }
[[ "$(git hash-object "$HELPER")" == "$OLD_HELPER_BLOB" ]] || { fail "helper atual divergiu do baseline v1.1.0; nada alterado"; exit 5; }
[[ "$(sha256sum "$CORE"|awk '{print $1}')" == "$CORE_SHA" ]] || { fail "SHA do Core divergente; nada alterado"; exit 6; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está ativo"; exit 7; }
[[ "$(pgrep -x xlxd|wc -l)" -eq 1 ]] || { fail "quantidade inesperada de processos xlxd"; exit 8; }
[[ -f /xlxd/users_db/users_base.csv && -f /xlxd/users_db/users.db && -f /xlxd/users_db/create_user_db.php && -f /xlxd/users_db/reflector_user_manager.sh ]] || { fail "arquivos RadioID incompletos"; exit 9; }
[[ "$(sqlite3 /xlxd/users_db/users.db 'PRAGMA integrity_check;' 2>/dev/null || true)" == ok ]] || { fail "users.db atual não está íntegro; nada alterado"; exit 10; }
visudo -cf "$SUDOERS" >/dev/null
for action in status listeners logs backups restart radioid-status radioid-check radioid-refresh; do grep -Fq "/usr/local/sbin/xlx026-control-helper $action" "$SUDOERS" || { fail "sudoers não contém ação esperada: $action"; exit 11; }; done
for action in radioid-search radioid-save radioid-delete; do grep -Fq "/usr/local/sbin/xlx026-control-helper $action *" "$SUDOERS" || { fail "sudoers não contém ação parametrizada esperada: $action"; exit 12; }; done
! grep -Eq 'NOPASSWD:[[:space:]]*ALL' "$SUDOERS" || { fail "sudoers amplo detectado"; exit 13; }
ok "Controle v1.1.0, Core e base RadioID íntegros"

section "2/9 — DOWNLOAD IMUTÁVEL"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$RADIO_URL" -o "$RADIO_SRC"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$DISPATCH_URL" -o "$DISPATCH_SRC"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$PATCHER_URL" -o "$PATCHER"
[[ "$(git hash-object "$RADIO_SRC")" == "$RADIO_BLOB" ]] || { fail "blob RadioID divergente"; exit 14; }
[[ "$(git hash-object "$DISPATCH_SRC")" == "$DISPATCH_BLOB" ]] || { fail "blob dispatcher divergente"; exit 15; }
[[ "$(git hash-object "$PATCHER")" == "$PATCHER_BLOB" ]] || { fail "blob patcher divergente"; exit 16; }
bash -n "$RADIO_SRC"
bash -n "$DISPATCH_SRC"
python3 -m py_compile "$PATCHER"
! grep -Eq 'eval |bash -c|sh -c|NOPASSWD:[[:space:]]*ALL' "$RADIO_SRC" "$DISPATCH_SRC" || { fail "padrão inseguro detectado"; exit 17; }
ok "fontes imutáveis e sintaxe aprovadas"

section "3/9 — GERAR INDEX v1.1.1 EM CÓPIA"
cp -a "$INDEX" "$CANDIDATE"
python3 "$PATCHER" "$CANDIDATE"
php -l "$CANDIDATE" >/dev/null
CANDIDATE_BLOB="$(git hash-object "$CANDIDATE")"
echo "index_blob_candidato=$CANDIDATE_BLOB"
[[ "$CANDIDATE_BLOB" == "$NEW_INDEX_BLOB" ]] || { fail "index v1.1.1 gerado divergiu do hash esperado"; exit 18; }
grep -Fq "const CTRL_VER='1.1.1'" "$CANDIDATE"
grep -Fq 'function helper_reason' "$CANDIDATE"
grep -Fq 'sincronização atômica' "$CANDIDATE"
ok "index v1.1.1 determinístico aprovado"

section "4/9 — BACKUP"
install -d -m 0700 "$BACK"
cp -a "$INDEX" "$BACK/index.php.before"
cp -a "$HELPER" "$BACK/helper.before"
cp -a "$SUDOERS" "$BACK/sudoers.before"
cp -a "$CFG" "$BACK/config.php.before"
[[ -d "$STATE" ]] && tar -C / -czf "$BACK/state.before.tar.gz" "${STATE#/}"
if [[ -e "$CORE_HELPER" ]]; then echo yes >"$BACK/core-helper.existed"; cp -a "$CORE_HELPER" "$BACK/core-helper.before"; else echo no >"$BACK/core-helper.existed"; fi
if [[ -e "$RADIO_HELPER" ]]; then echo yes >"$BACK/radio-helper.existed"; cp -a "$RADIO_HELPER" "$BACK/radio-helper.before"; else echo no >"$BACK/radio-helper.existed"; fi
sha256sum "$INDEX" "$HELPER" "$SUDOERS" "$CFG" "$CORE" /xlxd/users_db/users_base.csv /xlxd/users_db/users.db >"$BACK/SHA256_BEFORE.txt"
ok "backup=$BACK"

section "5/9 — PUBLICAR SOMENTE O CONTROLE"
MUTATED=1
install -o root -g root -m 0755 "$HELPER" "$CORE_HELPER"
[[ "$(git hash-object "$CORE_HELPER")" == "$OLD_HELPER_BLOB" ]]
install -o root -g root -m 0755 "$RADIO_SRC" "$RADIO_HELPER"
install -o root -g root -m 0755 "$DISPATCH_SRC" "$HELPER"
install -o root -g root -m 0644 "$CANDIDATE" "$INDEX"
[[ "$(git hash-object "$RADIO_HELPER")" == "$RADIO_BLOB" ]]
[[ "$(git hash-object "$HELPER")" == "$DISPATCH_BLOB" ]]
[[ "$(git hash-object "$INDEX")" == "$NEW_INDEX_BLOB" ]]
bash -n "$CORE_HELPER"
bash -n "$RADIO_HELPER"
bash -n "$HELPER"
php -l "$INDEX" >/dev/null
ok "Controle v1.1.1 publicado; banco RadioID não foi modificado"

section "6/9 — BARREIRA DE PRIVILÉGIO"
visudo -cf "$SUDOERS" >/dev/null
sudo -u www-data sudo -n "$HELPER" status >"$TMP/status.txt"
grep -Fxq 'service=active' "$TMP/status.txt"
grep -Fxq 'version=2.6.0' "$TMP/status.txt"
grep -Fxq "sha=$CORE_SHA" "$TMP/status.txt"
grep -Fxq 'processes=1' "$TMP/status.txt"
if sudo -u www-data sudo -n "$CORE_HELPER" status >/dev/null 2>&1; then fail "core-helper ficou acessível diretamente via sudo"; exit 19; fi
if sudo -u www-data sudo -n "$RADIO_HELPER" radioid-status >/dev/null 2>&1; then fail "radio-helper ficou acessível diretamente via sudo"; exit 20; fi
if sudo -u www-data sudo -n "$HELPER" shell >/dev/null 2>&1; then fail "dispatcher aceitou ação não permitida"; exit 21; fi
ok "somente o dispatcher autorizado pode elevar privilégios"

section "7/9 — TESTES RADIOID SOMENTE LEITURA"
CSV_BEFORE="$(sha256sum /xlxd/users_db/users_base.csv|awk '{print $1}')"
DB_BEFORE="$(sha256sum /xlxd/users_db/users.db|awk '{print $1}')"
sudo -u www-data sudo -n "$HELPER" radioid-status >"$TMP/radio-status.json"
sudo -u www-data sudo -n "$HELPER" radioid-search callsign PU2PNY >"$TMP/radio-search.json"
python3 - "$TMP/radio-status.json" "$TMP/radio-search.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1],encoding='utf-8'))
q=json.load(open(sys.argv[2],encoding='utf-8'))
assert s.get('ok') is True and s.get('integrity') == 'ok'
assert isinstance(s.get('records'),int) and s['records'] > 0
assert q.get('ok') is True and isinstance(q.get('rows'),list)
print('radioid_records='+str(s['records']))
print('pu2pny_matches='+str(q.get('count',0)))
PY
[[ "$(sha256sum /xlxd/users_db/users_base.csv|awk '{print $1}')" == "$CSV_BEFORE" ]]
[[ "$(sha256sum /xlxd/users_db/users.db|awk '{print $1}')" == "$DB_BEFORE" ]]
ok "status/pesquisa aprovados e hashes da base permaneceram iguais"

section "8/9 — WEB E CORE"
HTTP="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$TMP/login.html" -w '%{http_code}' https://xlx026.net/controle/)"
echo "controle_http=$HTTP"
[[ "$HTTP" == 200 ]]
grep -Fq 'Controle XLX026' "$TMP/login.html"
grep -Fq 'Acesso restrito' "$TMP/login.html"
[[ "$(sha256sum "$CORE"|awk '{print $1}')" == "$CORE_SHA" ]]
systemctl is-active --quiet xlxd.service
[[ "$(pgrep -x xlxd|wc -l)" -eq 1 ]]
ok "web, Core 2.6.0 e processo XLXD preservados"

section "9/9 — RELATÓRIO FINAL"
cat >"$BACK/CONTROL_RADIOID_V111_COMPLETE" <<EOF
status=CONTROL_RADIOID_V111_OK
control_version=1.1.1
url=https://xlx026.net/controle/
index_blob=$NEW_INDEX_BLOB
dispatch_blob=$DISPATCH_BLOB
radio_helper_blob=$RADIO_BLOB
core_helper_blob=$OLD_HELPER_BLOB
core_sha=$CORE_SHA
xlxd_restart=no
radioid_mutated_during_install=no
backup=$BACK
EOF
cat "$BACK/CONTROL_RADIOID_V111_COMPLETE"
SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
section "[OK] CONTROLE XLX026 v1.1.1 FINALIZADO"
echo "Correção: edição RadioID + sincronização SQLite atômica"
echo "URL: https://xlx026.net/controle/"
echo "XLXD não foi reiniciado."
