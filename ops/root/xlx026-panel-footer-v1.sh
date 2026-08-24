#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

PANEL_VERSION="1.1.0"
EXPECTED_CORE_VERSION="2.6.0"
BACKUP_ROOT="/root/backups-xlx026"
WEBROOT="/var/www/html/xlxd-novo"
INDEX="$WEBROOT/index.php"
BASE_URL="https://xlx026.net"
PANEL_SOURCE_URL="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard"
INSTALLER_URL="https://github.com/PU2PNY/XLX-Modern-Installer"
OLD_MARKER="Painel XLX-Modern — v1.0"
NEW_MARKER="Painel XLX026 v${PANEL_VERSION}"

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
get_kv(){ awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk cp curl date find grep head php python3 sed sha256sum sort stat tar tee wc xargs; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -d "$WEBROOT" && -f "$INDEX" ]] || { fail "webroot/index.php ausente"; exit 3; }

RELEASE_MARK="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name RELEASE_COMPLETE -path '*XLX026_CORE_260_RELEASE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$RELEASE_MARK" && -f "$RELEASE_MARK" ]] || { fail "RELEASE_COMPLETE do core não encontrado"; exit 4; }
[[ "$(get_kv "$RELEASE_MARK" status)" == "RELEASE_OK" ]] || { fail "release do core não aprovado"; exit 5; }
CORE_SHA="$(get_kv "$RELEASE_MARK" new_binary_sha)"
[[ -n "$CORE_SHA" ]] || { fail "SHA novo do core ausente no marcador"; exit 6; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "core ativo não coincide com release aprovado"; exit 7; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "XML não está em 2.6.0"; exit 8; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_PANEL_FOOTER_${STAMP}"
mkdir -p "$OUT/http"
chmod 700 "$OUT" "$OUT/http"
exec > >(tee "$OUT/execution.log") 2>&1

MUTATED=0
SUCCESS=0
TMP="$WEBROOT/.index.php.footer-${STAMP}"

rollback(){
  local why="$1"
  trap - EXIT
  set +e
  fail "ROLLBACK WEB AUTOMÁTICO: $why"
  if [[ "$MUTATED" -eq 1 && -f "$OUT/index.php.before" ]]; then
    cp -a "$OUT/index.php.before" "$TMP" 2>/dev/null || true
    mv -f "$TMP" "$INDEX" 2>/dev/null || true
  fi
  current="$(sha256sum "$INDEX" 2>/dev/null | awk '{print $1}')"
  expected="$(awk '{print $1}' "$OUT/index.php.before.sha256" 2>/dev/null)"
  if [[ -n "$expected" && "$current" == "$expected" ]]; then
    cat > "$OUT/PANEL_ROLLBACK_COMPLETE" <<EOF
status=PANEL_ROLLBACK_OK
reason=$why
index_sha=$current
EOF
    ok "Rodapé anterior restaurado"
  else
    cat > "$OUT/PANEL_ROLLBACK_FAILED" <<EOF
status=PANEL_ROLLBACK_FAILED
reason=$why
index_sha=$current
expected_sha=$expected
EOF
    fail "rollback do painel não pôde ser confirmado"
  fi
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 ]]; then rollback "falha inesperada rc=$rc"; else trap - EXIT; rm -f "$TMP"; exit "$rc"; fi; fi' EXIT

section "1/7 — VALIDAR RODAPÉ ATUAL"
OLD_COUNT="$(grep -Foc "$OLD_MARKER" "$INDEX" || true)"
NEW_COUNT="$(grep -Foc "$NEW_MARKER" "$INDEX" || true)"
[[ "$NEW_COUNT" -eq 0 ]] || { fail "painel já contém $NEW_MARKER; abortando para evitar duplicação"; exit 10; }
[[ "$OLD_COUNT" -eq 1 ]] || { fail "marcador antigo deveria ocorrer exatamente 1 vez; encontrado=$OLD_COUNT"; exit 11; }
FOOTER_CLASS_COUNT="$(grep -Foc 'class="footer-final-line"' "$INDEX" || true)"
[[ "$FOOTER_CLASS_COUNT" -eq 1 ]] || { fail "footer-final-line deveria ocorrer exatamente 1 vez; encontrado=$FOOTER_CLASS_COUNT"; exit 12; }
php -l "$INDEX"
ok "Rodapé atual identificado de forma inequívoca"

section "2/7 — BACKUP COMPLETO DO WEBROOT"
cp -a "$INDEX" "$OUT/index.php.before"
sha256sum "$OUT/index.php.before" > "$OUT/index.php.before.sha256"
tar -C /var/www/html -czpf "$OUT/xlxd-novo.before.tar.gz" xlxd-novo
sha256sum "$OUT/xlxd-novo.before.tar.gz" > "$OUT/xlxd-novo.before.tar.gz.sha256"
(cd "$OUT" && sha256sum -c index.php.before.sha256 && sha256sum -c xlxd-novo.before.tar.gz.sha256)
ok "Webroot completo e index.php protegidos"

section "3/7 — GERAR PATCH MÍNIMO"
python3 - "$INDEX" "$TMP" "$PANEL_VERSION" "$PANEL_SOURCE_URL" "$INSTALLER_URL" <<'PY'
import re,sys
src,dst,version,panel_url,installer_url=sys.argv[1:]
text=open(src,encoding='utf-8').read()
pat=re.compile(r'<small class="footer-final-line">.*?</small>', re.S)
m=pat.findall(text)
if len(m)!=1:
    raise SystemExit(f'footer-final-line count={len(m)}')
old=m[0]
if 'Painel XLX-Modern — v1.0' not in old or 'paginacertadigital.com.br' not in old:
    raise SystemExit('rodapé esperado não confere')
new=(
    '<small class="footer-final-line">'
    f'<strong>Painel XLX026 v{version}</strong>'
    '<span class="footer-separator">•</span>'
    f'<span><a href="{panel_url}" target="_blank" rel="noopener noreferrer">Código do Painel</a>'
    '<span class="footer-separator"> · </span>'
    f'<a href="{installer_url}" target="_blank" rel="noopener noreferrer">Instalador XLX Modern</a></span>'
    '<span class="footer-separator">•</span>'
    '<span>Desenvolvido por <a href="https://paginacertadigital.com.br/" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span>'
    '</small>'
)
new_text=pat.sub(new,text,count=1)
if new_text.count(f'Painel XLX026 v{version}')!=1:
    raise SystemExit('novo marcador não ficou único')
if f'href="{panel_url}"' not in new_text:
    raise SystemExit('href do código do painel ausente')
if f'href="{installer_url}"' not in new_text:
    raise SystemExit('href do instalador ausente')
open(dst,'w',encoding='utf-8',newline='').write(new_text)
PY
chown --reference="$INDEX" "$TMP"
chmod --reference="$INDEX" "$TMP"
php -l "$TMP"
[[ "$(grep -Foc "$NEW_MARKER" "$TMP")" -eq 1 ]]
grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$TMP"
grep -Fq "href=\"$INSTALLER_URL\"" "$TMP"
ok "Patch mínimo validado antes da publicação"

section "4/7 — PUBLICAÇÃO ATÔMICA DO INDEX"
MUTATED=1
mv -f "$TMP" "$INDEX"
php -l "$INDEX"
[[ "$(grep -Foc "$NEW_MARKER" "$INDEX")" -eq 1 ]] || { fail "novo marcador ausente após publicação"; exit 40; }
grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$INDEX" || { fail "link do código ausente"; exit 41; }
grep -Fq "href=\"$INSTALLER_URL\"" "$INDEX" || { fail "link do instalador ausente"; exit 42; }
ok "index.php atualizado"

section "5/7 — VALIDAR TODAS AS PÁGINAS"
PAGES=("/ao-vivo" "/conectados" "/suporte" "/aprs-dprs" "/ranking" "/certificado" "/simulado-anatel/" "/refletores" "/noticias")
: > "$OUT/http/pages.tsv"
for path in "${PAGES[@]}"; do
  safe="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
  body="$OUT/http/page${safe}.html"
  code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || { fail "HTTP falhou em $path"; exit 50; }
  [[ "$code" == "200" ]] || { fail "HTTP $code em $path"; exit 51; }
  grep -Fq "$NEW_MARKER" "$body" || { fail "novo rodapé não aparece em $path"; exit 52; }
  grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$body" || { fail "link Código do Painel ausente em $path"; exit 53; }
  grep -Fq "href=\"$INSTALLER_URL\"" "$body" || { fail "link Instalador ausente em $path"; exit 54; }
  printf '%s\t%s\t%s\n' "$path" "$code" "$(wc -c < "$body")" >> "$OUT/http/pages.tsv"
done
ok "Rodapé confirmado nas 9 páginas públicas"

section "6/7 — CONFIRMAR CORE INALTERADO"
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "core mudou durante ajuste do painel"; exit 60; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "XML do core mudou durante ajuste do painel"; exit 61; }
ok "Core 2.6.0 permaneceu intacto"

section "7/7 — RELATÓRIO FINAL DO PAINEL"
NEW_INDEX_SHA="$(sha256sum "$INDEX" | awk '{print $1}')"
find "$OUT" -type f ! -name execution.log ! -name PANEL_RELEASE_COMPLETE ! -name PANEL-MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > "$OUT/PANEL-MANIFEST.sha256"
cat > "$OUT/PANEL_RELEASE_COMPLETE" <<EOF
status=PANEL_RELEASE_OK
path=$OUT
panel_version=$PANEL_VERSION
index_sha=$NEW_INDEX_SHA
core_version=$EXPECTED_CORE_VERSION
core_sha=$CORE_SHA
panel_source_url=$PANEL_SOURCE_URL
installer_url=$INSTALLER_URL
pages_validated=9
webroot_backup=$OUT/xlxd-novo.before.tar.gz
index_backup=$OUT/index.php.before
EOF
chmod 600 "$OUT/PANEL_RELEASE_COMPLETE" "$OUT/PANEL-MANIFEST.sha256"
cat "$OUT/PANEL_RELEASE_COMPLETE"
SUCCESS=1; MUTATED=0
trap - EXIT
ok "PAINEL XLX026 v1.1.0 PUBLICADO E VALIDADO — rollback web preservado"
