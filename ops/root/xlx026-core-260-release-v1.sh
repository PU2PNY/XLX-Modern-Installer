#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

EXPECTED_OLD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"
EXPECTED_OLD_VERSION="2.5.3"
EXPECTED_NEW_VERSION="2.6.0"
EXPECTED_UPSTREAM="a79a3bf8d883bd35911a34648d71e6980726b4e8"
BACKUP_ROOT="/root/backups-xlx026"
PROD_BIN="/xlxd/xlxd"
PROD_SRC="/usr/src/xlxd"
BASE_URL="https://xlx026.net"
SERVICE="xlxd.service"
FINALIZER="/usr/local/sbin/xlx026-core-260-candidate-finalize-v1"
PRECHECK="/usr/local/sbin/xlx026-core-260-prepublish-v1"

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
get_kv(){ awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk cp curl date diff df find git grep head install journalctl mv pgrep python3 rm sed sha256sum sleep sort ss stat systemctl tail tar tee wc xargs; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -x "$FINALIZER" ]] || { fail "finalizador local ausente"; exit 3; }
[[ -x "$PRECHECK" ]] || { fail "pré-publicação local ausente"; exit 4; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_CORE_260_RELEASE_${STAMP}"
mkdir -p "$OUT/http"
chmod 700 "$OUT" "$OUT/http"
exec > >(tee "$OUT/execution.log") 2>&1

MUTATED=0
SOURCE_MUTATED=0
SUCCESS=0
OLD_SRC_RENAMED=""
TMP_BIN=""
TMP_SRC=""

capture_xlxd_listeners(){
  local out="$1"
  ss -H -lunp 2>/dev/null | awk '/xlxd/ {print $4}' | sort -u > "$out"
}

http_matrix(){
  local phase="$1" dir="$2"
  mkdir -p "$dir"
  local pages=("/ao-vivo" "/conectados" "/suporte" "/aprs-dprs" "/ranking" "/certificado" "/simulado-anatel/" "/refletores" "/noticias")
  local apis=("/api/status.php" "/api/live.php" "/api/mtr.php")
  : > "$dir/pages.tsv"; : > "$dir/apis.tsv"
  local path safe body code bytes
  for path in "${pages[@]}"; do
    safe="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
    body="$dir/page${safe}.html"
    code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || return 1
    [[ "$code" == "200" ]] || return 1
    bytes="$(wc -c < "$body")"; [[ "$bytes" -ge 500 ]] || return 1
    printf '%s\t%s\t%s\n' "$path" "$code" "$bytes" >> "$dir/pages.tsv"
  done
  for path in "${apis[@]}"; do
    safe="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
    body="$dir/api${safe}.json"
    code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || return 1
    [[ "$code" == "200" ]] || return 1
    python3 - "$body" <<'PY'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: json.load(f)
PY
    bytes="$(wc -c < "$body")"
    printf '%s\t%s\t%s\n' "$path" "$code" "$bytes" >> "$dir/apis.tsv"
  done
  ok "$phase: 9 páginas e 3 APIs aprovadas"
}

rollback(){
  local why="$1"
  trap - EXIT
  set +e
  fail "ROLLBACK AUTOMÁTICO: $why"

  if [[ "$SOURCE_MUTATED" -eq 1 && -n "$OLD_SRC_RENAMED" && -d "$OLD_SRC_RENAMED" ]]; then
    rm -rf "$PROD_SRC" 2>/dev/null || true
    mv "$OLD_SRC_RENAMED" "$PROD_SRC" 2>/dev/null || true
  fi

  if [[ "$MUTATED" -eq 1 && -f "$OUT/production-xlxd.before" ]]; then
    cp -a "$OUT/production-xlxd.before" "/xlxd/.xlxd.rollback-${STAMP}" 2>/dev/null || true
    mv -f "/xlxd/.xlxd.rollback-${STAMP}" "$PROD_BIN" 2>/dev/null || true
    systemctl restart "$SERVICE" 2>/dev/null || true
    for _ in {1..35}; do
      if systemctl is-active --quiet "$SERVICE" && \
         [[ "$(sha256sum "$PROD_BIN" 2>/dev/null | awk '{print $1}')" == "$EXPECTED_OLD_SHA" ]] && \
         [[ "$(xml_version)" == "$EXPECTED_OLD_VERSION" ]]; then
        break
      fi
      sleep 1
    done
  fi

  local current_sha current_ver
  current_sha="$(sha256sum "$PROD_BIN" 2>/dev/null | awk '{print $1}')"
  current_ver="$(xml_version)"
  if systemctl is-active --quiet "$SERVICE" && [[ "$current_sha" == "$EXPECTED_OLD_SHA" ]] && [[ "$current_ver" == "$EXPECTED_OLD_VERSION" ]]; then
    cat > "$OUT/ROLLBACK_COMPLETE" <<EOF
status=ROLLBACK_OK
reason=$why
production_sha=$current_sha
production_xml_version=$current_ver
xlxd_service=ACTIVE
EOF
    ok "Rollback confirmado: XLXD 2.5.3 restaurado e ativo"
  else
    cat > "$OUT/ROLLBACK_FAILED" <<EOF
status=ROLLBACK_FAILED
reason=$why
production_sha=$current_sha
production_xml_version=$current_ver
EOF
    fail "rollback não pôde ser confirmado automaticamente"
  fi
  exit 90
}

trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 || $SOURCE_MUTATED -eq 1 ]]; then rollback "falha inesperada rc=$rc"; else trap - EXIT; exit "$rc"; fi; fi' EXIT

section "1/11 — CANDIDATO FINALIZADO"
LATEST_CAND="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name CANDIDATE_COMPLETE -path '*XLX026_CORE_260_CANDIDATE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
if [[ -z "$LATEST_CAND" ]]; then
  "$FINALIZER"
  LATEST_CAND="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name CANDIDATE_COMPLETE -path '*XLX026_CORE_260_CANDIDATE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
fi
[[ -n "$LATEST_CAND" && -f "$LATEST_CAND" ]] || { fail "candidato finalizado não localizado"; exit 10; }
[[ "$(get_kv "$LATEST_CAND" status)" == "CANDIDATE_STATIC_OK" ]] || { fail "candidato não aprovado"; exit 11; }
ok "Candidato finalizado localizado"

section "2/11 — PRÉ-PUBLICAÇÃO FAIL-CLOSED"
"$PRECHECK"
PRE_MARK="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name PREPUBLISH_COMPLETE -path '*XLX026_PREPUBLISH_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$PRE_MARK" && -f "$PRE_MARK" ]] || { fail "PREPUBLISH_COMPLETE não localizado"; exit 20; }
[[ "$(get_kv "$PRE_MARK" status)" == "PREPUBLISH_OK" ]] || { fail "pré-publicação não aprovada"; exit 21; }
CAND_BIN="$(get_kv "$PRE_MARK" candidate_binary)"
CAND_SHA="$(get_kv "$PRE_MARK" candidate_sha256)"
CAND_TREE="$(get_kv "$PRE_MARK" candidate_tree)"
[[ "$(get_kv "$PRE_MARK" upstream_sha)" == "$EXPECTED_UPSTREAM" ]] || { fail "upstream inesperado"; exit 22; }
[[ -x "$CAND_BIN" && -d "$CAND_TREE/.git" ]] || { fail "artefatos candidatos ausentes"; exit 23; }
[[ "$(sha256sum "$CAND_BIN" | awk '{print $1}')" == "$CAND_SHA" ]] || { fail "SHA candidato mudou após precheck"; exit 24; }
[[ "$(sha256sum "$PROD_BIN" | awk '{print $1}')" == "$EXPECTED_OLD_SHA" ]] || { fail "produção mudou após precheck"; exit 25; }
ok "Gate PREPUBLISH_OK confirmado"

section "3/11 — BACKUP IMEDIATO VERIFICADO"
AVAIL_KB="$(df -Pk /root | awk 'NR==2 {print $4}')"
[[ "${AVAIL_KB:-0}" -ge 1048576 ]] || { fail "menos de 1 GiB livre"; exit 30; }
cp -a "$PROD_BIN" "$OUT/production-xlxd.before"
sha256sum "$OUT/production-xlxd.before" > "$OUT/production-xlxd.before.sha256"
tar -C / -czpf "$OUT/xlxd-dir.before.tar.gz" xlxd
tar -C /usr/src -czpf "$OUT/production-source.before.tar.gz" xlxd
sha256sum "$OUT/xlxd-dir.before.tar.gz" "$OUT/production-source.before.tar.gz" > "$OUT/backups.sha256"
(cd "$OUT" && sha256sum -c production-xlxd.before.sha256 && sha256sum -c backups.sha256)
systemctl cat "$SERVICE" > "$OUT/xlxd.service.before.txt"
systemctl show "$SERVICE" -p ActiveState -p SubState -p MainPID -p FragmentPath -p ExecStart > "$OUT/xlxd.service-state.before.txt"
cp -a /var/log/xlxd.xml "$OUT/xlxd.xml.before"
LOG_LINE_BEFORE="$(wc -l < /var/log/xlx.log 2>/dev/null || echo 0)"
capture_xlxd_listeners "$OUT/listeners.before.txt"
[[ -s "$OUT/listeners.before.txt" ]] || { fail "listeners baseline vazios"; exit 31; }
http_matrix "baseline imediato" "$OUT/http/before" || { fail "baseline HTTP/API falhou"; exit 32; }
ok "Backup imediato aprovado"

section "4/11 — PREPARAR TROCA ATÔMICA"
OWNER_UID="$(stat -c '%u' "$PROD_BIN")"; OWNER_GID="$(stat -c '%g' "$PROD_BIN")"; MODE="$(stat -c '%a' "$PROD_BIN")"
TMP_BIN="/xlxd/.xlxd.release-${STAMP}"
install -o "$OWNER_UID" -g "$OWNER_GID" -m "$MODE" "$CAND_BIN" "$TMP_BIN"
[[ "$(sha256sum "$TMP_BIN" | awk '{print $1}')" == "$CAND_SHA" ]] || { fail "SHA temporário diverge"; exit 40; }
ok "Binário pronto no mesmo filesystem"

section "5/11 — PUBLICAR E REINICIAR SOMENTE XLXD"
RESTART_AT="$(date --iso-8601=seconds)"
MUTATED=1
mv -f "$TMP_BIN" "$PROD_BIN"; TMP_BIN=""
[[ "$(sha256sum "$PROD_BIN" | awk '{print $1}')" == "$CAND_SHA" ]] || { fail "SHA após publicação diverge"; exit 50; }
systemctl restart "$SERVICE"
for _ in {1..35}; do
  systemctl is-active --quiet "$SERVICE" && [[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] && break
  sleep 1
done
systemctl is-active --quiet "$SERVICE" || { fail "xlxd.service não voltou active"; exit 51; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "processos xlxd pós-restart inválidos"; exit 52; }
[[ "$(sha256sum "$PROD_BIN" | awk '{print $1}')" == "$CAND_SHA" ]] || { fail "binário ativo não é o candidato"; exit 53; }
ok "XLXD reiniciado com candidato"

section "6/11 — XML 2.6.0 E LISTENERS"
NEW_XML=""
for _ in {1..45}; do NEW_XML="$(xml_version)"; [[ "$NEW_XML" == "$EXPECTED_NEW_VERSION" ]] && break; sleep 1; done
[[ "$NEW_XML" == "$EXPECTED_NEW_VERSION" ]] || { fail "XML não passou para 2.6.0: $NEW_XML"; exit 60; }
cp -a /var/log/xlxd.xml "$OUT/xlxd.xml.after"
for _ in {1..30}; do
  capture_xlxd_listeners "$OUT/listeners.after.txt"
  diff -u "$OUT/listeners.before.txt" "$OUT/listeners.after.txt" > "$OUT/listeners.diff.txt" && break
  sleep 1
done
diff -u "$OUT/listeners.before.txt" "$OUT/listeners.after.txt" > "$OUT/listeners.diff.txt" || { cat "$OUT/listeners.diff.txt"; fail "listeners UDP mudaram"; exit 61; }
if grep -Eq '(^|:)17000$' "$OUT/listeners.after.txt"; then fail "porta M17 17000 apareceu"; exit 62; fi
ok "XML 2.6.0 e listeners preservados"

section "7/11 — LOGS NOVOS SEM ERRO CRÍTICO"
journalctl -u "$SERVICE" --since "$RESTART_AT" --no-pager > "$OUT/xlxd.journal.after.txt" 2>&1 || true
if [[ "$LOG_LINE_BEFORE" =~ ^[0-9]+$ ]]; then sed -n "$((LOG_LINE_BEFORE+1)),\$p" /var/log/xlx.log > "$OUT/xlx.log.new.after.txt" 2>/dev/null || true; fi
if grep -Eqi 'Address already in use|bind[^[:alnum:]]+failed|segmentation fault|core dumped|terminate called|fatal error' "$OUT/xlxd.journal.after.txt" "$OUT/xlx.log.new.after.txt" 2>/dev/null; then
  fail "erro crítico detectado após restart"; exit 70
fi
ok "Sem erro crítico novo"

section "8/11 — REGRESSÃO HTTP/APIS"
http_matrix "pós-publicação" "$OUT/http/after" || { fail "regressão HTTP/API"; exit 80; }

section "9/11 — SINCRONIZAR FONTE"
TMP_SRC="/usr/src/.xlxd-release-${STAMP}"
OLD_SRC_RENAMED="/usr/src/xlxd.pre-${STAMP}"
rm -rf "$TMP_SRC" "$OLD_SRC_RENAMED"
cp -a "$CAND_TREE" "$TMP_SRC"
[[ "$(git -C "$TMP_SRC" rev-parse HEAD)" == "$EXPECTED_UPSTREAM" ]] || { fail "HEAD da fonte temporária diverge"; exit 90; }
grep -Eq '^#define[[:space:]]+VERSION_MAJOR[[:space:]]+2$' "$TMP_SRC/src/main.h"
grep -Eq '^#define[[:space:]]+VERSION_MINOR[[:space:]]+6$' "$TMP_SRC/src/main.h"
grep -Eq '^#define[[:space:]]+VERSION_REVISION[[:space:]]+0$' "$TMP_SRC/src/main.h"
grep -Eq '^#define[[:space:]]+NB_OF_PROTOCOLS[[:space:]]+9$' "$TMP_SRC/src/main.h"
SOURCE_MUTATED=1
mv "$PROD_SRC" "$OLD_SRC_RENAMED"
mv "$TMP_SRC" "$PROD_SRC"; TMP_SRC=""
[[ "$(git -C "$PROD_SRC" rev-parse HEAD)" == "$EXPECTED_UPSTREAM" ]] || { fail "HEAD da fonte publicada diverge"; exit 91; }
git -C "$PROD_SRC" status --short --branch > "$OUT/production-source.after.txt"
git -C "$PROD_SRC" diff -- src/main.h src/cprotocols.cpp src/creflector.cpp src/makefile > "$OUT/production-source.scope.patch"
ok "Fonte sincronizada; árvore anterior preservada em $OLD_SRC_RENAMED"

section "10/11 — VALIDAÇÃO FINAL"
systemctl is-active --quiet "$SERVICE" || { fail "serviço inativo no final"; exit 100; }
[[ "$(sha256sum "$PROD_BIN" | awk '{print $1}')" == "$CAND_SHA" ]] || { fail "SHA final diverge"; exit 101; }
[[ "$(xml_version)" == "$EXPECTED_NEW_VERSION" ]] || { fail "XML final não é 2.6.0"; exit 102; }
capture_xlxd_listeners "$OUT/listeners.final.txt"
diff -u "$OUT/listeners.before.txt" "$OUT/listeners.final.txt" > "$OUT/listeners.final.diff.txt" || { fail "listeners finais divergiram"; exit 103; }
http_matrix "validação final" "$OUT/http/final" || { fail "painel/APIs falharam no final"; exit 104; }
ok "Core 2.6.0 validado"

section "11/11 — RELATÓRIO E ROLLBACK PRESERVADO"
find "$OUT" -type f ! -name execution.log ! -name RELEASE_COMPLETE ! -name RELEASE-MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > "$OUT/RELEASE-MANIFEST.sha256"
cat > "$OUT/RELEASE_COMPLETE" <<EOF
status=RELEASE_OK
path=$OUT
old_version=$EXPECTED_OLD_VERSION
new_version=$EXPECTED_NEW_VERSION
old_binary_sha=$EXPECTED_OLD_SHA
new_binary_sha=$CAND_SHA
upstream_sha=$EXPECTED_UPSTREAM
xlxd_service=ACTIVE
listeners_preserved=yes
panel_pages_ok=9
critical_apis_ok=3
production_source=$PROD_SRC
old_source_rollback_tree=$OLD_SRC_RENAMED
binary_rollback_copy=$OUT/production-xlxd.before
xlxd_backup=$OUT/xlxd-dir.before.tar.gz
source_backup=$OUT/production-source.before.tar.gz
EOF
chmod 600 "$OUT/RELEASE_COMPLETE" "$OUT/RELEASE-MANIFEST.sha256"
cat "$OUT/RELEASE_COMPLETE"
SUCCESS=1; MUTATED=0; SOURCE_MUTATED=0
trap - EXIT
ok "XLX026 CORE 2.6.0 PUBLICADO E VALIDADO — rollback preservado"
