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
BASE_URL="https://xlx026.net"
EXPECTED_CORE_VERSION="2.6.0"
EXPECTED_CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
EXPECTED_LIVE_V1_SHA="b3ffeee168612f1bedd4545f4973fe25d7c9af1342d9f8dd9176ff32d24f8d31"
EXPECTED_COMMON_V1_SHA="73508375e21a49261676c65f6e52c40baacc11b0164b10a758d8719905a97d99"
OLD_MARKER="XLX026_LOG260_COMPAT_V1"
NEW_MARKER="XLX026_LOG260_COMPAT_V2"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' "$XML" 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk cp curl date grep install php pgrep python3 sed sha256sum stat systemctl tail wc; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -f "$LIVE" && -f "$COMMON" && -r "$LOG" ]] || { fail "arquivos do painel/log ausentes"; exit 3; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "XML não está em 2.6.0"; exit 4; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "SHA do core divergiu"; exit 5; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está ativo"; exit 6; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade inesperada de processos XLXD"; exit 7; }

LIVE_SHA="$(sha256sum "$LIVE" | awk '{print $1}')"
COMMON_SHA="$(sha256sum "$COMMON" | awk '{print $1}')"
[[ "$LIVE_SHA" == "$EXPECTED_LIVE_V1_SHA" ]] || { fail "live.php não está exatamente no hotfix V1 esperado: $LIVE_SHA"; exit 8; }
[[ "$COMMON_SHA" == "$EXPECTED_COMMON_V1_SHA" ]] || { fail "common.php não está exatamente no hotfix V1 esperado: $COMMON_SHA"; exit 9; }

grep -Fq "$OLD_MARKER" "$LIVE" || { fail "marcador V1 ausente em live.php"; exit 10; }
grep -Fq "$OLD_MARKER" "$COMMON" || { fail "marcador V1 ausente em common.php"; exit 11; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_LIVE260_HOTFIX_V2_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-live260-v2.XXXXXX)"
mkdir -p "$OUT"
chmod 700 "$OUT"
MUTATED=0
SUCCESS=0

cleanup(){ rm -rf "$TMP"; }
rollback(){
  local reason="$1"
  trap - EXIT
  set +e
  fail "ROLLBACK AUTOMÁTICO DO HOTFIX V2: $reason"
  if [[ "$MUTATED" -eq 1 ]]; then
    cp -a "$OUT/live.php.before" "$LIVE" 2>/dev/null || true
    cp -a "$OUT/common.php.before" "$COMMON" 2>/dev/null || true
  fi
  local l c
  l="$(sha256sum "$LIVE" 2>/dev/null | awk '{print $1}')"
  c="$(sha256sum "$COMMON" 2>/dev/null | awk '{print $1}')"
  if [[ "$l" == "$EXPECTED_LIVE_V1_SHA" && "$c" == "$EXPECTED_COMMON_V1_SHA" ]]; then
    cat > "$OUT/ROLLBACK_COMPLETE" <<EOF
status=ROLLBACK_OK
reason=$reason
live_sha=$l
common_sha=$c
EOF
    ok "Hotfix V1 restaurado integralmente"
  else
    fail "rollback não pôde ser confirmado"
  fi
  cleanup
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 ]]; then rollback "falha inesperada rc=$rc"; else trap - EXIT; cleanup; exit "$rc"; fi; fi' EXIT

section "1/8 — BACKUP E ESTADO EXATO"
php -l "$LIVE"
php -l "$COMMON"
cp -a "$LIVE" "$OUT/live.php.before"
cp -a "$COMMON" "$OUT/common.php.before"
sha256sum "$OUT/live.php.before" > "$OUT/live.php.before.sha256"
sha256sum "$OUT/common.php.before" > "$OUT/common.php.before.sha256"
(cd "$OUT" && sha256sum -c live.php.before.sha256 && sha256sum -c common.php.before.sha256)
{
  echo "core_version=$(xml_version)"
  echo "core_sha=$EXPECTED_CORE_SHA"
  echo "live_v1_sha=$LIVE_SHA"
  echo "common_v1_sha=$COMMON_SHA"
} | tee "$OUT/baseline.txt"
tail -n 3000 "$LOG" | grep 'Opening stream on module' | tail -30 > "$OUT/opening-streams.before.txt" || true
ok "Baseline V1 confirmado e protegido"

section "2/8 — GERAR V2 EM CÓPIA"
LIVE_NEW="$TMP/live.php"
COMMON_NEW="$TMP/common.php"
cp -a "$LIVE" "$LIVE_NEW"
cp -a "$COMMON" "$COMMON_NEW"

python3 - "$LIVE_NEW" "$COMMON_NEW" "$OLD_MARKER" "$NEW_MARKER" <<'PY'
from pathlib import Path
import sys
live=Path(sys.argv[1]); common=Path(sys.argv[2]); old_marker=sys.argv[3]; new_marker=sys.argv[4]

# Mantém os grupos usados pelo PHP: 1 módulo, 2 indicativo, 3 sufixo, 4 SID.
# O protocolo / DMR, / YSF etc. é propositalmente NÃO capturante.
old_regex = r"Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)"
new_regex = r"Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s*\/\s*[A-Z0-9+_-]+)?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)"

s=live.read_text(encoding='utf-8')
if s.count(old_marker)!=1:
    raise SystemExit(f'live.php: marker V1 count={s.count(old_marker)}')
needle = r"'(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+' ."
replacement = (
    r"'(?:\s*\/\s*[A-Z0-9+_-]+)?' ." + "\n" +
    r"            '(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+' ."
)
if s.count(needle)!=1:
    raise SystemExit(f'live.php: trecho on/via count={s.count(needle)}')
s=s.replace(needle,replacement,1)
s=s.replace(old_marker,new_marker,1)
live.write_text(s,encoding='utf-8')

s=common.read_text(encoding='utf-8')
if s.count(old_marker)!=1:
    raise SystemExit(f'common.php: marker V1 count={s.count(old_marker)}')
if s.count(old_regex)!=1:
    raise SystemExit(f'common.php: regex V1 count={s.count(old_regex)}')
s=s.replace(old_regex,new_regex,1)
s=s.replace(old_marker,new_marker,1)
common.write_text(s,encoding='utf-8')
PY

php -l "$LIVE_NEW"
php -l "$COMMON_NEW"
[[ "$(grep -Fc "$NEW_MARKER" "$LIVE_NEW")" -eq 1 ]]
[[ "$(grep -Fc "$NEW_MARKER" "$COMMON_NEW")" -eq 1 ]]
grep -Fq '\s*\/\s*[A-Z0-9+_-]+' "$LIVE_NEW"
grep -Fq '\s*\/\s*[A-Z0-9+_-]+' "$COMMON_NEW"
ok "V2 preparada sem alterar produção"

section "3/8 — TESTES UNITÁRIOS DOS FORMATOS 2.5/2.6"
php <<'PHP'
<?php
$p='/Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s*\/\s*[A-Z0-9+_-]+)?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)/i';
$tests=[
 '24 Aug, 00:40:14: Opening stream on module B for client PY1RV B with sid 23427'=>['B','PY1RV','B','23427'],
 '24 Aug, 00:51:49: Opening stream on module C for PY1RO / DMR on PY1RO B with sid 15285'=>['C','PY1RO','','15285'],
 '24 Aug, 00:53:50: Opening stream on module C for PU3VVS / YSF on PU3VVS B with sid 17925'=>['C','PU3VVS','','17925'],
 '24 Aug, 00:54:21: Opening stream on module A for PU2PNY / DMR on PU2PNY B with sid 37891'=>['A','PU2PNY','','37891'],
 '24 Aug, 00:10:03: Opening stream on module D for PU2ABC A via XLX999 B with sid 3456'=>['D','PU2ABC','A','3456'],
];
foreach($tests as $line=>$want){
 if(!preg_match($p,$line,$m)){fwrite(STDERR,"[ERRO] não casou: $line\n");exit(1);}
 $got=[$m[1]??'', $m[2]??'', $m[3]??'', $m[4]??''];
 if($got!==$want){fwrite(STDERR,"[ERRO] grupos: ".json_encode($got)." esperado ".json_encode($want)."\n");exit(2);}
}
echo "[OK] 2.5 legado + 2.6 DMR + 2.6 YSF + on/via aprovados\n";
PHP

section "4/8 — PROVAR CONTRA AS ÚLTIMAS LINHAS REAIS"
python3 - "$LOG" <<'PY'
import re,sys
p=re.compile(r'Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s*\/\s*[A-Z0-9+_-]+)?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)',re.I)
with open(sys.argv[1],'rb') as f:
    f.seek(0,2); size=f.tell(); f.seek(max(0,size-4194304)); raw=f.read().decode('utf-8','replace')
openings=[x for x in raw.splitlines() if 'Opening stream on module' in x]
recent=openings[-30:]
unmatched=[x for x in recent if not p.search(x)]
print(f'opening_lines_total_window={len(openings)}')
print(f'opening_lines_recent_tested={len(recent)}')
print(f'opening_lines_recent_matched={len(recent)-len(unmatched)}')
for x in recent[-10:]:
    print(('MATCH: ' if p.search(x) else 'MISS:  ')+x)
if recent and unmatched:
    print('[ERRO] linhas recentes não reconhecidas:')
    for x in unmatched: print('MISS:',x)
    raise SystemExit(1)
PY
ok "Últimas linhas reais do XLXD reconhecidas integralmente"

section "5/8 — PUBLICAR SOMENTE LIVE/COMMON"
chown --reference="$LIVE" "$LIVE_NEW"
chmod --reference="$LIVE" "$LIVE_NEW"
chown --reference="$COMMON" "$COMMON_NEW"
chmod --reference="$COMMON" "$COMMON_NEW"
MUTATED=1
install -o "$(stat -c %u "$LIVE")" -g "$(stat -c %g "$LIVE")" -m "$(stat -c %a "$LIVE")" "$LIVE_NEW" "$LIVE"
install -o "$(stat -c %u "$COMMON")" -g "$(stat -c %g "$COMMON")" -m "$(stat -c %a "$COMMON")" "$COMMON_NEW" "$COMMON"
php -l "$LIVE"
php -l "$COMMON"
grep -Fq "$NEW_MARKER" "$LIVE"
grep -Fq "$NEW_MARKER" "$COMMON"
ok "Parser V2 publicado; XLXD não foi reiniciado"

section "6/8 — INVALIDAR APENAS CACHE DO STATUS"
# status.php usa cache de 1s. Remover arquivos JSON força reconstrução imediata,
# sem afetar banco, logs, XML ou core.
find /var/cache/xlx-dashboard -maxdepth 1 -type f -name 'status*.json' -delete 2>/dev/null || true
ok "Cache efêmero do status invalidado"

section "7/8 — VALIDAR APIS E CORE"
LIVE_JSON="$TMP/live.json"
STATUS_JSON="$TMP/status.json"
LH="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$LIVE_JSON" -w '%{http_code}' "$BASE_URL/api/live.php?ts=$(date +%s)")"
SH="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$STATUS_JSON" -w '%{http_code}' "$BASE_URL/api/status.php?history_hours=24&ts=$(date +%s)")"
[[ "$LH" == 200 && "$SH" == 200 ]] || { fail "HTTP live=$LH status=$SH"; exit 70; }
python3 - "$LIVE_JSON" "$STATUS_JSON" <<'PY'
import json,sys
live=json.load(open(sys.argv[1],encoding='utf-8')); status=json.load(open(sys.argv[2],encoding='utf-8'))
assert live.get('ok') is True
assert isinstance(live.get('active'),dict)
assert status.get('ok') is True
assert isinstance(status.get('history'),list)
assert isinstance(status.get('modules'),dict)
print('live_active_count=',live.get('active_count'))
print('status_active_count=',status.get('active_count'))
print('status_history_count=',len(status.get('history') or []))
print('status_connected_count=',status.get('connected_count'))
PY
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]]
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]]
systemctl is-active --quiet xlxd.service
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]]
ok "APIs válidas e Core 2.6.0 intacto"

section "8/8 — RELATÓRIO"
LIVE_AFTER="$(sha256sum "$LIVE" | awk '{print $1}')"
COMMON_AFTER="$(sha256sum "$COMMON" | awk '{print $1}')"
cat > "$OUT/HOTFIX_V2_COMPLETE" <<EOF
status=HOTFIX_V2_OK
hotfix=$NEW_MARKER
core_version=$EXPECTED_CORE_VERSION
core_sha=$EXPECTED_CORE_SHA
live_sha_before=$EXPECTED_LIVE_V1_SHA
live_sha_after=$LIVE_AFTER
common_sha_before=$EXPECTED_COMMON_V1_SHA
common_sha_after=$COMMON_AFTER
xlxd_restart=no
backup=$OUT
EOF
chmod 600 "$OUT/HOTFIX_V2_COMPLETE"
cat "$OUT/HOTFIX_V2_COMPLETE"
SUCCESS=1; MUTATED=0
trap - EXIT
cleanup
ok "HOTFIX V2 AO VIVO PUBLICADO — / DMR e / YSF agora reconhecidos"
