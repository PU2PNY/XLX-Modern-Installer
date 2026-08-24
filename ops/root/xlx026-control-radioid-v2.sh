#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

BASE="/var/www/html/xlxd-novo"
CONTROL="$BASE/controle"
INDEX="$CONTROL/index.php"
HELPER="/usr/local/sbin/xlx026-control-helper"
SUDOERS="/etc/sudoers.d/xlx026-control"
CFG="/etc/xlx026-control/config.php"
STATE="/var/lib/xlx026-control"

CORE="/xlxd/xlxd"
CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
OLD_INDEX_BLOB="c615cb8068d5d9ce900fc193ea771642f2206e94"
OLD_HELPER_BLOB="dc78219b8a8a6fdfe6a364b2d422b5a5340e735c"

SOURCE_COMMIT="587160491ab3caf49f7663ee4ad40366ce98dbc6"
NEW_INDEX_BLOB="a617b6e359620834ffefc9d71c2632949aa6fe70"
NEW_HELPER_BLOB="2a0b62879ab91d73b746796a478ca5be4d63c2ff"
INDEX_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_COMMIT}/control/xlx026-control-index-radioid-v2.php"
HELPER_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_COMMIT}/control/xlx026-control-helper-radioid-v2"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACK="/root/backups-xlx026/XLX026_CONTROL_RADIOID_V2_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-control-radioid-v2.XXXXXX)"
NEW_INDEX="$TMP/index.php"
NEW_HELPER="$TMP/helper"
MUTATED=0
SUCCESS=0

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
cleanup(){ rm -rf "$TMP"; }
rollback(){
  local why="$1"
  trap - EXIT
  set +e
  fail "rollback automático: $why"
  [[ -f "$BACK/index.php.before" ]] && cp -a "$BACK/index.php.before" "$INDEX"
  [[ -f "$BACK/helper.before" ]] && cp -a "$BACK/helper.before" "$HELPER"
  if [[ -f "$BACK/sudoers.before" ]]; then cp -a "$BACK/sudoers.before" "$SUDOERS"; else rm -f "$SUDOERS"; fi
  [[ -f "$SUDOERS" ]] && visudo -cf "$SUDOERS" >/dev/null 2>&1 || true
  cleanup
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; else cleanup; fi' EXIT

section "XLX026 — CONTROLE v1.1.0 — INDICATIVOS & RADIOID"
[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl git php python3 sqlite3 flock visudo sudo systemctl sha256sum stat grep; do command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }; done

section "1/8 — PRÉ-CHECAGEM"
[[ -x "$CORE" && -f "$INDEX" && -x "$HELPER" && -f "$CFG" ]] || { fail "Controle/Core incompleto"; exit 3; }
[[ "$(sha256sum "$CORE"|awk '{print $1}')" == "$CORE_SHA" ]] || { fail "SHA do Core divergente"; exit 4; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está ativo"; exit 5; }
[[ "$(pgrep -x xlxd|wc -l)" -eq 1 ]] || { fail "quantidade inesperada de processos xlxd"; exit 6; }
CUR_INDEX="$(git hash-object "$INDEX")"
CUR_HELPER="$(git hash-object "$HELPER")"
echo "index_blob_atual=$CUR_INDEX"
echo "helper_blob_atual=$CUR_HELPER"
[[ "$CUR_INDEX" == "$OLD_INDEX_BLOB" ]] || { fail "index.php não é o baseline v1.0.0 esperado; nada alterado"; exit 7; }
[[ "$CUR_HELPER" == "$OLD_HELPER_BLOB" ]] || { fail "helper não é o baseline esperado; nada alterado"; exit 8; }
[[ -f /xlxd/users_db/reflector_user_manager.sh ]] || { fail "reflector_user_manager.sh não encontrado"; exit 9; }
[[ -f /xlxd/users_db/users_base.csv ]] || { fail "users_base.csv não encontrado"; exit 10; }
[[ -f /xlxd/users_db/create_user_db.php ]] || { fail "create_user_db.php não encontrado"; exit 11; }
ok "baseline atual e arquivos RadioID aprovados"

section "2/8 — DOWNLOAD IMUTÁVEL"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$INDEX_URL" -o "$NEW_INDEX"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$HELPER_URL" -o "$NEW_HELPER"
[[ "$(git hash-object "$NEW_INDEX")" == "$NEW_INDEX_BLOB" ]] || { fail "blob do novo index divergente"; exit 12; }
[[ "$(git hash-object "$NEW_HELPER")" == "$NEW_HELPER_BLOB" ]] || { fail "blob do novo helper divergente"; exit 13; }
php -l "$NEW_INDEX" >/dev/null
bash -n "$NEW_HELPER"
grep -Fq "const CTRL_VER='1.1.0'" "$NEW_INDEX"
grep -Fq 'Indicativos &amp; RadioID' "$NEW_INDEX"
grep -Fq 'radioid-refresh' "$NEW_HELPER"
! grep -Eq 'eval |bash -c|sh -c|NOPASSWD:[[:space:]]*ALL' "$NEW_INDEX" "$NEW_HELPER"
ok "fontes novas íntegras e sintaxe aprovada"

section "3/8 — BACKUP"
install -d -m 0700 "$BACK"
cp -a "$INDEX" "$BACK/index.php.before"
cp -a "$HELPER" "$BACK/helper.before"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACK/sudoers.before"
cp -a "$CFG" "$BACK/config.php.before"
[[ -d "$STATE" ]] && tar -C / -czf "$BACK/state.before.tar.gz" "${STATE#/}"
sha256sum "$INDEX" "$HELPER" "$CORE" > "$BACK/SHA256_BEFORE.txt"
ok "backup=$BACK"

section "4/8 — PUBLICAR CONTROLE"
MUTATED=1
install -o root -g root -m 0644 "$NEW_INDEX" "$INDEX"
install -o root -g root -m 0755 "$NEW_HELPER" "$HELPER"
php -l "$INDEX" >/dev/null
bash -n "$HELPER"
ok "Controle visual RadioID publicado"

section "5/8 — SUDOERS RESTRITO"
cat > "$SUDOERS" <<'EOF'
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper status
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper listeners
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper logs
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper backups
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper restart
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper radioid-status
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper radioid-check
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper radioid-refresh
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper radioid-search *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper radioid-save *
www-data ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-control-helper radioid-delete *
EOF
chmod 0440 "$SUDOERS"
visudo -cf "$SUDOERS" >/dev/null
! grep -Eq 'NOPASSWD:[[:space:]]*ALL' "$SUDOERS"
ok "sudoers limitado ao helper validado"

section "6/8 — TESTES DO HELPER"
sudo -u www-data sudo -n "$HELPER" status > "$TMP/status.txt"
grep -Fxq 'service=active' "$TMP/status.txt"
grep -Fxq 'version=2.6.0' "$TMP/status.txt"
grep -Fxq "sha=$CORE_SHA" "$TMP/status.txt"
grep -Fxq 'processes=1' "$TMP/status.txt"
sudo -u www-data sudo -n "$HELPER" radioid-status > "$TMP/radio.json"
python3 - "$TMP/radio.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
assert x.get('ok') is True
assert isinstance(x.get('records'),int) and x['records']>0
assert x.get('csv',{}).get('exists') is True
assert x.get('generator_exists') is True
print('radioid_records='+str(x['records']))
print('radioid_integrity='+str(x.get('integrity')))
PY
sudo -u www-data sudo -n "$HELPER" radioid-search callsign PU2PNY > "$TMP/search.json"
python3 - "$TMP/search.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
assert x.get('ok') is True and isinstance(x.get('rows'),list)
print('search_count='+str(x.get('count',0)))
PY
ok "status e pesquisa RadioID aprovados sem alterar a base"

section "7/8 — TESTE WEB E CORE"
HTTP="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$TMP/login.html" -w '%{http_code}' https://xlx026.net/controle/)"
echo "controle_http=$HTTP"
[[ "$HTTP" == 200 ]]
grep -Fq 'Controle XLX026' "$TMP/login.html"
grep -Fq 'Acesso restrito' "$TMP/login.html"
[[ "$(sha256sum "$CORE"|awk '{print $1}')" == "$CORE_SHA" ]]
systemctl is-active --quiet xlxd.service
[[ "$(pgrep -x xlxd|wc -l)" -eq 1 ]]
ok "login público, Core e serviço preservados"

section "8/8 — RELATÓRIO"
NEW_INDEX_NOW="$(git hash-object "$INDEX")"
NEW_HELPER_NOW="$(git hash-object "$HELPER")"
[[ "$NEW_INDEX_NOW" == "$NEW_INDEX_BLOB" ]]
[[ "$NEW_HELPER_NOW" == "$NEW_HELPER_BLOB" ]]
cat > "$BACK/CONTROL_RADIOID_V2_COMPLETE" <<EOF
status=CONTROL_RADIOID_V2_OK
control_version=1.1.0
url=https://xlx026.net/controle/
index_blob=$NEW_INDEX_NOW
helper_blob=$NEW_HELPER_NOW
core_sha=$CORE_SHA
xlxd_restart=no
radioid_source=/xlxd/users_db/users_base.csv
radioid_sql=/xlxd/users_db/users.db
radioid_manager=/xlxd/users_db/reflector_user_manager.sh
backup=$BACK
EOF
cat "$BACK/CONTROL_RADIOID_V2_COMPLETE"
SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
section "[OK] CONTROLE XLX026 v1.1.0 — RADIOID FINALIZADO"
echo "URL: https://xlx026.net/controle/"
echo "XLXD não foi reiniciado."
