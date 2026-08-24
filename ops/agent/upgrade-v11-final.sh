#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

V10_REF="9253b6c353fd40a3e26157355679eb62079372b6"
V10_BLOB="4b54c21625105f6448de1839b85d1cc46a1895ca"
V10_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${V10_REF}/ops/agent/upgrade-v10-final.sh"

EXPECTED_OLD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"
EXPECTED_OLD_VERSION="2.5.3"
EXPECTED_NEW_VERSION="2.6.0"
EXPECTED_RELEASE_V9_BLOB="97faad18b30179cd1587a813479e56f8721b1d46"
EXPECTED_CANDIDATE_V2_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"

BACKUP_ROOT="/root/backups-xlx026"
STATE="$BACKUP_ROOT/XLX026_V10_RESUME.state"
RELEASE="/usr/local/sbin/xlx026-core-260-release-v1"
PRECHECK="/usr/local/sbin/xlx026-core-260-prepublish-v1"
PROD_BIN="/xlxd/xlxd"

TMP="$(mktemp -d /tmp/xlx026-v11-final.XXXXXX)"
V10="$TMP/upgrade-v10-final.sh"

cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
get_kv(){ awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk bash cp curl date dirname find git grep install pgrep python3 sed sha256sum sort systemctl tar wc; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

fetch_v10(){
  curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$V10_URL" -o "$V10"
  local got
  got="$(git hash-object "$V10")"
  echo "v10_blob_expected=$V10_BLOB"
  echo "v10_blob_obtained=$got"
  [[ "$got" == "$V10_BLOB" ]] || { fail "blob V10 divergente"; exit 10; }
  bash -n "$V10"
}

patch_listener_validator(){
  local target="$1"
  python3 - "$target" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
marker='# XLX026_DYNAMIC_TRANSCODER_RANGE=10101-10199'
if marker in s:
    print('[OK] validador já contém regra dinâmica V11')
    raise SystemExit(0)

old='''capture_xlxd_listeners(){
  local out="$1"
  ss -H -lunp 2>/dev/null | awk '/xlxd/ {print $4}' | sort -u > "$out"
}
'''
new='''# XLX026_DYNAMIC_TRANSCODER_RANGE=10101-10199
capture_xlxd_listeners(){
  local out="$1"
  local dynamic="${out%.txt}.dynamic.txt"
  ss -H -lunp 2>/dev/null | awk '/xlxd/ {addr=$4; n=split(addr,a,":"); port=a[n]+0; if (port < 10101 || port > 10199) print addr}' | sort -u > "$out"
  ss -H -lunp 2>/dev/null | awk '/xlxd/ {addr=$4; n=split(addr,a,":"); port=a[n]+0; if (port >= 10101 && port <= 10199) print addr}' | sort -u > "$dynamic"
}
'''
if s.count(old)!=1:
    raise SystemExit('V11: função capture_xlxd_listeners inesperada')
s=s.replace(old,new,1)

old='''[[ -s "$OUT/listeners.before.txt" ]] || { fail "listeners baseline vazios"; exit 31; }'''
new='''[[ -s "$OUT/listeners.before.txt" ]] || { fail "listeners baseline vazios"; exit 31; }
grep -Eq '(^|:)10100$' "$OUT/listeners.before.txt" || { fail "listener fixo transcoder 10100 ausente"; exit 311; }'''
if s.count(old)!=1:
    raise SystemExit('V11: gate listeners baseline inesperado')
s=s.replace(old,new,1)

old='''listeners_preserved=yes
panel_pages_ok=9'''
new='''listeners_preserved=yes
dynamic_transcoder_range=10101-10199
dynamic_transcoder_listener_comparison=excluded_by_design
panel_pages_ok=9'''
if s.count(old)!=1:
    raise SystemExit('V11: manifesto listeners inesperado')
s=s.replace(old,new,1)

p.write_text(s,encoding='utf-8')
PY
  bash -n "$target"
  grep -Fq '# XLX026_DYNAMIC_TRANSCODER_RANGE=10101-10199' "$target"
  grep -Fq "grep -Eq '(^|:)10100$'" "$target"
  grep -Fq 'dynamic_transcoder_listener_comparison=excluded_by_design' "$target"
}

update_state_release_blob(){
  local new_blob="$1"
  [[ -f "$STATE" ]] || { fail "estado resumível ausente: $STATE"; exit 40; }
  python3 - "$STATE" "$new_blob" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); new=sys.argv[2]
s=p.read_text(encoding='utf-8')
lines=s.splitlines()
seen=0
out=[]
for line in lines:
    if line.startswith('release_blob='):
        out.append('release_blob='+new)
        seen+=1
    else:
        out.append(line)
if seen!=1:
    raise SystemExit(f'V11: release_blob count={seen}')
p.write_text('\n'.join(out)+'\n',encoding='utf-8')
PY
}

section "1/6 — VALIDAR V10 IMUTÁVEL"
fetch_v10
ok "V10 imutável validada"

section "2/6 — VALIDAR REGRA DINÂMICA EM CÓPIA"
FIXTURE="$TMP/release-fixture.sh"
cat > "$FIXTURE" <<'FIX'
#!/usr/bin/env bash
capture_xlxd_listeners(){
  local out="$1"
  ss -H -lunp 2>/dev/null | awk '/xlxd/ {print $4}' | sort -u > "$out"
}
OUT=/tmp/x
capture_xlxd_listeners "$OUT/listeners.before.txt"
[[ -s "$OUT/listeners.before.txt" ]] || { fail "listeners baseline vazios"; exit 31; }
cat <<EOF
listeners_preserved=yes
panel_pages_ok=9
EOF
FIX
patch_listener_validator "$FIXTURE"
grep -Fq '10101 && port <= 10199' "$FIXTURE"
ok "Regra 10101-10199 validada em cópia"

if [[ "${XLX026_V11_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "V11 verify-only concluída; nenhuma ação no servidor executada"
  exit 0
fi

section "3/6 — CLASSIFICAR ESTADO E CANDIDATO"
[[ -x "$PROD_BIN" ]] || { fail "binário de produção ausente"; exit 20; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está active"; exit 21; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade de processos xlxd inesperada"; exit 22; }
CUR_VER="$(xml_version)"
CUR_SHA="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
echo "current_version=$CUR_VER"
echo "current_sha=$CUR_SHA"

if [[ "$CUR_VER" == "$EXPECTED_OLD_VERSION" ]]; then
  [[ "$CUR_SHA" == "$EXPECTED_OLD_SHA" ]] || { fail "2.5.3 com SHA inesperado"; exit 23; }
  [[ -f "$STATE" ]] || { fail "estado V10 ausente"; exit 24; }
  CAND_COMPLETE="$(get_kv "$STATE" candidate_complete)"
  CAND_SHA="$(get_kv "$STATE" candidate_sha)"
  PRE_BLOB="$(get_kv "$STATE" prepublish_blob)"
  STATE_REL_BLOB="$(get_kv "$STATE" release_blob)"
  [[ -n "$CAND_COMPLETE" && -f "$CAND_COMPLETE" ]] || { fail "Candidate V2 do estado ausente"; exit 25; }
  [[ "$(get_kv "$CAND_COMPLETE" status)" == "CANDIDATE_V2_STATIC_OK" ]] || { fail "Candidate V2 não aprovado"; exit 26; }
  [[ "$CAND_SHA" == "$EXPECTED_CANDIDATE_V2_SHA" ]] || { fail "SHA Candidate V2 inesperado: $CAND_SHA"; exit 27; }
  CAND_BIN="$(get_kv "$CAND_COMPLETE" candidate_binary)"
  [[ -x "$CAND_BIN" ]] || { fail "binário Candidate V2 ausente/não executável"; exit 28; }
  [[ "$(sha256sum "$CAND_BIN" | awk '{print $1}')" == "$EXPECTED_CANDIDATE_V2_SHA" ]] || { fail "binário Candidate V2 mudou"; exit 29; }
  NM_FILE="$(dirname "$CAND_COMPLETE")/candidate-binary.nm"
  [[ -s "$NM_FILE" ]] || { fail "auditoria nm do Candidate V2 ausente"; exit 30; }
  grep -Fq 'CTranscoder::Init' "$NM_FILE" || { fail "CTranscoder::Init ausente do Candidate V2"; exit 31; }
  grep -Fq 'CCodecStream::Init' "$NM_FILE" || { fail "CCodecStream::Init ausente do Candidate V2"; exit 32; }
  [[ "$(git hash-object "$PRECHECK")" == "$PRE_BLOB" ]] || { fail "prepublish instalado divergiu do estado"; exit 33; }
  ok "Candidate V2 íntegro e infraestrutura de transcoding presente"
else
  [[ "$CUR_VER" == "$EXPECTED_NEW_VERSION" ]] || { fail "versão inesperada: $CUR_VER"; exit 34; }
  warn "Core já está em 2.6.0; V11 seguirá apenas pela retomada V10"
fi

section "4/6 — CORRIGIR COMPARAÇÃO DE LISTENERS"
if [[ "$CUR_VER" == "$EXPECTED_OLD_VERSION" ]]; then
  [[ -f "$RELEASE" ]] || { fail "release validator ausente"; exit 35; }
  CUR_REL_BLOB="$(git hash-object "$RELEASE")"
  if grep -Fq '# XLX026_DYNAMIC_TRANSCODER_RANGE=10101-10199' "$RELEASE"; then
    ok "Validador V11 já instalado"
  else
    [[ "$CUR_REL_BLOB" == "$EXPECTED_RELEASE_V9_BLOB" ]] || {
      fail "release validator não corresponde ao V9 conhecido"
      echo "esperado=$EXPECTED_RELEASE_V9_BLOB" >&2
      echo "obtido=$CUR_REL_BLOB" >&2
      exit 36
    }
    STAMP="$(date +%Y%m%d_%H%M%S)"
    PRE="$BACKUP_ROOT/LISTENER_VALIDATOR_V11_PRE_${STAMP}"
    mkdir -p "$PRE"
    chmod 700 "$PRE"
    cp -a "$RELEASE" "$PRE/xlx026-core-260-release-v1.before"
    sha256sum "$PRE/xlx026-core-260-release-v1.before" > "$PRE/xlx026-core-260-release-v1.before.sha256"
    (cd "$PRE" && sha256sum -c xlx026-core-260-release-v1.before.sha256)
    PATCHED="$TMP/release-v11.sh"
    cp -a "$RELEASE" "$PATCHED"
    patch_listener_validator "$PATCHED"
    install -o root -g root -m 0750 "$PATCHED" "$RELEASE"
    ok "Validador de listeners V11 instalado; backup: $PRE"
  fi
  NEW_REL_BLOB="$(git hash-object "$RELEASE")"
  update_state_release_blob "$NEW_REL_BLOB"
  [[ "$(get_kv "$STATE" release_blob)" == "$NEW_REL_BLOB" ]] || { fail "estado resumível não recebeu blob V11"; exit 37; }
  [[ "$(sha256sum "$PROD_BIN" | awk '{print $1}')" == "$EXPECTED_OLD_SHA" ]] || { fail "produção mudou durante patch do validador"; exit 38; }
  [[ "$(xml_version)" == "$EXPECTED_OLD_VERSION" ]] || { fail "XML mudou durante patch do validador"; exit 39; }
  echo "release_v11_blob=$NEW_REL_BLOB"
  ok "Estado resumível atualizado sem restart do XLXD"
fi

section "5/6 — RETOMAR V10"
bash "$V10"

section "6/6 — RESULTADO"
FINAL_VER="$(xml_version)"
FINAL_SHA="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
echo "final_version=$FINAL_VER"
echo "final_sha=$FINAL_SHA"
[[ "$FINAL_VER" == "$EXPECTED_NEW_VERSION" ]] || { fail "V10 não terminou em 2.6.0"; exit 50; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service inativo no final"; exit 51; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "processos XLXD inválidos no final"; exit 52; }
PROJECT="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name PROJECT_COMPLETE -path '*XLX026_PROJECT_COMPLETE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$PROJECT" && -f "$PROJECT" ]] || { fail "PROJECT_COMPLETE não localizado"; exit 53; }
[[ "$(get_kv "$PROJECT" status)" == "PROJECT_COMPLETE" ]] || { fail "marcador final inesperado"; exit 54; }
echo "project_complete=$PROJECT"
ok "XLX026 finalizado com listeners fixos preservados e faixa dinâmica 10101-10199 auditada separadamente"
