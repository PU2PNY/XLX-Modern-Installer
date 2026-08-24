#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

WEBROOT="/var/www/html/xlxd-novo"
LIVE="$WEBROOT/api/live.php"
COMMON="$WEBROOT/api/common.php"
LOG="/var/log/xlx.log"
XML="/var/log/xlxd.xml"
BACKUP_ROOT="/root/backups-xlx026"
EXPECTED_CORE_VERSION="2.6.0"
EXPECTED_CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
BASE_URL="https://xlx026.net"
MARKER="XLX026_LOG260_COMPAT_V1"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' "$XML" 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk bash cp curl date grep install php pgrep python3 sed sha256sum stat systemctl tail wc; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -f "$LIVE" && -f "$COMMON" ]] || { fail "APIs live/common ausentes"; exit 3; }
[[ -r "$LOG" ]] || { fail "$LOG não está legível"; exit 4; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "core XML não está em 2.6.0"; exit 5; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "SHA do core 2.6.0 divergiu"; exit 6; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está active"; exit 7; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade inesperada de processos XLXD"; exit 8; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_LIVE260_HOTFIX_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-live260.XXXXXX)"
MUTATED=0
SUCCESS=0
mkdir -p "$OUT"
chmod 700 "$OUT"

cleanup(){ rm -rf "$TMP"; }
rollback(){
  local reason="$1"
  trap - EXIT
  set +e
  fail "ROLLBACK AUTOMÁTICO DO PAINEL: $reason"
  if [[ "$MUTATED" -eq 1 ]]; then
    cp -a "$OUT/live.php.before" "$LIVE" 2>/dev/null || true
    cp -a "$OUT/common.php.before" "$COMMON" 2>/dev/null || true
  fi
  local live_now common_now live_old common_old
  live_now="$(sha256sum "$LIVE" 2>/dev/null | awk '{print $1}')"
  common_now="$(sha256sum "$COMMON" 2>/dev/null | awk '{print $1}')"
  live_old="$(awk '{print $1}' "$OUT/live.php.before.sha256" 2>/dev/null)"
  common_old="$(awk '{print $1}' "$OUT/common.php.before.sha256" 2>/dev/null)"
  if [[ "$live_now" == "$live_old" && "$common_now" == "$common_old" ]]; then
    cat > "$OUT/ROLLBACK_COMPLETE" <<EOF
status=ROLLBACK_OK
reason=$reason
live_sha=$live_now
common_sha=$common_now
EOF
    ok "live.php e common.php restaurados"
  else
    fail "rollback não pôde ser confirmado"
  fi
  cleanup
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 ]]; then rollback "falha inesperada rc=$rc"; else trap - EXIT; cleanup; exit "$rc"; fi; fi' EXIT

section "1/8 — DIAGNÓSTICO E BACKUP"
php -l "$LIVE"
php -l "$COMMON"
cp -a "$LIVE" "$OUT/live.php.before"
cp -a "$COMMON" "$OUT/common.php.before"
sha256sum "$OUT/live.php.before" > "$OUT/live.php.before.sha256"
sha256sum "$OUT/common.php.before" > "$OUT/common.php.before.sha256"
(cd "$OUT" && sha256sum -c live.php.before.sha256 && sha256sum -c common.php.before.sha256)
sha256sum /xlxd/xlxd > "$OUT/core.sha256"
{
  echo "core_version=$(xml_version)"
  echo "core_sha=$(sha256sum /xlxd/xlxd | awk '{print $1}')"
  echo "live_sha_before=$(sha256sum "$LIVE" | awk '{print $1}')"
  echo "common_sha_before=$(sha256sum "$COMMON" | awk '{print $1}')"
  echo "old_live_parser_count=$(grep -Fc 'for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?' "$LIVE" || true)"
  echo "old_common_parser_count=$(grep -Fc 'for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?' "$COMMON" || true)"
} | tee "$OUT/baseline.txt"
grep 'Opening stream on module' "$LOG" | tail -20 > "$OUT/recent-opening-streams.txt" || true
ok "Backup e evidência do log gravados em $OUT"

section "2/8 — PREPARAR PATCH EM CÓPIA"
LIVE_NEW="$TMP/live.php"
COMMON_NEW="$TMP/common.php"
cp -a "$LIVE" "$LIVE_NEW"
cp -a "$COMMON" "$COMMON_NEW"

python3 - "$LIVE_NEW" "$COMMON_NEW" "$MARKER" <<'PY'
from pathlib import Path
import sys
live=Path(sys.argv[1]); common=Path(sys.argv[2]); marker=sys.argv[3]

# Compatibilidade dos logs:
# 2.5.x: Opening stream on module D for client PU2ABC A with sid 123
# 2.6.x: Opening stream on module D for PU2ABC A on/via PY2XYZ with sid 123
# Grupos preservados: 1=módulo, 2=indicativo, 3=sufixo opcional, 4=sid.
combined = r"Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)"

s=live.read_text(encoding='utf-8')
if marker not in s:
    old1=r"'for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?\s+' ."
    old2=r"'with sid\s+(\d+)/i',"
    if s.count(old1)!=1 or s.count(old2)!=1:
        raise SystemExit(f'live.php: parser esperado não é único: old1={s.count(old1)} old2={s.count(old2)}')
    new=(
        r"'for\s+(?:client\s+)?([A-Z0-9\/\-]+)' ." + "\n"
        r"            '(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?' ." + "\n"
        r"            '(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+' ."
    )
    s=s.replace(old1,new,1)
    loop="foreach ($lines as $line) {"
    if s.count(loop)!=1:
        raise SystemExit(f'live.php: foreach de log count={s.count(loop)}')
    s=s.replace(loop, f"/* {marker}: parser compatível XLXD 2.5/2.6 */\n{loop}",1)
    live.write_text(s,encoding='utf-8')

s=common.read_text(encoding='utf-8')
if marker not in s:
    old=r"Opening stream on module\s+([A-Z])\s+for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?\s+with sid\s+(\d+)"
    if s.count(old)!=1:
        raise SystemExit(f'common.php: parser esperado count={s.count(old)}')
    s=s.replace(old,combined,1)
    anchor="if(preg_match('/"+combined
    if s.count(anchor)!=1:
        raise SystemExit(f'common.php: parser novo anchor count={s.count(anchor)}')
    s=s.replace(anchor, "/* "+marker+": parser compatível XLXD 2.5/2.6 */\n        "+anchor,1)
    common.write_text(s,encoding='utf-8')
PY

php -l "$LIVE_NEW"
php -l "$COMMON_NEW"
grep -Fq "$MARKER" "$LIVE_NEW"
grep -Fq "$MARKER" "$COMMON_NEW"
grep -Fq '(?:on|via)' "$LIVE_NEW"
grep -Fq '(?:on|via)' "$COMMON_NEW"
ok "Patch preparado e sintaxe aprovada"

section "3/8 — TESTE UNITÁRIO DO REGEX"
php <<'PHP'
<?php
$p='/Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)/i';
$tests=[
 '24 Aug, 00:10:01: Opening stream on module D for client PU2ABC A with sid 1234'=>['D','PU2ABC','A','1234'],
 '24 Aug, 00:10:02: Opening stream on module C for PU2ABC on PY2XYZ with sid 2345'=>['C','PU2ABC','','2345'],
 '24 Aug, 00:10:03: Opening stream on module D for PU2ABC A via XLX999 B with sid 3456'=>['D','PU2ABC','A','3456'],
];
foreach($tests as $line=>$want){
 if(!preg_match($p,$line,$m)) { fwrite(STDERR,"[ERRO] não casou: $line\n"); exit(1); }
 $got=[$m[1]??'', $m[2]??'', $m[3]??'', $m[4]??''];
 if($got!==$want){ fwrite(STDERR,"[ERRO] grupos divergentes: ".json_encode($got)."\n"); exit(2); }
}
echo "[OK] Regex aceita XLXD 2.5, 2.6 on e 2.6 via mantendo grupos 1-4\n";
PHP

section "4/8 — TESTAR CONTRA LOG REAL"
python3 - "$LOG" <<'PY'
import re,sys
p=re.compile(r'Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)',re.I)
with open(sys.argv[1],'rb') as f:
    f.seek(0,2)
    size=f.tell()
    f.seek(max(0,size-2097152))
    raw=f.read().decode('utf-8','replace')
lines=raw.splitlines()
openings=[x for x in lines if 'Opening stream on module' in x]
matches=[x for x in openings if p.search(x)]
print(f'opening_lines_recent={len(openings)}')
print(f'opening_lines_matched={len(matches)}')
for x in matches[-5:]: print('MATCH:',x)
if openings and not matches:
    raise SystemExit('[ERRO] há linhas Opening stream recentes, mas o parser novo não reconheceu nenhuma')
PY
ok "Compatibilidade com log real aprovada"

section "5/8 — PUBLICAÇÃO ATÔMICA DAS DUAS APIS"
chown --reference="$LIVE" "$LIVE_NEW"
chmod --reference="$LIVE" "$LIVE_NEW"
chown --reference="$COMMON" "$COMMON_NEW"
chmod --reference="$COMMON" "$COMMON_NEW"
MUTATED=1
install -o "$(stat -c %u "$LIVE")" -g "$(stat -c %g "$LIVE")" -m "$(stat -c %a "$LIVE")" "$LIVE_NEW" "$LIVE"
install -o "$(stat -c %u "$COMMON")" -g "$(stat -c %g "$COMMON")" -m "$(stat -c %a "$COMMON")" "$COMMON_NEW" "$COMMON"
php -l "$LIVE"
php -l "$COMMON"
grep -Fq "$MARKER" "$LIVE"
grep -Fq "$MARKER" "$COMMON"
ok "live.php e common.php atualizados; XLXD não foi reiniciado"

section "6/8 — VALIDAR APIS"
LIVE_JSON="$TMP/live.json"
STATUS_JSON="$TMP/status.json"
LIVE_HTTP="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$LIVE_JSON" -w '%{http_code}' "$BASE_URL/api/live.php?ts=$(date +%s)")"
STATUS_HTTP="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$STATUS_JSON" -w '%{http_code}' "$BASE_URL/api/status.php?history_hours=24&ts=$(date +%s)")"
[[ "$LIVE_HTTP" == "200" ]] || { fail "live.php HTTP $LIVE_HTTP"; exit 60; }
[[ "$STATUS_HTTP" == "200" ]] || { fail "status.php HTTP $STATUS_HTTP"; exit 61; }
python3 - "$LIVE_JSON" "$STATUS_JSON" <<'PY'
import json,sys
live=json.load(open(sys.argv[1],encoding='utf-8'))
status=json.load(open(sys.argv[2],encoding='utf-8'))
if live.get('ok') is not True: raise SystemExit('[ERRO] live.php ok != true')
if not isinstance(live.get('active'),dict): raise SystemExit('[ERRO] live.active não é objeto')
if status.get('ok') is not True: raise SystemExit('[ERRO] status.php ok != true')
for k in ('modules','history','connections'):
    if k not in status: raise SystemExit(f'[ERRO] status sem {k}')
print('live_active_count=',live.get('active_count'))
print('status_active_count=',status.get('active_count'))
print('status_history_count=',len(status.get('history') or []))
print('status_connected_count=',status.get('connected_count'))
PY
ok "live/status HTTP 200 e contrato JSON aprovados"

section "7/8 — CONFIRMAR CORE E PAINEL"
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "versão do core mudou"; exit 70; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "SHA do core mudou"; exit 71; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service deixou de estar active"; exit 72; }
PAGE="$TMP/ao-vivo.html"
PAGE_HTTP="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$PAGE" -w '%{http_code}' "$BASE_URL/ao-vivo")"
[[ "$PAGE_HTTP" == "200" ]] || { fail "/ao-vivo HTTP $PAGE_HTTP"; exit 73; }
ok "Core 2.6.0 permaneceu intacto e Ao Vivo responde HTTP 200"

section "8/8 — MANIFESTO E HASHES"
LIVE_AFTER="$(sha256sum "$LIVE" | awk '{print $1}')"
COMMON_AFTER="$(sha256sum "$COMMON" | awk '{print $1}')"
cat > "$OUT/HOTFIX_COMPLETE" <<EOF
status=HOTFIX_OK
hotfix=$MARKER
core_version=$EXPECTED_CORE_VERSION
core_sha=$EXPECTED_CORE_SHA
live_sha_before=$(awk '{print $1}' "$OUT/live.php.before.sha256")
live_sha_after=$LIVE_AFTER
common_sha_before=$(awk '{print $1}' "$OUT/common.php.before.sha256")
common_sha_after=$COMMON_AFTER
live_http=200
status_http=200
xlxd_restart=no
backup=$OUT
EOF
sha256sum "$LIVE" "$COMMON" > "$OUT/production-api-after.sha256"
chmod 600 "$OUT/HOTFIX_COMPLETE" "$OUT/production-api-after.sha256"
cat "$OUT/HOTFIX_COMPLETE"
SUCCESS=1; MUTATED=0
trap - EXIT
cleanup
ok "HOTFIX AO VIVO XLXD 2.6.0 PUBLICADO — rollback preservado"
