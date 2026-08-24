#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

EXPECTED_PROD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"
EXPECTED_UPSTREAM="a79a3bf8d883bd35911a34648d71e6980726b4e8"
EXPECTED_XML_VERSION="2.5.3"
BACKUP_ROOT="/root/backups-xlx026"
LAB_ROOT="/root/xlx026-lab"
PROD_BIN="/xlxd/xlxd"
PROD_SRC="/usr/src/xlxd"
WEBROOT="/var/www/html/xlxd-novo"
BASE_URL="https://xlx026.net"

ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk curl find grep pgrep python3 readlink sha256sum sort ss systemctl tar; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_PREPUBLISH_${STAMP}"
mkdir -p "$OUT/http"
chmod 700 "$OUT" "$OUT/http"
exec > >(tee "$OUT/execution.log") 2>&1

get_kv(){
  local file="$1" key="$2"
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$file"
}

section "1/8 — CANDIDATO FINALIZADO"
COMPLETE="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name CANDIDATE_COMPLETE -path '*XLX026_CORE_260_CANDIDATE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$COMPLETE" && -f "$COMPLETE" ]] || { fail "CANDIDATE_COMPLETE não encontrado"; exit 10; }

STATUS="$(get_kv "$COMPLETE" status)"
CAND_BIN="$(get_kv "$COMPLETE" candidate_binary)"
CAND_SHA="$(get_kv "$COMPLETE" candidate_sha256)"
UPSTREAM_SHA="$(get_kv "$COMPLETE" upstream_sha)"
MARKER_PROD_SHA="$(get_kv "$COMPLETE" production_binary_sha)"
CAND_TREE="$(get_kv "$COMPLETE" candidate_tree)"

[[ "$STATUS" == "CANDIDATE_STATIC_OK" ]] || { fail "status do candidato não aprovado: $STATUS"; exit 11; }
[[ "$UPSTREAM_SHA" == "$EXPECTED_UPSTREAM" ]] || { fail "upstream SHA inesperado: $UPSTREAM_SHA"; exit 12; }
[[ -x "$CAND_BIN" ]] || { fail "binário candidato ausente/não executável: $CAND_BIN"; exit 13; }
[[ -d "$CAND_TREE/.git" ]] || { fail "árvore candidata ausente: $CAND_TREE"; exit 14; }

REAL_CAND="$(readlink -f "$CAND_BIN")"
REAL_TREE="$(readlink -f "$CAND_TREE")"
[[ "$REAL_CAND" == "$BACKUP_ROOT"/XLX026_CORE_260_CANDIDATE_*/xlxd-core-2.6.0-candidate ]] || { fail "caminho do candidato fora do padrão permitido"; exit 15; }
[[ "$REAL_TREE" == "$LAB_ROOT"/XLX026-Core-2.6.0-candidate_* ]] || { fail "árvore candidata fora do laboratório permitido"; exit 16; }

ACTUAL_CAND_SHA="$(sha256sum "$CAND_BIN" | awk '{print $1}')"
[[ -n "$CAND_SHA" && "$ACTUAL_CAND_SHA" == "$CAND_SHA" ]] || { fail "SHA do candidato diverge do marcador"; exit 17; }
ACTUAL_TREE_HEAD="$(git -C "$CAND_TREE" rev-parse HEAD)"
[[ "$ACTUAL_TREE_HEAD" == "$EXPECTED_UPSTREAM" ]] || { fail "HEAD da árvore candidata diverge"; exit 18; }
cp -a "$COMPLETE" "$OUT/CANDIDATE_COMPLETE.input"
ok "Candidato estático aprovado e íntegro: $CAND_SHA"

section "2/8 — PRODUÇÃO IMUTÁVEL DESDE O BUILD"
[[ -x "$PROD_BIN" ]] || { fail "binário de produção ausente"; exit 20; }
PROD_SHA="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
[[ "$PROD_SHA" == "$EXPECTED_PROD_SHA" ]] || { fail "SHA de produção diferente do baseline aprovado"; exit 21; }
[[ "$MARKER_PROD_SHA" == "$PROD_SHA" ]] || { fail "produção mudou desde a finalização do candidato"; exit 22; }

mapfile -t PIDS < <(pgrep -x xlxd || true)
[[ ${#PIDS[@]} -eq 1 ]] || { fail "esperado exatamente 1 processo xlxd; encontrados ${#PIDS[@]}"; exit 23; }
ok "Produção ainda é o baseline 2.5.3 aprovado"

section "3/8 — SYSTEMD E COMANDO REAL"
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está active"; exit 30; }
MAINPID="$(systemctl show xlxd.service -p MainPID --value)"
[[ "$MAINPID" == "${PIDS[0]}" ]] || { fail "MainPID do systemd não coincide com pgrep"; exit 31; }
systemctl show xlxd.service -p Id -p ActiveState -p SubState -p MainPID -p FragmentPath -p ExecStart > "$OUT/xlxd-systemd.txt"
grep -Fq '/xlxd/xlxd' "$OUT/xlxd-systemd.txt" || { fail "ExecStart não aponta para /xlxd/xlxd"; exit 32; }
cat "$OUT/xlxd-systemd.txt"
ok "Unidade systemd e processo consistentes"

section "4/8 — XML, LISTENERS E LOGS"
[[ -r /var/log/xlxd.xml ]] || { fail "XML de status ausente"; exit 40; }
cp -a /var/log/xlxd.xml "$OUT/xlxd.xml.before"
XML_VERSION="$(sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml | head -1)"
[[ "$XML_VERSION" == "$EXPECTED_XML_VERSION" ]] || { fail "versão XML pré-publicação inesperada: $XML_VERSION"; exit 41; }

ss -lunp > "$OUT/udp-listeners.before.txt"
grep -F 'xlxd' "$OUT/udp-listeners.before.txt" > "$OUT/xlxd-udp-listeners.before.txt" || true
LISTENER_COUNT="$(wc -l < "$OUT/xlxd-udp-listeners.before.txt")"
[[ "$LISTENER_COUNT" -ge 9 ]] || { fail "poucos listeners UDP atribuídos ao xlxd: $LISTENER_COUNT"; exit 42; }

tail -n 300 /var/log/xlx.log > "$OUT/xlx.log.tail.before.txt" 2>/dev/null || true
if grep -Eqi 'Address already in use|bind.*failed|segmentation fault|core dumped' "$OUT/xlx.log.tail.before.txt"; then
  warn "Há mensagens críticas no recorte de log; revisar relatório antes de publicação"
fi
echo "xml_version=$XML_VERSION"
echo "xlxd_udp_listener_lines=$LISTENER_COUNT"
ok "XML e listeners capturados"

section "5/8 — MATRIZ HTTP DO PAINEL"
PAGES=(
  "/ao-vivo"
  "/conectados"
  "/suporte"
  "/aprs-dprs"
  "/ranking"
  "/certificado"
  "/simulado-anatel/"
  "/refletores"
  "/noticias"
)
: > "$OUT/http-pages.tsv"
for path in "${PAGES[@]}"; do
  safe="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
  body="$OUT/http/page${safe}.html"
  code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || {
    fail "HTTP falhou em $path"
    exit 50
  }
  [[ "$code" == "200" ]] || { fail "HTTP $code em $path"; exit 51; }
  bytes="$(wc -c < "$body")"
  [[ "$bytes" -ge 500 ]] || { fail "resposta muito pequena em $path: $bytes bytes"; exit 52; }
  printf '%s\t%s\t%s\n' "$path" "$code" "$bytes" | tee -a "$OUT/http-pages.tsv"
done
ok "Todas as 9 páginas públicas responderam HTTP 200"

section "6/8 — APIS CRÍTICAS"
APIS=("/api/status.php" "/api/live.php" "/api/mtr.php")
: > "$OUT/http-apis.tsv"
for path in "${APIS[@]}"; do
  safe="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
  body="$OUT/http/api${safe}.json"
  code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || {
    fail "API falhou em $path"
    exit 60
  }
  [[ "$code" == "200" ]] || { fail "API HTTP $code em $path"; exit 61; }
  python3 - "$body" <<'PY'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f:
    json.load(f)
PY
  bytes="$(wc -c < "$body")"
  printf '%s\t%s\t%s\n' "$path" "$code" "$bytes" | tee -a "$OUT/http-apis.tsv"
done
ok "APIs críticas responderam HTTP 200 e JSON válido"

section "7/8 — WEBROOT, FONTE E RECURSOS"
[[ -d "$WEBROOT" ]] || { fail "webroot não encontrado: $WEBROOT"; exit 70; }
[[ -f "$WEBROOT/index.php" ]] || { fail "index.php do painel não encontrado"; exit 71; }
sha256sum "$WEBROOT/index.php" > "$OUT/web-index.before.sha256"

if [[ -d "$PROD_SRC/.git" ]]; then
  git -C "$PROD_SRC" rev-parse HEAD > "$OUT/production-source-head.before.txt" 2>/dev/null || true
  git -C "$PROD_SRC" status --short --branch > "$OUT/production-source-status.before.txt" 2>/dev/null || true
fi

df -Pk /root "$WEBROOT" > "$OUT/disk.before.txt"
AVAIL_KB="$(df -Pk /root | awk 'NR==2 {print $4}')"
[[ "${AVAIL_KB:-0}" -ge 1048576 ]] || { fail "menos de 1 GiB livre em /root"; exit 72; }
ok "Webroot, fonte e espaço aprovados"

section "8/8 — MANIFESTO PRE-PUBLISH"
find "$OUT" -type f ! -name 'PREPUBLISH_COMPLETE' ! -name 'PREPUBLISH-MANIFEST.sha256' -print0 | sort -z | xargs -0 sha256sum > "$OUT/PREPUBLISH-MANIFEST.sha256"
cat > "$OUT/PREPUBLISH_COMPLETE" <<EOF
status=PREPUBLISH_OK
path=$OUT
candidate_complete=$COMPLETE
candidate_binary=$CAND_BIN
candidate_sha256=$CAND_SHA
candidate_tree=$CAND_TREE
upstream_sha=$EXPECTED_UPSTREAM
production_sha=$PROD_SHA
production_xml_version=$XML_VERSION
xlxd_service=xlxd.service
xlxd_mainpid=$MAINPID
xlxd_udp_listener_lines=$LISTENER_COUNT
panel_pages_ok=9
critical_apis_ok=3
webroot=$WEBROOT
EOF
chmod 600 "$OUT/PREPUBLISH_COMPLETE" "$OUT/PREPUBLISH-MANIFEST.sha256"
cat "$OUT/PREPUBLISH_COMPLETE"
ok "PRE-PUBLISH APROVADO — nenhuma alteração de produção foi feita"
