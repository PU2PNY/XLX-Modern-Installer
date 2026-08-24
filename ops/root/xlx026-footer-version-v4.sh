#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

WEBROOT="/var/www/html/xlxd-novo"
INDEX="$WEBROOT/index.php"
BACKUP_ROOT="/root/backups-xlx026"
BASE_URL="https://xlx026.net"
EXPECTED_CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
PANEL_URL="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard"
INSTALLER_URL="https://github.com/PU2PNY/XLX-Modern-Installer"
CREDIT_URL="https://paginacertadigital.com.br/"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in cp curl date grep install php python3 sha256sum stat systemctl; do command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }; done
[[ -f "$INDEX" ]] || { fail "index.php ausente"; exit 3; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "core 2.6.0 divergiu; nada alterado"; exit 4; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service inativo"; exit 5; }
php -l "$INDEX" >/dev/null

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_FOOTER_VERSION_V4_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-footer-v4.XXXXXX)"
CAND="$TMP/index.php"
MUTATED=0
SUCCESS=0
mkdir -p "$OUT"; chmod 700 "$OUT"

cleanup(){ rm -rf "$TMP"; }
rollback(){
  local reason="$1"; trap - EXIT; set +e
  fail "ROLLBACK AUTOMÁTICO DO RODAPÉ: $reason"
  if [[ "$MUTATED" -eq 1 && -f "$OUT/index.php.before" ]]; then cp -a "$OUT/index.php.before" "$INDEX"; fi
  php -l "$INDEX" >/dev/null 2>&1 && ok "Rodapé anterior restaurado" || fail "rollback não pôde ser confirmado"
  cleanup; exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; else trap - EXIT; cleanup; exit "$rc"; fi; fi' EXIT

section "1/6 — BACKUP"
cp -a "$INDEX" "$OUT/index.php.before"
sha256sum "$OUT/index.php.before" > "$OUT/index.php.before.sha256"
(cd "$OUT" && sha256sum -c index.php.before.sha256)
ok "index.php protegido em $OUT"

section "2/6 — GERAR RODAPÉ FINAL EM CÓPIA"
python3 - "$INDEX" "$CAND" "$PANEL_URL" "$INSTALLER_URL" "$CREDIT_URL" <<'PY'
import re,sys
src,dst,panel_url,installer_url,credit_url=sys.argv[1:]
text=open(src,encoding='utf-8').read()
pat=re.compile(r'<small class="footer-final-line">.*?</small>',re.S)
found=pat.findall(text)
if len(found)!=1:
    raise SystemExit(f'[ERRO] footer-final-line count={len(found)}')
old=found[0]
allowed=(
    'Painel XLX026 v1.1.0' in old or
    'Painel XLX Modern v1.1.0' in old or
    'paginacertadigital.com.br' in old
)
if not allowed:
    raise SystemExit('[ERRO] rodapé atual não corresponde aos estados conhecidos')
new=(
    '<small class="footer-final-line">'
    f'<a href="{panel_url}" target="_blank" rel="noopener noreferrer"><strong>Painel XLX Modern v1.1.0</strong></a>'
    '<span class="footer-separator"> · </span>'
    f'<a href="{installer_url}" target="_blank" rel="noopener noreferrer"><strong>Instalador v2.6.0</strong></a>'
    '<span class="footer-separator"> · </span>'
    f'<span>Desenvolvido por <a href="{credit_url}" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span>'
    '</small>'
)
new_text=pat.sub(new,text,count=1)
checks=[
 ('Painel XLX Modern v1.1.0',1),
 ('Instalador v2.6.0',1),
 ('Desenvolvido por',1),
 ('paginacertadigital.com.br',1),
]
for token,count in checks:
    if new_text.count(token)!=count:
        raise SystemExit(f'[ERRO] {token!r} count={new_text.count(token)}')
for forbidden in ('Código do Painel','Instalador XLX Modern'):
    if forbidden in new_text:
        raise SystemExit(f'[ERRO] texto extra ainda presente: {forbidden}')
for url in (panel_url,installer_url,credit_url):
    if f'href="{url}"' not in new_text:
        raise SystemExit(f'[ERRO] link ausente: {url}')
open(dst,'w',encoding='utf-8',newline='').write(new_text)
PY
chown --reference="$INDEX" "$CAND"
chmod --reference="$INDEX" "$CAND"
php -l "$CAND"
ok "Rodapé novo validado em cópia"

section "3/6 — PUBLICAÇÃO"
MUTATED=1
install -o "$(stat -c %u "$INDEX")" -g "$(stat -c %g "$INDEX")" -m "$(stat -c %a "$INDEX")" "$CAND" "$INDEX"
php -l "$INDEX"
ok "index.php atualizado"

section "4/6 — VALIDAR 9 PÁGINAS"
PAGES=("/ao-vivo" "/conectados" "/suporte" "/aprs-dprs" "/ranking" "/certificado" "/simulado-anatel/" "/refletores" "/noticias")
for path in "${PAGES[@]}"; do
  BODY="$TMP/page.html"
  CODE="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$BODY" -w '%{http_code}' "$BASE_URL$path")"
  [[ "$CODE" == "200" ]] || { fail "HTTP $CODE em $path"; exit 40; }
  grep -Fq 'Painel XLX Modern v1.1.0' "$BODY" || { fail "texto painel ausente em $path"; exit 41; }
  grep -Fq 'Instalador v2.6.0' "$BODY" || { fail "texto instalador ausente em $path"; exit 42; }
  grep -Fq 'Desenvolvido por' "$BODY" || { fail "crédito ausente em $path"; exit 43; }
  grep -Fq 'href="https://paginacertadigital.com.br/"' "$BODY" || { fail "link Página Certa ausente em $path"; exit 44; }
done
ok "9 páginas aprovadas"

section "5/6 — CONFIRMAR CORE INALTERADO"
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "core mudou"; exit 50; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service ficou inativo"; exit 51; }
ok "Core 2.6.0 permaneceu intacto"

section "6/6 — RELATÓRIO"
NEW_SHA="$(sha256sum "$INDEX" | awk '{print $1}')"
cat > "$OUT/FOOTER_V4_COMPLETE" <<EOF
status=FOOTER_V4_OK
panel_text=Painel XLX Modern v1.1.0
panel_url=$PANEL_URL
installer_text=Instalador v2.6.0
installer_url=$INSTALLER_URL
credit_text=Desenvolvido por paginacertadigital.com.br
credit_url=$CREDIT_URL
index_sha_after=$NEW_SHA
core_sha=$EXPECTED_CORE_SHA
pages_validated=9
backup=$OUT/index.php.before
EOF
cat "$OUT/FOOTER_V4_COMPLETE"
SUCCESS=1; MUTATED=0; trap - EXIT; cleanup
ok "RODAPÉ FINAL PUBLICADO COM CRÉDITO PRESERVADO"
