#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

SOURCE_REF="b4f19164471c9af9a196f0f60e78a6fb19651377"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_REF}"
EXPECTED_PROD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"
EXPECTED_XML_VERSION="2.5.3"
PRECHECK_OLD_BLOB="07e2956c77269ccd07f46d9b3d5b9f29517362dd"
RELEASE_OLD_BLOB="81298c3e64579eac0e6ff4f253762b38b3443d82"

TMP="$(mktemp -d /tmp/xlx026-agent-v8.XXXXXX)"
PRE=""
MUTATED=0

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

restore_previous(){
  local rc="$1"
  trap - EXIT
  set +e
  if [[ "$MUTATED" -eq 1 && -n "$PRE" && -f "$PRE/validators-pre-v8.tar.gz" ]]; then
    echo "[ATENÇÃO] Falha na V8; restaurando validadores anteriores..." >&2
    tar -C / -xzf "$PRE/validators-pre-v8.tar.gz" || true
  fi
  rm -rf "$TMP"
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 ]]; then restore_previous "$rc"; else rm -rf "$TMP"; fi' EXIT

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl git install pgrep python3 sha256sum systemctl tar; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

fetch_verify_blob(){
  local rel="$1" expected="$2" out got
  out="$TMP/$(basename "$rel")"
  curl --fail --silent --show-error --location --connect-timeout 10 --max-time 45 "$RAW/$rel" -o "$out"
  got="$(git hash-object "$out")"
  [[ "$got" == "$expected" ]] || {
    fail "Git blob divergente em $rel"
    echo "esperado=$expected" >&2
    echo "obtido=$got" >&2
    exit 3
  }
  echo "$out"
}

PRECHECK="$(fetch_verify_blob ops/root/xlx026-core-260-prepublish-v1.sh "$PRECHECK_OLD_BLOB")"
RELEASE="$(fetch_verify_blob ops/root/xlx026-core-260-release-v1.sh "$RELEASE_OLD_BLOB")"

python3 - "$PRECHECK" "$RELEASE" <<'PY'
from pathlib import Path
import sys
pre=Path(sys.argv[1])
rel=Path(sys.argv[2])

p=pre.read_text(encoding='utf-8')
old='APIS=("/api/status.php" "/api/live.php" "/api/mtr.php")'
if p.count(old) != 1:
    raise SystemExit('precheck: lista de APIs inesperada')
p=p.replace(old,'APIS=("/api/status.php" "/api/live.php")',1)
needle='''done\nok "APIs críticas responderam HTTP 200 e JSON válido"'''
if p.count(needle) != 1:
    raise SystemExit('precheck: ponto de inserção MTR inesperado')
insert='''done

mtr_path="/api/mtr.php"
mtr_body="$OUT/http/api_api_mtr_php.json"
mtr_code="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$mtr_body" -w '%{http_code}' "$BASE_URL$mtr_path")" || {
  fail "API MTR indisponível"
  exit 62
}
[[ "$mtr_code" == "400" ]] || { fail "contrato MTR inesperado: HTTP $mtr_code"; exit 63; }
python3 - "$mtr_body" <<'PYMTR'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f:
    d=json.load(f)
if d.get('ok') is not False or d.get('error') != 'invalid_request':
    raise SystemExit('contrato MTR JSON inesperado')
PYMTR
mtr_bytes="$(wc -c < "$mtr_body")"
printf '%s\\t%s\\t%s\\n' "$mtr_path" "$mtr_code" "$mtr_bytes" | tee -a "$OUT/http-apis.tsv"
ok "status/live HTTP 200 + contrato MTR HTTP 400/invalid_request aprovados"'''
p=p.replace(needle,insert,1)
pre.write_text(p,encoding='utf-8')

r=rel.read_text(encoding='utf-8')
old='local apis=("/api/status.php" "/api/live.php" "/api/mtr.php")'
if r.count(old) != 1:
    raise SystemExit('release: lista de APIs inesperada')
r=r.replace(old,'local apis=("/api/status.php" "/api/live.php")',1)
needle='''  done\n  ok "$phase: 9 páginas e 3 APIs aprovadas"'''
if r.count(needle) != 1:
    raise SystemExit('release: ponto de inserção MTR inesperado')
insert='''  done

  local mtr_path="/api/mtr.php"
  local mtr_body="$dir/api_api_mtr_php.json"
  local mtr_code mtr_bytes
  mtr_code="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$mtr_body" -w '%{http_code}' "$BASE_URL$mtr_path")" || return 1
  [[ "$mtr_code" == "400" ]] || return 1
  if ! python3 - "$mtr_body" <<'PYMTR'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f:
    d=json.load(f)
if d.get('ok') is not False or d.get('error') != 'invalid_request':
    raise SystemExit(1)
PYMTR
  then
    return 1
  fi
  mtr_bytes="$(wc -c < "$mtr_body")"
  printf '%s\\t%s\\t%s\\n' "$mtr_path" "$mtr_code" "$mtr_bytes" >> "$dir/apis.tsv"
  ok "$phase: 9 páginas + status/live HTTP 200 + contrato MTR aprovado"'''
r=r.replace(needle,insert,1)
rel.write_text(r,encoding='utf-8')
PY

bash -n "$PRECHECK"
bash -n "$RELEASE"

grep -Fq 'contrato MTR HTTP 400/invalid_request' "$PRECHECK"
grep -Fq 'local apis=("/api/status.php" "/api/live.php")' "$RELEASE"

PRECHECK_NEW_BLOB="$(git hash-object "$PRECHECK")"
RELEASE_NEW_BLOB="$(git hash-object "$RELEASE")"

echo "precheck_new_blob=$PRECHECK_NEW_BLOB"
echo "release_new_blob=$RELEASE_NEW_BLOB"

if [[ "${XLX026_UPGRADE_V8_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "Upgrade V8 verify-only: patch MTR determinístico e sintaxe aprovados."
  exit 0
fi

[[ -x /xlxd/xlxd ]] || { fail "/xlxd/xlxd ausente"; exit 10; }
CURRENT_PROD_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA" == "$EXPECTED_PROD_SHA" ]] || {
  fail "produção não está mais no baseline 2.5.3; V8 abortada"
  echo "esperado=$EXPECTED_PROD_SHA" >&2
  echo "obtido=$CURRENT_PROD_SHA" >&2
  exit 11
}
[[ "$(xml_version)" == "$EXPECTED_XML_VERSION" ]] || { fail "XML não está em 2.5.3; V8 abortada"; exit 12; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está active"; exit 13; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade de processos xlxd inesperada"; exit 14; }

INST_PRE="/usr/local/sbin/xlx026-core-260-prepublish-v1"
INST_REL="/usr/local/sbin/xlx026-core-260-release-v1"
[[ -f "$INST_PRE" && -f "$INST_REL" ]] || { fail "validadores V7 não encontrados"; exit 15; }
CUR_PRE="$(git hash-object "$INST_PRE")"
CUR_REL="$(git hash-object "$INST_REL")"
[[ "$CUR_PRE" == "$PRECHECK_OLD_BLOB" || "$CUR_PRE" == "$PRECHECK_NEW_BLOB" ]] || { fail "prepublish local não corresponde ao V7/V8 esperado"; exit 16; }
[[ "$CUR_REL" == "$RELEASE_OLD_BLOB" || "$CUR_REL" == "$RELEASE_NEW_BLOB" ]] || { fail "release local não corresponde ao V7/V8 esperado"; exit 17; }

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="/root/backups-xlx026/VALIDATORS_V8_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"
tar -C / -czpf "$PRE/validators-pre-v8.tar.gz" \
  usr/local/sbin/xlx026-core-260-prepublish-v1 \
  usr/local/sbin/xlx026-core-260-release-v1
sha256sum "$PRE/validators-pre-v8.tar.gz" > "$PRE/validators-pre-v8.tar.gz.sha256"
(cd "$PRE" && sha256sum -c validators-pre-v8.tar.gz.sha256)

MUTATED=1
install -o root -g root -m 0750 "$PRECHECK" "$INST_PRE"
install -o root -g root -m 0750 "$RELEASE" "$INST_REL"
[[ "$(git hash-object "$INST_PRE")" == "$PRECHECK_NEW_BLOB" ]]
[[ "$(git hash-object "$INST_REL")" == "$RELEASE_NEW_BLOB" ]]

[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_PROD_SHA" ]] || { fail "produção mudou durante V8"; exit 20; }
[[ "$(xml_version)" == "$EXPECTED_XML_VERSION" ]] || { fail "XML mudou durante V8"; exit 21; }
systemctl is-active --quiet xlxd.service || { fail "XLXD deixou de estar ativo durante V8"; exit 22; }

MUTATED=0
cat <<OUT
[OK] VALIDADORES V8 instalados.
[OK] MTR agora é validado pelo contrato correto: HTTP 400 + invalid_request sem parâmetros.
[OK] status.php e live.php continuam exigindo HTTP 200 + JSON válido.
[OK] Backup pré-V8: $PRE
[OK] Core permaneceu 2.5.3, SHA: $EXPECTED_PROD_SHA
[OK] Nenhum restart do XLXD ocorreu.
[OK] Próxima ação: /usr/local/sbin/xlx026-finish-project-v1
OUT
