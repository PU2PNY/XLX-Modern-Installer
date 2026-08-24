#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

WEBROOT="/var/www/html/xlxd-novo"
INDEX="$WEBROOT/index.php"
BACKUP_ROOT="/root/backups-xlx026"
BASE_URL="https://xlx026.net"
EXPECTED_INDEX_SHA="1b3df74adc9ddd9eb105916fd97f5325cd3fddf860862d0bd178a137e77aef9e"
EXPECTED_CORE_SHA="10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7"
PANEL_URL="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard"
INSTALLER_URL="https://github.com/PU2PNY/XLX-Modern-Installer"
NEW_TEXT_PANEL="Painel XLX Modern v1.1.0"
NEW_TEXT_INSTALLER="Instalador v2.6.0"

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in cp curl date grep install php python3 sha256sum stat systemctl; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -f "$INDEX" ]] || { fail "index.php ausente"; exit 3; }
[[ "$(sha256sum "$INDEX" | awk '{print $1}')" == "$EXPECTED_INDEX_SHA" ]] || { fail "index.php fora do estado aprovado; nada alterado"; exit 4; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "core 2.6.0 divergiu; nada alterado"; exit 5; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service inativo"; exit 6; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_FOOTER_VERSION_V3_${STAMP}"
TMP="$(mktemp -d /tmp/xlx026-footer-v3.XXXXXX)"
CAND="$TMP/index.php"
MUTATED=0
SUCCESS=0
mkdir -p "$OUT"
chmod 700 "$OUT"

cleanup(){ rm -rf "$TMP"; }
rollback(){
  local reason="$1"
  trap - EXIT
  set +e
  fail "ROLLBACK AUTOMÁTICO DO RODAPÉ: $reason"
  if [[ "$MUTATED" -eq 1 && -f "$OUT/index.php.before" ]]; then
    cp -a "$OUT/index.php.before" "$INDEX"
  fi
  if [[ "$(sha256sum "$INDEX" 2>/dev/null | awk '{print $1}')" == "$EXPECTED_INDEX_SHA" ]]; then
    ok "Rodapé anterior restaurado"
  else
    fail "rollback não pôde ser confirmado"
  fi
  cleanup
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 ]]; then if [[ $MUTATED -eq 1 ]]; then rollback "falha rc=$rc"; else trap - EXIT; cleanup; exit "$rc"; fi; fi' EXIT

section "1/6 — BACKUP"
cp -a "$INDEX" "$OUT/index.php.before"
sha256sum "$OUT/index.php.before" > "$OUT/index.php.before.sha256"
(cd "$OUT" && sha256sum -c index.php.before.sha256)
ok "index.php protegido em $OUT"

section "2/6 — GERAR RODAPÉ EXATO EM CÓPIA"
python3 - "$INDEX" "$CAND" "$PANEL_URL" "$INSTALLER_URL" <<'PY'
import re,sys
src,dst,panel_url,installer_url=sys.argv[1:]
text=open(src,encoding='utf-8').read()
pat=re.compile(r'<small class="footer-final-line">.*?</small>',re.S)
m=pat.findall(text)
if len(m)!=1:
    raise SystemExit(f'[ERRO] footer-final-line count={len(m)}')
old=m[0]
if 'Painel XLX026 v1.1.0' not in old:
    raise SystemExit('[ERRO] rodapé v1.1.0 esperado não encontrado')
new=(
    '<small class="footer-final-line">'
    f'<a href="{panel_url}" target="_blank" rel="noopener noreferrer"><strong>Painel XLX Modern v1.1.0</strong></a>'
    '<span class="footer-separator"> · </span>'
    f'<a href="{installer_url}" target="_blank" rel="noopener noreferrer"><strong>Instalador v2.6.0</strong></a>'
    '</small>'
)
new_text=pat.sub(new,text,count=1)
for forbidden in ('Código do Painel','Instalador XLX Modern'):
    if forbidden in new_text:
        raise SystemExit(f'[ERRO] texto extra ainda presente: {forbidden}')
if new_text.count('Painel XLX Modern v1.1.0')!=1:
    raise SystemExit('[ERRO] texto do painel não ficou único')
if new_text.count('Instalador v2.6.0')!=1:
    raise SystemExit('[ERRO] texto do instalador não ficou único')
if f'href="{panel_url}"' not in new_text:
    raise SystemExit('[ERRO] link do código do painel ausente')
if f'href="{installer_url}"' not in new_text:
    raise SystemExit('[ERRO] link do instalador ausente')
open(dst,'w',encoding='utf-8',newline='').write(new_text)
PY
chown --reference="$INDEX" "$CAND"
chmod --reference="$INDEX" "$CAND"
php -l "$CAND"
grep -Fq 'Painel XLX Modern v1.1.0' "$CAND"
grep -Fq 'Instalador v2.6.0' "$CAND"
! grep -Fq 'Código do Painel' "$CAND"
! grep -Fq 'Instalador XLX Modern' "$CAND"
ok "Rodapé novo validado em cópia"

section "3/6 — PUBLICAÇÃO ATÔMICA"
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
  grep -Fq 'Painel XLX Modern v1.1.0' "$BODY" || { fail "texto do painel ausente em $path"; exit 41; }
  grep -Fq 'Instalador v2.6.0' "$BODY" || { fail "texto do instalador ausente em $path"; exit 42; }
  grep -Fq "href=\"$PANEL_URL\"" "$BODY" || { fail "link painel ausente em $path"; exit 43; }
  grep -Fq "href=\"$INSTALLER_URL\"" "$BODY" || { fail "link instalador ausente em $path"; exit 44; }
  if grep -Fq 'Código do Painel' "$BODY" || grep -Fq 'Instalador XLX Modern' "$BODY"; then
    fail "texto extra ainda presente em $path"; exit 45
  fi
done
ok "9 páginas aprovadas"

section "5/6 — CONFIRMAR CORE INALTERADO"
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$EXPECTED_CORE_SHA" ]] || { fail "core mudou durante alteração do rodapé"; exit 50; }
systemctl is-active --quiet xlxd.service || { fail "xlxd.service ficou inativo"; exit 51; }
ok "Core 2.6.0 permaneceu intacto"

section "6/6 — RELATÓRIO"
NEW_SHA="$(sha256sum "$INDEX" | awk '{print $1}')"
cat > "$OUT/FOOTER_V3_COMPLETE" <<EOF
status=FOOTER_V3_OK
panel_text=$NEW_TEXT_PANEL
panel_url=$PANEL_URL
installer_text=$NEW_TEXT_INSTALLER
installer_url=$INSTALLER_URL
index_sha_before=$EXPECTED_INDEX_SHA
index_sha_after=$NEW_SHA
core_sha=$EXPECTED_CORE_SHA
pages_validated=9
backup=$OUT/index.php.before
EOF
cat "$OUT/FOOTER_V3_COMPLETE"
SUCCESS=1; MUTATED=0
trap - EXIT
cleanup
ok "RODAPÉ FINAL PUBLICADO"
