#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

WEBROOT="/var/www/html/xlxd-novo"
INDEX="$WEBROOT/index.php"
BACKUP_ROOT="/root/backups-xlx026"
BASE_URL="https://xlx026.net"
EXPECTED_INDEX_SHA="1b3df74adc9ddd9eb105916fd97f5325cd3fddf860862d0bd178a137e77aef9e"
CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
OLD_MARKER="Painel XLX026 v1.1.0"
NEW_BRAND="XLX Modern"
PANEL_VERSION="1.1.0"
INSTALLER_VERSION="2.6.0"
PANEL_SOURCE_URL="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard"
INSTALLER_URL="https://github.com/PU2PNY/XLX-Modern-Installer"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in cp curl date grep install php python3 sed sha256sum stat systemctl; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -f "$INDEX" ]] || { fail "index.php ausente"; exit 3; }
[[ "$(sha256sum "$INDEX" | awk '{print $1}')" == "$EXPECTED_INDEX_SHA" ]] || { fail "index.php fora do estado aprovado"; exit 4; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "core 2.6.0 divergiu"; exit 5; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service inativo"; exit 6; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_FOOTER_VERSION_V2_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-footer-v2.XXXXXX)"
CAND="$TMP/index.php"
mkdir -p "$OUT"
chmod 700 "$OUT"
cp -a "$INDEX" "$OUT/index.php.before"
sha256sum "$OUT/index.php.before" > "$OUT/index.php.before.sha256"

rollback(){
  set +e
  cp -a "$OUT/index.php.before" "$INDEX" 2>/dev/null || true
  php -l "$INDEX" >/dev/null 2>&1 || true
  fail "Rollback do rodapé executado"
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 ]]; then rollback; fi' EXIT

section "1/5 — VALIDAR RODAPÉ ATUAL"
php -l "$INDEX"
[[ "$(grep -Foc "$OLD_MARKER" "$INDEX" || true)" -eq 1 ]] || { fail "marcador atual não é único"; exit 10; }
grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$INDEX" || { fail "link Código do Painel ausente"; exit 11; }
grep -Fq "href=\"$INSTALLER_URL\"" "$INDEX" || { fail "link Instalador ausente"; exit 12; }
ok "Rodapé v1.1.0 identificado"

section "2/5 — GERAR CANDIDATO"
python3 - "$INDEX" "$CAND" "$PANEL_SOURCE_URL" "$INSTALLER_URL" <<'PY'
import re,sys
src,dst,panel_url,installer_url=sys.argv[1:]
text=open(src,encoding='utf-8').read()
pat=re.compile(r'<small class="footer-final-line">.*?</small>',re.S)
items=pat.findall(text)
if len(items)!=1:
    raise SystemExit(f'footer-final-line count={len(items)}')
old=items[0]
if 'Painel XLX026 v1.1.0' not in old:
    raise SystemExit('rodapé v1.1.0 esperado ausente')
new=(
    '<small class="footer-final-line">'
    '<strong>XLX Modern</strong>'
    '<span class="footer-separator">•</span>'
    '<span>Painel v1.1.0</span>'
    '<span class="footer-separator">•</span>'
    '<span>Instalador v2.6.0</span>'
    '<span class="footer-separator">•</span>'
    f'<span><a href="{panel_url}" target="_blank" rel="noopener noreferrer">Código do Painel</a>'
    '<span class="footer-separator"> · </span>'
    f'<a href="{installer_url}" target="_blank" rel="noopener noreferrer">Instalador XLX Modern</a></span>'
    '<span class="footer-separator">•</span>'
    '<span>Desenvolvido por <a href="https://paginacertadigital.com.br/" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span>'
    '</small>'
)
new_text=pat.sub(new,text,count=1)
for token in ('XLX Modern','Painel v1.1.0','Instalador v2.6.0'):
    if new_text.count(token)!=1:
        raise SystemExit(f'{token}: count inesperado')
open(dst,'w',encoding='utf-8',newline='').write(new_text)
PY
chown --reference="$INDEX" "$CAND"
chmod --reference="$INDEX" "$CAND"
php -l "$CAND"
ok "Candidato validado"

section "3/5 — PUBLICAR SOMENTE INDEX.PHP"
install -o "$(stat -c %u "$INDEX")" -g "$(stat -c %g "$INDEX")" -m "$(stat -c %a "$INDEX")" "$CAND" "$INDEX"
php -l "$INDEX"
ok "Rodapé publicado sem restart"

section "4/5 — VALIDAR 9 PÁGINAS"
for path in /ao-vivo /conectados /suporte /aprs-dprs /ranking /certificado /simulado-anatel/ /refletores /noticias; do
  body="$TMP/page.html"
  code="$(curl --fail --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")"
  [[ "$code" == "200" ]] || { fail "$path HTTP $code"; exit 40; }
  grep -Fq 'XLX Modern' "$body" || { fail "XLX Modern ausente em $path"; exit 41; }
  grep -Fq 'Painel v1.1.0' "$body" || { fail "Painel v1.1.0 ausente em $path"; exit 42; }
  grep -Fq 'Instalador v2.6.0' "$body" || { fail "Instalador v2.6.0 ausente em $path"; exit 43; }
done
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "core mudou"; exit 44; }
systemctl is-active --quiet xlxd.service || { fail "xlxd ficou inativo"; exit 45; }
ok "Rodapé confirmado nas 9 páginas; core intacto"

section "5/5 — RESULTADO"
NEW_SHA="$(sha256sum "$INDEX" | awk '{print $1}')"
cat > "$OUT/COMPLETE" <<EOF
status=FOOTER_VERSION_V2_OK
brand=XLX Modern
panel_version=1.1.0
installer_version=2.6.0
index_sha=$NEW_SHA
backup=$OUT/index.php.before
xlxd_restart=no
EOF
cat "$OUT/COMPLETE"
trap - EXIT
rm -rf "$TMP"
ok "XLX Modern · Painel v1.1.0 · Instalador v2.6.0 publicado"
