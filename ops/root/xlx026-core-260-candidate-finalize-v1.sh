#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

EXPECTED_UPSTREAM="a79a3bf8d883bd35911a34648d71e6980726b4e8"
BACKUP_ROOT="/root/backups-xlx026"
LAB_ROOT="/root/xlx026-lab"
PROD_BIN="/xlxd/xlxd"
PROD_SRC="/usr/src/xlxd"

ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }

for c in git sha256sum nm grep awk find sort head cut pgrep; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

section "1/7 — LOCALIZAR CANDIDATO COMPILADO COM FALHA APENAS NO EMPACOTAMENTO"

OUT="$(
  find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'XLX026_CORE_260_CANDIDATE_*' -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | cut -d' ' -f2- \
  | while IFS= read -r d; do
      [[ -f "$d/execution.log" ]] || continue
      [[ -f "$d/candidate-binary.sha256" ]] || continue
      [[ -f "$d/candidate-binary.nm" ]] || continue
      [[ -x "$d/xlxd-core-2.6.0-candidate" ]] || continue
      [[ -f "$d/xlxd-core-2.6.0-candidate.sha256" ]] || continue
      [[ -f "$d/xlx026-core-2.6.0.patch.sha256" ]] || continue
      [[ ! -f "$d/CANDIDATE_COMPLETE" ]] || continue
      grep -Fq '[OK] Handlers extras ausentes; 9 handlers esperados presentes' "$d/execution.log" || continue
      grep -Fq 'sha256sum: xlx026-core-2.6.0-candidate.sha256: No such file or directory' "$d/execution.log" || continue
      printf '%s\n' "$d"
      break
    done
)"

[[ -n "$OUT" && -d "$OUT" ]] || {
  fail "nenhum candidato elegível para finalização foi encontrado"
  exit 10
}

BASE="$(basename "$OUT")"
STAMP="${BASE#XLX026_CORE_260_CANDIDATE_}"
CAND="$LAB_ROOT/XLX026-Core-2.6.0-candidate_${STAMP}"

echo "candidate_output=$OUT"
echo "candidate_tree=$CAND"
ok "Falha anterior identificada exatamente como typo de checksum"

section "2/7 — VALIDAR ÁRVORE E SHA UPSTREAM"

[[ -d "$CAND/.git" ]] || { fail "árvore candidata ausente: $CAND"; exit 20; }
ACTUAL="$(git -C "$CAND" rev-parse HEAD)"
[[ "$ACTUAL" == "$EXPECTED_UPSTREAM" ]] || {
  fail "HEAD candidato diverge: $ACTUAL"
  exit 21
}
echo "upstream_sha=$ACTUAL"

grep -Eq '^#define[[:space:]]+NB_OF_PROTOCOLS[[:space:]]+9$' "$CAND/src/main.h"
! grep -Eq 'cm17protocol|cnxdnprotocol|cp25protocol' "$CAND/src/cprotocols.cpp"
! grep -Fq 'g_NxdnIdDir.Init();' "$CAND/src/creflector.cpp"
grep -Fq 'filter-out cm17protocol.cpp cnxdnprotocol.cpp cp25protocol.cpp' "$CAND/src/makefile"
ok "Recorte de 9 protocolos confirmado"

section "3/7 — VALIDAR CHECKSUMS COM O NOME CORRETO"

(
  cd "$OUT"
  sha256sum -c xlx026-core-2.6.0.patch.sha256
  sha256sum -c xlxd-core-2.6.0-candidate.sha256
)

BUILD_SHA="$(awk '{print $1}' "$OUT/candidate-binary.sha256")"
STAGED_SHA="$(sha256sum "$OUT/xlxd-core-2.6.0-candidate" | awk '{print $1}')"
[[ "$BUILD_SHA" == "$STAGED_SHA" ]] || {
  fail "SHA do binário compilado e do artefato estagiado divergem"
  exit 30
}
echo "candidate_sha256=$STAGED_SHA"
ok "Artefato e checksums íntegros"

section "4/7 — REPETIR AUDITORIA ESTÁTICA"

if grep -Eq 'CM17Protocol::(Init|Task|Close)|CNxdnProtocol::(Init|Task|Close)|CP25Protocol::(Init|Task|Close)' "$OUT/candidate-binary.nm"; then
  fail "handlers M17/NXDN/P25 detectados"
  exit 40
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
    exit 41
  }
done
ok "9 handlers esperados presentes; extras ausentes"

section "5/7 — CONFERIR PRODUÇÃO E FONTE ATUAL"

[[ -x "$PROD_BIN" ]] || { fail "binário de produção ausente"; exit 50; }

ORIGINAL_PROD_SHA="$(awk -F= '$1=="production_sha_before"{print $2; exit}' "$OUT/execution.log")"
CURRENT_PROD_SHA="$(sha256sum "$PROD_BIN" | awk '{print $1}')"

echo "production_sha_expected=$ORIGINAL_PROD_SHA"
echo "production_sha_current=$CURRENT_PROD_SHA"

[[ -n "$ORIGINAL_PROD_SHA" && "$CURRENT_PROD_SHA" == "$ORIGINAL_PROD_SHA" ]] || {
  fail "produção mudou desde o build do candidato"
  exit 51
}

pgrep -x xlxd >/dev/null 2>&1 || {
  fail "XLXD de produção não está ativo"
  exit 52
}

CURRENT_HEAD=""
DIRTY_COUNT="-1"
if [[ -d "$PROD_SRC/.git" ]]; then
  CURRENT_HEAD="$(git -C "$PROD_SRC" rev-parse HEAD 2>/dev/null || true)"
  git -C "$PROD_SRC" status --short --branch > "$OUT/current-source-status-final.txt" 2>&1 || true
  DIRTY_COUNT="$(git -C "$PROD_SRC" status --porcelain 2>/dev/null | wc -l)"
  echo "current_source_head=$CURRENT_HEAD"
  echo "current_source_dirty_files=$DIRTY_COUNT"
  if [[ "$DIRTY_COUNT" != "0" ]]; then
    warn "Fonte atual possui arquivos modificados; serão revisados antes de qualquer publicação:"
    cat "$OUT/current-source-status-final.txt"
  fi
fi

section "6/7 — GERAR MANIFESTO FINAL"

cat > "$OUT/CANDIDATE-MANIFEST.txt" <<EOF
XLX026 Core 2.6.0 candidate
upstream_sha=$EXPECTED_UPSTREAM
operational_protocol_count=9
active_protocols=DEXTRA,DPLUS,DCS,XLX,DMRPLUS,DMRMMDVM,YSF,G3,IMRS
disabled_protocol_handlers=M17,NXDN,P25
ambed_installed_by_this_job=no
candidate_executed_by_this_job=no
candidate_installed_to_production=no
finalized_from_packaging_typo=yes
candidate_sha256=$STAGED_SHA
candidate_tree=$CAND
EOF

sha256sum "$OUT/CANDIDATE-MANIFEST.txt" > "$OUT/CANDIDATE-MANIFEST.txt.sha256"

section "7/7 — MARCADOR DE CONCLUSÃO"

cat > "$OUT/CANDIDATE_COMPLETE" <<EOF
status=CANDIDATE_STATIC_OK
path=$OUT
candidate_tree=$CAND
candidate_binary=$OUT/xlxd-core-2.6.0-candidate
candidate_sha256=$STAGED_SHA
upstream_sha=$EXPECTED_UPSTREAM
production_binary_sha=$CURRENT_PROD_SHA
xlxd_final=ACTIVE
current_source_head=$CURRENT_HEAD
current_source_dirty_files=$DIRTY_COUNT
finalized_from_packaging_typo=yes
EOF

chmod 600 "$OUT"/CANDIDATE-MANIFEST.txt "$OUT"/CANDIDATE-MANIFEST.txt.sha256 "$OUT"/CANDIDATE_COMPLETE \
  "$OUT"/current-source-status-final.txt 2>/dev/null || true

cat "$OUT/CANDIDATE_COMPLETE"
ok "CANDIDATO FINALIZADO SEM EXECUTAR, INSTALAR OU REINICIAR PRODUÇÃO"
