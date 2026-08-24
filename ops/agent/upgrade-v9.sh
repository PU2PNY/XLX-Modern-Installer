#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

SOURCE_REF="b4f19164471c9af9a196f0f60e78a6fb19651377"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_REF}"
EXPECTED_UPSTREAM="a79a3bf8d883bd35911a34648d71e6980726b4e8"
EXPECTED_PROD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"
EXPECTED_XML_VERSION="2.5.3"
EXPECTED_SOURCE_HEAD="1d67b5a29ca2ced01ed5683d803ff9d10eac5a64"
EXPECTED_MAINH_SHA="72a0f60786fdb7d6f3bfd02783728a5fa4f3b51867bd9d021aa2ea0deaef2fbc"
EXPECTED_MAINH_BACKUP_SHA="49902efee053ed760dd99d42b52c391f598abab8d91ef8726b2996bf0c0c2cec"
CANDIDATE_V1_BLOB="c5194e7597145e3b6f6621485108abdeec02b8e7"
PRECHECK_V8_BLOB="074499e783377cabaf11c814fce634240719efa9"
RELEASE_V8_BLOB="0cccbb4f7a3d873b3229614eb1f85a2f84de7b33"

PROD_SRC="/usr/src/xlxd"
PROD_BIN="/xlxd/xlxd"
BACKUP_ROOT="/root/backups-xlx026"
PRECHECK="/usr/local/sbin/xlx026-core-260-prepublish-v1"
RELEASE="/usr/local/sbin/xlx026-core-260-release-v1"

TMP="$(mktemp -d /tmp/xlx026-agent-v9.XXXXXX)"
PRE=""
VALIDATORS_MUTATED=0

ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

restore_validators(){
  local rc="$1"
  trap - EXIT
  set +e
  if [[ "$VALIDATORS_MUTATED" -eq 1 && -n "$PRE" && -f "$PRE/validators-pre-v9.tar.gz" ]]; then
    echo "[ATENÇÃO] Falha na V9; restaurando validadores V8..." >&2
    tar -C / -xzf "$PRE/validators-pre-v9.tar.gz" || true
  fi
  rm -rf "$TMP"
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 ]]; then restore_validators "$rc"; else rm -rf "$TMP"; fi' EXIT

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash cp curl find git grep install make nm pgrep python3 sha256sum sort systemctl tar wc; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

section_state(){
  [[ -x "$PROD_BIN" ]] || { fail "binário de produção ausente"; exit 10; }
  [[ "$(sha256sum "$PROD_BIN" | awk '{print $1}')" == "$EXPECTED_PROD_SHA" ]] || { fail "produção não está no SHA 2.5.3 aprovado"; exit 11; }
  [[ "$(xml_version)" == "$EXPECTED_XML_VERSION" ]] || { fail "XML não está em 2.5.3"; exit 12; }
  systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está active"; exit 13; }
  [[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade de processos xlxd inesperada"; exit 14; }
  [[ -d "$PROD_SRC/.git" && -f "$PROD_SRC/src/main.h" ]] || { fail "fonte de produção inválida"; exit 15; }
  [[ "$(git -C "$PROD_SRC" rev-parse HEAD)" == "$EXPECTED_SOURCE_HEAD" ]] || { fail "HEAD da fonte mudou"; exit 16; }
  [[ "$(sha256sum "$PROD_SRC/src/main.h" | awk '{print $1}')" == "$EXPECTED_MAINH_SHA" ]] || { fail "main.h local mudou desde a auditoria"; exit 17; }
  [[ -f "$PROD_SRC/src/main.h.bkp_20260703_215904" ]] || { fail "backup histórico main.h ausente"; exit 18; }
  [[ "$(sha256sum "$PROD_SRC/src/main.h.bkp_20260703_215904" | awk '{print $1}')" == "$EXPECTED_MAINH_BACKUP_SHA" ]] || { fail "backup histórico main.h mudou"; exit 19; }
  mapfile -t dirty < <(git -C "$PROD_SRC" status --porcelain | sort)
  [[ ${#dirty[@]} -eq 2 ]] || { fail "quantidade de alterações locais mudou: ${#dirty[@]}"; exit 20; }
  printf '%s\n' "${dirty[@]}" | grep -Fxq ' M src/main.h' || { fail "src/main.h não está no estado esperado"; exit 21; }
  printf '%s\n' "${dirty[@]}" | grep -Fxq '?? src/main.h.bkp_20260703_215904' || { fail "backup main.h não está no estado esperado"; exit 22; }
}

fetch_base_builder(){
  local out="$TMP/candidate-v2.sh"
  curl --fail --silent --show-error --location --connect-timeout 10 --max-time 45 \
    "$RAW/ops/root/xlx026-core-260-candidate-v1.sh" -o "$out"
  [[ "$(git hash-object "$out")" == "$CANDIDATE_V1_BLOB" ]] || { fail "blob do candidate-v1 divergente"; exit 30; }
  echo "$out"
}

patch_builder_v2(){
  local f="$1"
  python3 - "$f" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

repls=[
('OUT="$BACKUP_ROOT/XLX026_CORE_260_CANDIDATE_${STAMP}"','OUT="$BACKUP_ROOT/XLX026_CORE_260_CANDIDATE_V2_${STAMP}"'),
('CAND="$LAB_ROOT/XLX026-Core-2.6.0-candidate_${STAMP}"','CAND="$LAB_ROOT/XLX026-Core-2.6.0-candidate-v2_${STAMP}"'),
('status=CANDIDATE_STATIC_OK','status=CANDIDATE_V2_STATIC_OK'),
('XLX026 Core 2.6.0 candidate\n','XLX026 Core 2.6.0 candidate V2\n'),
('[OK] CANDIDATO XLX026 CORE 2.6.0 CONSTRUÍDO SEM EXECUTAR E SEM ALTERAR PRODUÇÃO','[OK] CANDIDATO V2 XLX026 CORE 2.6.0 CONSTRUÍDO SEM EXECUTAR E SEM ALTERAR PRODUÇÃO'),
]
for old,new in repls:
    if s.count(old) != 1:
        raise SystemExit(f'builder V2: ocorrência inesperada: {old}')
    s=s.replace(old,new,1)

needle='''s = s.replace(old, new, 1)\nwrite(p, s)\n\n# 2) cprotocols.cpp'''
if s.count(needle) != 1:
    raise SystemExit('builder V2: ponto main.h não localizado')
insert='''s = s.replace(old, new, 1)\n\n# XLX026 production operational profile audited on 2026-08-23.\noperational = {\n    "#define NB_OF_MODULES                   10": "#define NB_OF_MODULES                   5",\n    "#define DMRMMDVM_KEEPALIVE_TIMEOUT      (DMRMMDVM_KEEPALIVE_PERIOD*10)      // in seconds": "#define DMRMMDVM_KEEPALIVE_TIMEOUT      180                                 // in seconds",\n    "#define YSF_KEEPALIVE_TIMEOUT           (YSF_KEEPALIVE_PERIOD*10)           // in seconds": "#define YSF_KEEPALIVE_TIMEOUT           90                                  // in seconds",\n    "#define YSF_DEFAULT_NODE_TX_FREQ        437000000                           // in Hz": "#define YSF_DEFAULT_NODE_TX_FREQ        433125000                           // in Hz",\n    "#define YSF_DEFAULT_NODE_RX_FREQ        437000000                           // in Hz": "#define YSF_DEFAULT_NODE_RX_FREQ        433125000                           // in Hz",\n    "#define YSF_AUTOLINK_ENABLE             0                                   // 1 = enable, 0 = disable auto-link": "#define YSF_AUTOLINK_ENABLE             1                                   // 1 = enable, 0 = disable auto-link",\n    "#define YSF_AUTOLINK_MODULE             'B'                                 // module for client to auto-link to": "#define YSF_AUTOLINK_MODULE             'C'                                 // module for client to auto-link to",\n}\nfor old_cfg,new_cfg in operational.items():\n    if s.count(old_cfg) != 1:\n        raise SystemExit(f"main.h: configuração base inesperada: {old_cfg}")\n    s=s.replace(old_cfg,new_cfg,1)\nwrite(p, s)\n\n# 2) cprotocols.cpp'''
s=s.replace(needle,insert,1)

needle='''grep -Eq '^#define[[:space:]]+NB_OF_PROTOCOLS[[:space:]]+9$' "$CAND/src/main.h"'''
if s.count(needle) != 1:
    raise SystemExit('builder V2: validação NB_OF_PROTOCOLS não localizada')
extra='''grep -Eq '^#define[[:space:]]+NB_OF_PROTOCOLS[[:space:]]+9$' "$CAND/src/main.h"\ngrep -Eq '^#define[[:space:]]+NB_OF_MODULES[[:space:]]+5$' "$CAND/src/main.h"\ngrep -Eq '^#define[[:space:]]+DMRMMDVM_KEEPALIVE_TIMEOUT[[:space:]]+180([[:space:]]|$)' "$CAND/src/main.h"\ngrep -Eq '^#define[[:space:]]+YSF_KEEPALIVE_TIMEOUT[[:space:]]+90([[:space:]]|$)' "$CAND/src/main.h"\ngrep -Eq '^#define[[:space:]]+YSF_DEFAULT_NODE_TX_FREQ[[:space:]]+433125000([[:space:]]|$)' "$CAND/src/main.h"\ngrep -Eq '^#define[[:space:]]+YSF_DEFAULT_NODE_RX_FREQ[[:space:]]+433125000([[:space:]]|$)' "$CAND/src/main.h"\ngrep -Eq '^#define[[:space:]]+YSF_AUTOLINK_ENABLE[[:space:]]+1([[:space:]]|$)' "$CAND/src/main.h"\ngrep -Eq "^#define[[:space:]]+YSF_AUTOLINK_MODULE[[:space:]]+'C'([[:space:]]|$)" "$CAND/src/main.h"'''
s=s.replace(needle,extra,1)

needle='''disabled_protocol_handlers=M17,NXDN,P25\nambed_installed_by_this_job=no'''
if s.count(needle) != 1:
    raise SystemExit('builder V2: manifesto não localizado')
manifest='''disabled_protocol_handlers=M17,NXDN,P25\nnb_of_modules=5\ndmrmmdvm_keepalive_timeout=180\nysf_keepalive_timeout=90\nysf_default_node_tx_freq=433125000\nysf_default_node_rx_freq=433125000\nysf_autolink_enable=1\nysf_autolink_module=C\nambed_installed_by_this_job=no'''
s=s.replace(needle,manifest,1)

p.write_text(s,encoding='utf-8')
PY
  bash -n "$f"
  grep -Fq 'status=CANDIDATE_V2_STATIC_OK' "$f"
  grep -Fq 'DMRMMDVM_KEEPALIVE_TIMEOUT      180' "$f"
  grep -Fq 'YSF_AUTOLINK_MODULE             '\''C'\''' "$f"
}

patch_validators_v2(){
  local pre="$1" rel="$2"
  python3 - "$pre" "$rel" <<'PY'
from pathlib import Path
import sys
pre=Path(sys.argv[1]); rel=Path(sys.argv[2])
p=pre.read_text(encoding='utf-8')
r=rel.read_text(encoding='utf-8')

# Candidate path/status must select V2 only.
p=p.replace("*XLX026_CORE_260_CANDIDATE_*/*","*XLX026_CORE_260_CANDIDATE_V2_*/*")
p=p.replace("XLX026_CORE_260_CANDIDATE_*/xlxd-core-2.6.0-candidate","XLX026_CORE_260_CANDIDATE_V2_*/xlxd-core-2.6.0-candidate")
p=p.replace("XLX026-Core-2.6.0-candidate_*","XLX026-Core-2.6.0-candidate-v2_*")
if p.count('CANDIDATE_STATIC_OK') != 1:
    raise SystemExit('precheck V9: status antigo inesperado')
p=p.replace('CANDIDATE_STATIC_OK','CANDIDATE_V2_STATIC_OK',1)

old='''[[ "$MARKER_SOURCE_DIRTY" == "0" && "$CURRENT_SOURCE_DIRTY" == "0" ]] || { fail "fonte de produção possui alterações locais não incorporadas"; exit 75; }'''
if p.count(old) != 1:
    raise SystemExit('precheck V9: gate dirty antigo não localizado')
new='''[[ "$MARKER_SOURCE_DIRTY" == "2" && "$CURRENT_SOURCE_DIRTY" == "2" ]] || { fail "estado dirty da fonte divergiu do auditado"; exit 75; }\n[[ "$CURRENT_SOURCE_HEAD" == "1d67b5a29ca2ced01ed5683d803ff9d10eac5a64" ]] || { fail "HEAD da fonte não é o baseline auditado"; exit 751; }\n[[ "$(sha256sum "$PROD_SRC/src/main.h" | awk '{print $1}')" == "72a0f60786fdb7d6f3bfd02783728a5fa4f3b51867bd9d021aa2ea0deaef2fbc" ]] || { fail "main.h mudou desde a auditoria"; exit 752; }\n[[ -f "$PROD_SRC/src/main.h.bkp_20260703_215904" ]] || { fail "backup main.h auditado ausente"; exit 753; }\n[[ "$(sha256sum "$PROD_SRC/src/main.h.bkp_20260703_215904" | awk '{print $1}')" == "49902efee053ed760dd99d42b52c391f598abab8d91ef8726b2996bf0c0c2cec" ]] || { fail "backup main.h mudou desde a auditoria"; exit 754; }\nmapfile -t SOURCE_DIRTY_LINES < <(git -C "$PROD_SRC" status --porcelain | sort)\n[[ ${#SOURCE_DIRTY_LINES[@]} -eq 2 ]] || { fail "arquivos dirty inesperados"; exit 755; }\nprintf '%s\\n' "${SOURCE_DIRTY_LINES[@]}" | grep -Fxq ' M src/main.h' || { fail "src/main.h não está no estado auditado"; exit 756; }\nprintf '%s\\n' "${SOURCE_DIRTY_LINES[@]}" | grep -Fxq '?? src/main.h.bkp_20260703_215904' || { fail "backup main.h não está no estado auditado"; exit 757; }'''
p=p.replace(old,new,1)

old='''  G3_PRESENCE_PORT G3_CONFIG_PORT G3_DV_PORT IMRS_PORT TRANSCODER_PORT JSON_PORT'''
if p.count(old) != 1:
    raise SystemExit('precheck V9: lista macro não localizada')
new='''  DMRMMDVM_KEEPALIVE_TIMEOUT YSF_KEEPALIVE_TIMEOUT\n  G3_PRESENCE_PORT G3_CONFIG_PORT G3_DV_PORT IMRS_PORT TRANSCODER_PORT JSON_PORT'''
p=p.replace(old,new,1)

# Release selects only the V2 marker. MTR contract patch from V8 remains intact.
r=r.replace("*XLX026_CORE_260_CANDIDATE_*/*","*XLX026_CORE_260_CANDIDATE_V2_*/*")
if r.count('CANDIDATE_STATIC_OK') != 1:
    raise SystemExit('release V9: status antigo inesperado')
r=r.replace('CANDIDATE_STATIC_OK','CANDIDATE_V2_STATIC_OK',1)

pre.write_text(p,encoding='utf-8')
rel.write_text(r,encoding='utf-8')
PY
  bash -n "$pre"
  bash -n "$rel"
  grep -Fq 'CANDIDATE_V2_STATIC_OK' "$pre"
  grep -Fq 'CANDIDATE_V2_STATIC_OK' "$rel"
  grep -Fq 'DMRMMDVM_KEEPALIVE_TIMEOUT YSF_KEEPALIVE_TIMEOUT' "$pre"
  grep -Fq 'contrato MTR HTTP 400/invalid_request' "$pre"
  grep -Fq 'local apis=("/api/status.php" "/api/live.php")' "$rel"
}

section_state
ok "Baseline 2.5.3 e personalizações locais exatas confirmados"

BUILDER="$(fetch_base_builder)"
patch_builder_v2 "$BUILDER"
BUILDER_V2_BLOB="$(git hash-object "$BUILDER")"
echo "candidate_v2_builder_blob=$BUILDER_V2_BLOB"

PRE_COPY="$TMP/prepublish-v9.sh"
REL_COPY="$TMP/release-v9.sh"
[[ -f "$PRECHECK" && -f "$RELEASE" ]] || { fail "validadores V8 instalados não encontrados"; exit 40; }
[[ "$(git hash-object "$PRECHECK")" == "$PRECHECK_V8_BLOB" ]] || { fail "prepublish local não é exatamente V8"; exit 41; }
[[ "$(git hash-object "$RELEASE")" == "$RELEASE_V8_BLOB" ]] || { fail "release local não é exatamente V8"; exit 42; }
cp -a "$PRECHECK" "$PRE_COPY"
cp -a "$RELEASE" "$REL_COPY"
patch_validators_v2 "$PRE_COPY" "$REL_COPY"
PRE_V9_BLOB="$(git hash-object "$PRE_COPY")"
REL_V9_BLOB="$(git hash-object "$REL_COPY")"
echo "prepublish_v9_blob=$PRE_V9_BLOB"
echo "release_v9_blob=$REL_V9_BLOB"

if [[ "${XLX026_UPGRADE_V9_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "Upgrade V9 verify-only: Candidate V2 e validadores determinísticos aprovados"
  exit 0
fi

LATEST_V2="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name CANDIDATE_COMPLETE -path '*XLX026_CORE_260_CANDIDATE_V2_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
if [[ -z "$LATEST_V2" || "$(awk -F= '$1=="status"{print $2;exit}' "$LATEST_V2" 2>/dev/null)" != "CANDIDATE_V2_STATIC_OK" ]]; then
  warn "Candidate V2 ainda não existe; iniciando build isolado"
  bash "$BUILDER"
  LATEST_V2="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name CANDIDATE_COMPLETE -path '*XLX026_CORE_260_CANDIDATE_V2_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
fi
[[ -n "$LATEST_V2" && -f "$LATEST_V2" ]] || { fail "CANDIDATE V2 não foi gerado"; exit 50; }
[[ "$(awk -F= '$1=="status"{print $2;exit}' "$LATEST_V2")" == "CANDIDATE_V2_STATIC_OK" ]] || { fail "Candidate V2 não terminou aprovado"; exit 51; }
V2_BIN="$(awk -F= '$1=="candidate_binary"{sub(/^[^=]*=/,"");print;exit}' "$LATEST_V2")"
V2_TREE="$(awk -F= '$1=="candidate_tree"{sub(/^[^=]*=/,"");print;exit}' "$LATEST_V2")"
V2_SHA="$(awk -F= '$1=="candidate_sha256"{print $2;exit}' "$LATEST_V2")"
[[ -x "$V2_BIN" && -d "$V2_TREE/.git" ]] || { fail "artefatos V2 ausentes"; exit 52; }
[[ "$(sha256sum "$V2_BIN" | awk '{print $1}')" == "$V2_SHA" ]] || { fail "SHA V2 diverge"; exit 53; }
grep -Eq '^#define[[:space:]]+NB_OF_MODULES[[:space:]]+5$' "$V2_TREE/src/main.h"
grep -Eq '^#define[[:space:]]+DMRMMDVM_KEEPALIVE_TIMEOUT[[:space:]]+180([[:space:]]|$)' "$V2_TREE/src/main.h"
grep -Eq '^#define[[:space:]]+YSF_KEEPALIVE_TIMEOUT[[:space:]]+90([[:space:]]|$)' "$V2_TREE/src/main.h"
grep -Eq '^#define[[:space:]]+YSF_DEFAULT_NODE_TX_FREQ[[:space:]]+433125000([[:space:]]|$)' "$V2_TREE/src/main.h"
grep -Eq '^#define[[:space:]]+YSF_DEFAULT_NODE_RX_FREQ[[:space:]]+433125000([[:space:]]|$)' "$V2_TREE/src/main.h"
grep -Eq '^#define[[:space:]]+YSF_AUTOLINK_ENABLE[[:space:]]+1([[:space:]]|$)' "$V2_TREE/src/main.h"
grep -Eq "^#define[[:space:]]+YSF_AUTOLINK_MODULE[[:space:]]+'C'([[:space:]]|$)" "$V2_TREE/src/main.h"
section_state
ok "Candidate V2 aprovado; produção ainda 2.5.3"

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="$BACKUP_ROOT/VALIDATORS_V9_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"
tar -C / -czpf "$PRE/validators-pre-v9.tar.gz" \
  usr/local/sbin/xlx026-core-260-prepublish-v1 \
  usr/local/sbin/xlx026-core-260-release-v1
sha256sum "$PRE/validators-pre-v9.tar.gz" > "$PRE/validators-pre-v9.tar.gz.sha256"
(cd "$PRE" && sha256sum -c validators-pre-v9.tar.gz.sha256)

VALIDATORS_MUTATED=1
install -o root -g root -m 0750 "$PRE_COPY" "$PRECHECK"
install -o root -g root -m 0750 "$REL_COPY" "$RELEASE"
[[ "$(git hash-object "$PRECHECK")" == "$PRE_V9_BLOB" ]]
[[ "$(git hash-object "$RELEASE")" == "$REL_V9_BLOB" ]]
section_state
VALIDATORS_MUTATED=0

cat <<OUT
[OK] XLX026 V9 concluída.
[OK] Candidate V2: CANDIDATE_V2_STATIC_OK
[OK] Candidate V2 SHA: $V2_SHA
[OK] Configuração preservada: 5 módulos; DMR=180s; YSF=90s; 433125000 Hz; autolink=C.
[OK] M17/NXDN/P25 handlers continuam desativados no candidato.
[OK] Validadores V9 instalados com contrato MTR V8 preservado.
[OK] Backup dos validadores V8: $PRE
[OK] Produção continua XLXD 2.5.3 sem restart.
[OK] Próxima ação fixa: /usr/local/sbin/xlx026-finish-project-v1
OUT
