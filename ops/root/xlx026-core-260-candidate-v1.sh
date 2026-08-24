#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

EXPECTED_UPSTREAM="a79a3bf8d883bd35911a34648d71e6980726b4e8"
BACKUP_ROOT="/root/backups-xlx026"
LAB_ROOT="/root/xlx026-lab"
PROD_BIN="/xlxd/xlxd"
PROD_SRC="/usr/src/xlxd"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_CORE_260_CANDIDATE_${STAMP}"
CAND="$LAB_ROOT/XLX026-Core-2.6.0-candidate_${STAMP}"

ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }

for c in git make g++ python3 sha256sum diff nm file ldd grep awk find cp; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

mkdir -p "$OUT" "$LAB_ROOT"
chmod 700 "$OUT" "$LAB_ROOT"
exec > >(tee -a "$OUT/execution.log") 2>&1

section "1/9 — LOCALIZAR GOLDEN/LAB VALIDADO"

COMPLETE="$(
  find "$BACKUP_ROOT" -maxdepth 2 -type f -name COMPLETE \
    -path '*XLX026_GOLDEN_BASELINE_V2_*/*' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"

[[ -n "$COMPLETE" && -f "$COMPLETE" ]] || {
  fail "Golden COMPLETE não encontrado"
  exit 10
}

LAB_REPO="$(awk -F= '$1=="lab"{print substr($0,index($0,"=")+1)}' "$COMPLETE")"
LAB_RESULT="$(awk -F= '$1=="lab_result"{print $2}' "$COMPLETE")"
UPSTREAM_SHA="$(awk -F= '$1=="upstream_sha"{print $2}' "$COMPLETE")"

[[ "$LAB_RESULT" == "BUILD_OK" ]] || { fail "Golden sem BUILD_OK"; exit 11; }
[[ "$UPSTREAM_SHA" == "$EXPECTED_UPSTREAM" ]] || { fail "Golden upstream SHA inesperado"; exit 12; }
[[ -d "$LAB_REPO/.git" ]] || { fail "lab repo inválido: $LAB_REPO"; exit 13; }

ACTUAL="$(git -C "$LAB_REPO" rev-parse HEAD)"
[[ "$ACTUAL" == "$EXPECTED_UPSTREAM" ]] || { fail "HEAD do lab diverge: $ACTUAL"; exit 14; }

echo "golden_complete=$COMPLETE"
echo "lab_repo=$LAB_REPO"
echo "upstream_sha=$ACTUAL"
ok "Golden/Lab confirmado"

section "2/9 — ESTADO DA PRODUÇÃO"

[[ -x "$PROD_BIN" ]] || { fail "binário de produção ausente"; exit 20; }
PROD_SHA_BEFORE="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
echo "production_sha_before=$PROD_SHA_BEFORE"

if [[ -d "$PROD_SRC/.git" ]]; then
  CURRENT_HEAD="$(git -C "$PROD_SRC" rev-parse HEAD 2>/dev/null || true)"
  echo "current_source_head=$CURRENT_HEAD"
  git -C "$PROD_SRC" status --short --branch > "$OUT/current-source-status.txt" 2>&1 || true
  DIRTY_COUNT="$(git -C "$PROD_SRC" status --porcelain 2>/dev/null | wc -l)"
  echo "current_source_dirty_files=$DIRTY_COUNT"
else
  warn "$PROD_SRC não é repositório git"
  CURRENT_HEAD=""
  DIRTY_COUNT="-1"
fi

section "3/9 — CRIAR CÓPIA ISOLADA DO CANDIDATO"

[[ ! -e "$CAND" ]] || { fail "diretório candidato já existe"; exit 30; }
cp -a "$LAB_REPO" "$CAND"
git -C "$CAND" reset --hard "$EXPECTED_UPSTREAM" >/dev/null
git -C "$CAND" clean -fdx >/dev/null
[[ "$(git -C "$CAND" rev-parse HEAD)" == "$EXPECTED_UPSTREAM" ]] || {
  fail "cópia candidata não ficou no SHA esperado"
  exit 31
}
ok "Cópia isolada criada: $CAND"

section "4/9 — APLICAR RECORTE XLX026 (9 PROTOCOLOS)"

python3 - "$CAND" <<'PY'
from pathlib import Path
import re, sys

root = Path(sys.argv[1]) / "src"

def read(name):
    return (root / name).read_text(encoding="utf-8-sig")

def write(name, text):
    (root / name).write_text(text, encoding="utf-8", newline="\n")

# 1) main.h — operational protocol array back to the production scope (9).
p = "main.h"
s = read(p)
old = "#define NB_OF_PROTOCOLS                 12"
new = "#define NB_OF_PROTOCOLS                 9"
if s.count(old) != 1:
    raise SystemExit("main.h: NB_OF_PROTOCOLS=12 não encontrado exatamente uma vez")
s = s.replace(old, new, 1)
write(p, s)

# 2) cprotocols.cpp — remove M17/NXDN/P25 handlers while keeping 2.6 internals.
p = "cprotocols.cpp"
s = read(p)
for inc in (
    '#include "cm17protocol.h"\n',
    '#include "cnxdnprotocol.h"\n',
    '#include "cp25protocol.h"\n',
):
    if s.count(inc) != 1:
        raise SystemExit(f"cprotocols.cpp: include inesperado: {inc.strip()}")
    s = s.replace(inc, "", 1)

patterns = [
    r'\n\s*// create and initialize M17\n\s*delete m_Protocols\[9\];\n\s*m_Protocols\[9\] = new CM17Protocol;\n\s*ok &= m_Protocols\[9\]->Init\(\);\n',
    r'\n\s*// create and initialize NXDN \(peer-only\)\n\s*delete m_Protocols\[10\];\n\s*m_Protocols\[10\] = new CNxdnProtocol;\n\s*ok &= m_Protocols\[10\]->Init\(\);\n',
    r'\n\s*// create and initialize P25 \(peer-only\)\n\s*delete m_Protocols\[11\];\n\s*m_Protocols\[11\] = new CP25Protocol;\n\s*ok &= m_Protocols\[11\]->Init\(\);\n',
]
for pat in patterns:
    s2, n = re.subn(pat, "\n", s, count=1)
    if n != 1:
        raise SystemExit("cprotocols.cpp: bloco de protocolo extra não encontrado")
    s = s2

old_close = """        for ( int i = 0; i < m_Protocols.size(); i++ )
        {
            m_Protocols[i]->Close();
        }
"""
new_close = """        for ( int i = 0; i < m_Protocols.size(); i++ )
        {
            if ( m_Protocols[i] != NULL )
            {
                m_Protocols[i]->Close();
            }
        }
"""
if s.count(old_close) != 1:
    raise SystemExit("cprotocols.cpp: Close() esperado não encontrado")
s = s.replace(old_close, new_close, 1)
write(p, s)

# 3) creflector.cpp — no NXDN directory initialization in XLX026 scope.
p = "creflector.cpp"
s = read(p)
for inc in (
    '#include "cnxdniddirfile.h"\n',
    '#include "cnxdniddirhttp.h"\n',
):
    if s.count(inc) != 1:
        raise SystemExit(f"creflector.cpp: include inesperado: {inc.strip()}")
    s = s.replace(inc, "", 1)

block = """    // init nxdn id directory
    g_NxdnIdDir.Init();

"""
if s.count(block) != 1:
    raise SystemExit("creflector.cpp: init NXDN esperado não encontrado")
s = s.replace(block, "", 1)
write(p, s)

# 4) makefile — do not link the three protocol handlers.
p = "makefile"
s = read(p)
old = "SOURCES=$(wildcard *.cpp)"
new = "SOURCES=$(filter-out cm17protocol.cpp cnxdnprotocol.cpp cp25protocol.cpp,$(wildcard *.cpp))"
if s.count(old) != 1:
    raise SystemExit("makefile: SOURCES wildcard esperado não encontrado")
s = s.replace(old, new, 1)
write(p, s)
PY

ok "Patch determinístico aplicado"

section "5/9 — VALIDAR O RECORTE ANTES DO BUILD"

grep -Eq '^#define[[:space:]]+NB_OF_PROTOCOLS[[:space:]]+9$' "$CAND/src/main.h"
! grep -Eq 'cm17protocol|cnxdnprotocol|cp25protocol' "$CAND/src/cprotocols.cpp"
! grep -Eq 'new[[:space:]]+(CM17Protocol|CNxdnProtocol|CP25Protocol)' "$CAND/src/cprotocols.cpp"
! grep -Fq 'g_NxdnIdDir.Init();' "$CAND/src/creflector.cpp"
grep -Fq 'filter-out cm17protocol.cpp cnxdnprotocol.cpp cp25protocol.cpp' "$CAND/src/makefile"

git -C "$CAND" diff -- src/main.h src/cprotocols.cpp src/creflector.cpp src/makefile \
  > "$OUT/xlx026-core-2.6.0.patch"
sha256sum "$OUT/xlx026-core-2.6.0.patch" > "$OUT/xlx026-core-2.6.0.patch.sha256"
git -C "$CAND" diff --stat > "$OUT/candidate-diff-stat.txt"
cat "$OUT/candidate-diff-stat.txt"

section "6/9 — BUILD DO CANDIDATO (SEM EXECUTAR / SEM INSTALL)"

set +e
(
  cd "$CAND/src"
  make clean
  nice -n 10 make -j1
) > "$OUT/candidate-build.log" 2>&1
BRC=$?
set -e

if [[ $BRC -ne 0 || ! -x "$CAND/src/xlxd" ]]; then
  fail "build do candidato falhou"
  tail -n 120 "$OUT/candidate-build.log" || true
  exit 40
fi

ok "Build do candidato concluído"

section "7/9 — AUDITORIA ESTÁTICA DO BINÁRIO"

BIN="$CAND/src/xlxd"
sha256sum "$BIN" > "$OUT/candidate-binary.sha256"
file "$BIN" > "$OUT/candidate-binary.file"
ldd "$BIN" > "$OUT/candidate-binary.ldd" 2>&1 || true
nm -C "$BIN" > "$OUT/candidate-binary.nm" 2>&1 || true

if grep -Eq 'CM17Protocol::(Init|Task|Close)|CNxdnProtocol::(Init|Task|Close)|CP25Protocol::(Init|Task|Close)' "$OUT/candidate-binary.nm"; then
  fail "símbolos de handlers M17/NXDN/P25 ainda presentes"
  grep -E 'CM17Protocol::|CNxdnProtocol::|CP25Protocol::' "$OUT/candidate-binary.nm" | head -30 || true
  exit 50
fi

for sym in \
  'CDextraProtocol::Init' \
  'CDplusProtocol::Init' \
  'CDcsProtocol::Init' \
  'CXlxProtocol::Init' \
  'CDmrplusProtocol::Init' \
  'CDmrmmdvmProtocol::Init' \
  'CYsfProtocol::Init' \
  'CG3Protocol::Init' \
  'CImrsProtocol::Init'
do
  grep -Fq "$sym" "$OUT/candidate-binary.nm" || {
    fail "símbolo obrigatório ausente: $sym"
    exit 51
  }
done

CAND_SHA="$(awk '{print $1}' "$OUT/candidate-binary.sha256")"
echo "candidate_sha256=$CAND_SHA"
ok "Handlers extras ausentes; 9 handlers esperados presentes"

section "8/9 — ESTAGIAR ARTEFATO SEM TOCAR PRODUÇÃO"

install -m 0750 "$BIN" "$OUT/xlxd-core-2.6.0-candidate"
sha256sum "$OUT/xlxd-core-2.6.0-candidate" > "$OUT/xlxd-core-2.6.0-candidate.sha256"
(
  cd "$OUT"
  sha256sum -c xlx026-core-2.6.0.patch.sha256
  sha256sum -c xlx026-core-2.6.0-candidate.sha256
)

cat > "$OUT/CANDIDATE-MANIFEST.txt" <<EOF
XLX026 Core 2.6.0 candidate
upstream_sha=$EXPECTED_UPSTREAM
operational_protocol_count=9
active_protocols=DEXTRA,DPLUS,DCS,XLX,DMRPLUS,DMRMMDVM,YSF,G3,IMRS
disabled_protocol_handlers=M17,NXDN,P25
ambed_installed_by_this_job=no
candidate_executed_by_this_job=no
candidate_installed_to_production=no
candidate_sha256=$CAND_SHA
candidate_tree=$CAND
EOF

section "9/9 — VALIDAR PRODUÇÃO INTACTA"

PROD_SHA_AFTER="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
[[ "$PROD_SHA_AFTER" == "$PROD_SHA_BEFORE" ]] || {
  fail "binário de produção mudou durante o laboratório"
  exit 60
}

if systemctl is-active --quiet xlxd.service || pgrep -x xlxd >/dev/null 2>&1; then
  XLXD_FINAL="ACTIVE"
else
  fail "XLXD de produção não está ativo"
  exit 61
fi

cat > "$OUT/CANDIDATE_COMPLETE" <<EOF
status=CANDIDATE_STATIC_OK
path=$OUT
candidate_tree=$CAND
candidate_binary=$OUT/xlxd-core-2.6.0-candidate
candidate_sha256=$CAND_SHA
upstream_sha=$EXPECTED_UPSTREAM
production_binary_sha=$PROD_SHA_AFTER
xlxd_final=$XLXD_FINAL
current_source_head=$CURRENT_HEAD
current_source_dirty_files=$DIRTY_COUNT
EOF

chmod 600 "$OUT"/* 2>/dev/null || true

cat "$OUT/CANDIDATE_COMPLETE"
echo "[OK] CANDIDATO XLX026 CORE 2.6.0 CONSTRUÍDO SEM EXECUTAR E SEM ALTERAR PRODUÇÃO"
