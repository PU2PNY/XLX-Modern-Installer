#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

V9_REF="3ae4a2c62b6960af22771d1373b691c3795db887"
V9_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${V9_REF}/ops/agent/upgrade-v9.sh"
V9_BLOB="4879bd3b1a81ba141122d595705307538901d5d9"
EXPECTED_OLD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"
EXPECTED_OLD_VERSION="2.5.3"
EXPECTED_NEW_VERSION="2.6.0"
EXPECTED_PANEL_VERSION="1.1.0"
PANEL_MARKER="Painel XLX026 v1.1.0"
PANEL_SOURCE_URL="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard"
INSTALLER_URL="https://github.com/PU2PNY/XLX-Modern-Installer"
BACKUP_ROOT="/root/backups-xlx026"
RELEASE="/usr/local/sbin/xlx026-core-260-release-v1"
PANEL_RELEASE="/usr/local/sbin/xlx026-panel-footer-v1"
PRECHECK="/usr/local/sbin/xlx026-core-260-prepublish-v1"
WEBROOT="/var/www/html/xlxd-novo"
BASE_URL="https://xlx026.net"
STATE="$BACKUP_ROOT/XLX026_V10_RESUME.state"

TMP="$(mktemp -d /tmp/xlx026-v10-final.XXXXXX)"
V9="$TMP/upgrade-v9-fixed.sh"
LOG="$TMP/v9.log"

cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
get_kv(){ awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl find git grep pgrep python3 sed sha256sum sort systemctl tee wc; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

section "1/8 — PREPARAR V9 CORRIGIDA"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$V9_URL" -o "$V9"
[[ "$(git hash-object "$V9")" == "$V9_BLOB" ]] || { fail "blob V9 divergente"; exit 10; }
python3 - "$V9" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
needle="repls=[\n"
if s.count(needle) != 1:
    raise SystemExit('V10: lista repls da V9 inesperada')
fixes=(
    "repls=[\n"
    "('sha256sum -c xlx026-core-2.6.0-candidate.sha256','sha256sum -c xlxd-core-2.6.0-candidate.sha256'),\n"
    "('chmod 600 \"$OUT\"/* 2>/dev/null || true','chmod 600 \"$OUT\"/* 2>/dev/null || true\\nchmod 0750 \"$OUT/xlxd-core-2.6.0-candidate\"'),\n"
)
s=s.replace(needle,fixes,1)
p.write_text(s,encoding='utf-8')
blocks=re.findall(r"<<'PY'\n(.*?)\nPY\n",s,flags=re.S)
if len(blocks)!=2:
    raise SystemExit(f'V10: blocos Python V9={len(blocks)}')
for i,b in enumerate(blocks,1):
    compile(b,f'v9-fixed-{i}.py','exec')
PY
bash -n "$V9"
grep -Fq "sha256sum -c xlxd-core-2.6.0-candidate.sha256" "$V9"
grep -Fq 'chmod 0750 \"$OUT/xlxd-core-2.6.0-candidate\"' "$V9"
ok "V9 corrigida deterministicamente: checksum e bit executável"

if [[ "${XLX026_V10_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "V10 verify-only concluído; nenhuma ação no servidor executada"
  exit 0
fi

section "2/8 — CLASSIFICAR ESTADO ATUAL"
[[ -x /xlxd/xlxd ]] || { fail "/xlxd/xlxd ausente"; exit 20; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está active"; exit 21; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "processos XLXD inesperados"; exit 22; }
CURRENT_VER="$(xml_version)"
CURRENT_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
echo "current_version=$CURRENT_VER"
echo "current_sha=$CURRENT_SHA"

if [[ "$CURRENT_VER" == "$EXPECTED_OLD_VERSION" ]]; then
  [[ "$CURRENT_SHA" == "$EXPECTED_OLD_SHA" ]] || { fail "2.5.3 com SHA não aprovado"; exit 23; }
  MODE="PRE_CORE"
elif [[ "$CURRENT_VER" == "$EXPECTED_NEW_VERSION" ]]; then
  MODE="POST_CORE"
else
  fail "versão inesperada: $CURRENT_VER"
  exit 24
fi
echo "resume_mode=$MODE"

section "3/8 — CANDIDATE V2 + VALIDADORES V9"
if [[ "$MODE" == "PRE_CORE" ]]; then
  RESUME_OK=0
  if [[ -f "$STATE" ]]; then
    EXPECT_PRE="$(get_kv "$STATE" prepublish_blob)"
    EXPECT_REL="$(get_kv "$STATE" release_blob)"
    EXPECT_CAND="$(get_kv "$STATE" candidate_complete)"
    if [[ -n "$EXPECT_PRE" && -n "$EXPECT_REL" && -f "$EXPECT_CAND" && \
          "$(get_kv "$EXPECT_CAND" status)" == "CANDIDATE_V2_STATIC_OK" && \
          "$(git hash-object "$PRECHECK" 2>/dev/null || true)" == "$EXPECT_PRE" && \
          "$(git hash-object "$RELEASE" 2>/dev/null || true)" == "$EXPECT_REL" ]]; then
      RESUME_OK=1
      ok "Estado V9 anterior válido; build/patch não serão repetidos"
    fi
  fi

  if [[ "$RESUME_OK" -ne 1 ]]; then
    bash "$V9" | tee "$LOG"
    PRE_BLOB="$(awk -F= '$1=="prepublish_v9_blob"{print $2;exit}' "$LOG")"
    REL_BLOB="$(awk -F= '$1=="release_v9_blob"{print $2;exit}' "$LOG")"
    CAND_COMPLETE="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name CANDIDATE_COMPLETE -path '*XLX026_CORE_260_CANDIDATE_V2_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
    [[ -n "$PRE_BLOB" && -n "$REL_BLOB" && -f "$CAND_COMPLETE" ]] || { fail "não foi possível registrar estado V9"; exit 30; }
    [[ "$(get_kv "$CAND_COMPLETE" status)" == "CANDIDATE_V2_STATIC_OK" ]] || { fail "Candidate V2 não aprovado"; exit 31; }
    [[ "$(git hash-object "$PRECHECK")" == "$PRE_BLOB" ]] || { fail "prepublish V9 divergente"; exit 32; }
    [[ "$(git hash-object "$RELEASE")" == "$REL_BLOB" ]] || { fail "release V9 divergente"; exit 33; }
    cat > "$STATE" <<EOF
status=V9_READY
prepublish_blob=$PRE_BLOB
release_blob=$REL_BLOB
candidate_complete=$CAND_COMPLETE
candidate_sha=$(get_kv "$CAND_COMPLETE" candidate_sha256)
EOF
    chmod 600 "$STATE"
    ok "Estado resumível V9 gravado em $STATE"
  fi
else
  ok "Core já está em 2.6.0; etapa Candidate V2 não será repetida"
fi

section "4/8 — PUBLICAR/CONFIRMAR CORE 2.6.0"
if [[ "$MODE" == "PRE_CORE" ]]; then
  "$RELEASE"
  CURRENT_VER="$(xml_version)"
  CURRENT_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
  [[ "$CURRENT_VER" == "$EXPECTED_NEW_VERSION" ]] || { fail "release não terminou em 2.6.0"; exit 40; }
fi

CORE_MARK="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name RELEASE_COMPLETE -path '*XLX026_CORE_260_RELEASE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$CORE_MARK" && -f "$CORE_MARK" ]] || { fail "RELEASE_COMPLETE não localizado"; exit 41; }
[[ "$(get_kv "$CORE_MARK" status)" == "RELEASE_OK" ]] || { fail "release do core não está aprovado"; exit 42; }
CORE_SHA="$(get_kv "$CORE_MARK" new_binary_sha)"
[[ -n "$CORE_SHA" && "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "SHA core ativo diverge do release"; exit 43; }
[[ "$(xml_version)" == "$EXPECTED_NEW_VERSION" ]] || { fail "XML ativo não é 2.6.0"; exit 44; }
[[ "$(get_kv "$CORE_MARK" listeners_preserved)" == "yes" ]] || { fail "release não confirmou listeners"; exit 45; }
ok "Core 2.6.0 confirmado: $CORE_SHA"

section "5/8 — PUBLICAR/CONFIRMAR PAINEL v1.1.0"
INDEX="$WEBROOT/index.php"
[[ -f "$INDEX" ]] || { fail "index.php ausente"; exit 50; }
if ! grep -Fq "$PANEL_MARKER" "$INDEX"; then
  "$PANEL_RELEASE"
else
  warn "Painel já contém v1.1.0; validando marcador de release em vez de duplicar"
fi
PANEL_MARK="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name PANEL_RELEASE_COMPLETE -path '*XLX026_PANEL_FOOTER_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$PANEL_MARK" && -f "$PANEL_MARK" ]] || { fail "PANEL_RELEASE_COMPLETE não localizado"; exit 51; }
[[ "$(get_kv "$PANEL_MARK" status)" == "PANEL_RELEASE_OK" ]] || { fail "painel não está aprovado"; exit 52; }
[[ "$(get_kv "$PANEL_MARK" panel_version)" == "$EXPECTED_PANEL_VERSION" ]] || { fail "versão do painel no marcador diverge"; exit 53; }
grep -Fq "$PANEL_MARKER" "$INDEX" || { fail "marcador painel v1.1.0 ausente"; exit 54; }
grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$INDEX" || { fail "link Código do Painel ausente"; exit 55; }
grep -Fq "href=\"$INSTALLER_URL\"" "$INDEX" || { fail "link Instalador ausente"; exit 56; }
ok "Painel v1.1.0 confirmado"

section "6/8 — REGRESSÃO EXTERNA FINAL"
FINAL_OUT="$BACKUP_ROOT/XLX026_PROJECT_COMPLETE_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$FINAL_OUT/http"
chmod 700 "$FINAL_OUT" "$FINAL_OUT/http"
PAGES=("/ao-vivo" "/conectados" "/suporte" "/aprs-dprs" "/ranking" "/certificado" "/simulado-anatel/" "/refletores" "/noticias")
for path in "${PAGES[@]}"; do
  safe="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
  body="$FINAL_OUT/http/page${safe}.html"
  code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || { fail "HTTP final falhou em $path"; exit 60; }
  [[ "$code" == "200" ]] || { fail "HTTP $code em $path"; exit 61; }
  grep -Fq "$PANEL_MARKER" "$body" || { fail "painel v1.1.0 ausente em $path"; exit 62; }
  grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$body" || { fail "Código do Painel ausente em $path"; exit 63; }
  grep -Fq "href=\"$INSTALLER_URL\"" "$body" || { fail "Instalador ausente em $path"; exit 64; }
done

for api in status.php live.php; do
  body="$FINAL_OUT/http/api-${api}.json"
  code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL/api/$api")" || { fail "API $api falhou"; exit 65; }
  [[ "$code" == "200" ]] || { fail "API $api HTTP $code"; exit 66; }
  python3 - "$body" <<'PYAPI'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: json.load(f)
PYAPI
done
MTR="$FINAL_OUT/http/api-mtr.json"
MTR_CODE="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$MTR" -w '%{http_code}' "$BASE_URL/api/mtr.php")"
[[ "$MTR_CODE" == "400" ]] || { fail "contrato MTR HTTP inesperado: $MTR_CODE"; exit 67; }
python3 - "$MTR" <<'PYMTR'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: d=json.load(f)
if d.get('ok') is not False or d.get('error')!='invalid_request': raise SystemExit(1)
PYMTR
ok "9 páginas + status/live + contrato MTR aprovados"

section "7/8 — ENCERRAR AGENTE TEMPORÁRIO"
systemctl disable xlx026-github-agent.timer 2>/dev/null || true
systemctl disable xlx026-github-executor.path 2>/dev/null || true
systemctl stop xlx026-github-agent.timer xlx026-github-agent.service xlx026-github-executor.path xlx026-github-executor.service 2>/dev/null || true
TIMER_STATE="$(systemctl is-active xlx026-github-agent.timer 2>/dev/null || true)"
EXEC_STATE="$(systemctl is-active xlx026-github-executor.path 2>/dev/null || true)"
[[ "$TIMER_STATE" != "active" && "$EXEC_STATE" != "active" ]] || { fail "agente temporário ainda ativo"; exit 70; }
ok "Agente temporário desativado"

section "8/8 — MARCADOR FINAL"
cat > "$FINAL_OUT/PROJECT_COMPLETE" <<EOF
status=PROJECT_COMPLETE
core_version=$EXPECTED_NEW_VERSION
core_sha=$CORE_SHA
panel_version=$EXPECTED_PANEL_VERSION
panel_marker=$PANEL_MARKER
panel_source_url=$PANEL_SOURCE_URL
installer_url=$INSTALLER_URL
pages_validated=9
critical_apis_validated=3
mtr_contract=HTTP_400_invalid_request
listeners_preserved=yes
xlxd_service=ACTIVE
maintenance_agent_timer=$TIMER_STATE
maintenance_executor_path=$EXEC_STATE
core_release_marker=$CORE_MARK
panel_release_marker=$PANEL_MARK
v10_resume_state=$STATE
EOF
chmod 600 "$FINAL_OUT/PROJECT_COMPLETE"
cat "$FINAL_OUT/PROJECT_COMPLETE"
rm -f "$STATE" 2>/dev/null || true
ok "XLX026 FINALIZADO: CORE 2.6.0 + PAINEL v1.1.0"
