from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one replacement target, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


old_admin = r'''# Quando o HTTPS já está disponível, confirme a rota nova antes de declarar
# sucesso. Isso impede concluir uma atualização que criou os arquivos, mas
# deixou /admin/ (ou o nome escolhido) respondendo 404. Em uma instalação
# nova sem certificado ainda, a validação final do instalador cobre HTTPS.
if curl --silent --show-error --insecure --resolve "$DOMAIN:443:127.0.0.1" \
  --connect-timeout 5 --max-time 12 "$BASE_URL/$slug/" -o "$WORK/admin-web.html" 2>/dev/null; then
  grep -Fq "$TITLE" "$WORK/admin-web.html" || fail "$(say 'A rota Admin respondeu, mas não entregou a tela privada correta.' 'Admin route responded but did not deliver the correct private page.')"
  [[ -s "$WORK/admin-web.html" ]] || fail "$(say 'A rota Admin retornou resposta vazia.' 'Admin route returned an empty response.')"
  LOGIN_MARKER="$(say 'Acesso restrito' 'Restricted access')"
  grep -Fq "$LOGIN_MARKER" "$WORK/admin-web.html" || fail "$(say 'A rota Admin não entregou a tela de autenticação.' 'Admin route did not deliver the authentication page.')"
  ok "$(say 'Rota privada do Admin validada localmente.' 'Private Admin route validated locally.')"
else
  warn "$(say 'HTTPS local ainda indisponível; arquivos, credencial e rota foram validados e o teste web será repetido ao fim da instalação.' 'Local HTTPS is not available yet; files, credentials and route were validated and the web test will run at the end of installation.')"
fi
'''
new_admin = r'''# Prove the configured private route over whichever local web scheme is
# actually available at this stage. A pending certificate must not skip it.
ADMIN_SCHEME='http'
ADMIN_PORT='80'
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  ADMIN_SCHEME='https'
  ADMIN_PORT='443'
fi
ADMIN_BASE="$ADMIN_SCHEME://$DOMAIN"
ADMIN_CURL=(curl --silent --show-error --resolve "$DOMAIN:$ADMIN_PORT:127.0.0.1" --connect-timeout 5 --max-time 12)
[[ "$ADMIN_SCHEME" == https ]] && ADMIN_CURL+=(--insecure)
if ! "${ADMIN_CURL[@]}" "$ADMIN_BASE/$slug/" -o "$WORK/admin-web.html"; then
  fail "$(say 'A rota privada do Admin não respondeu localmente.' 'Private Admin route did not respond locally.')"
fi
grep -Fq "$TITLE" "$WORK/admin-web.html" || fail "$(say 'A rota Admin respondeu, mas não entregou a tela privada correta.' 'Admin route responded but did not deliver the correct private page.')"
[[ -s "$WORK/admin-web.html" ]] || fail "$(say 'A rota Admin retornou resposta vazia.' 'Admin route returned an empty response.')"
LOGIN_MARKER="$(say 'Acesso restrito' 'Restricted access')"
grep -Fq "$LOGIN_MARKER" "$WORK/admin-web.html" || fail "$(say 'A rota Admin não entregou a tela de autenticação.' 'Admin route did not deliver the authentication page.')"
ok "$(say "Rota privada do Admin validada localmente por $ADMIN_SCHEME." "Private Admin route validated locally over $ADMIN_SCHEME.")"
'''
replace_once("modules/69-admin-page.sh", old_admin, new_admin)

old_routes = r'''# Page routes must render through the final web edge. Empty current traffic is valid; a
# broken route, stale asset or server error is not.
for page in ao-vivo conectados modulos digital-lab certificado refletores; do
    "${CURL[@]}" "$BASE/?page=$page&fresh_install_probe=1" >/dev/null || fail "Dashboard route failed: $page"
done
ok 'Current dashboard routes validated.'

printf 'ASSET_BUILD_TOKEN=%s\n' "$ASSET_TOKEN"
'''
new_routes = r'''# Canonical public URLs must render through the final web edge. Empty current
# traffic is valid; a broken route, redirect mismatch or server error is not.
for public_path in /ao-vivo /conectados /modulos /ranking /refletores /certificado /aprs-dprs; do
    "${CURL[@]}" "$BASE$public_path?fresh_install_probe=1" >/dev/null || fail "Dashboard route failed: $public_path"
done
ok 'Canonical dashboard routes validated.'

# The private Admin route is also installation readiness. Validate the exact
# saved slug through the same final Nginx/PHP-FPM edge, even while HTTPS waits.
ADMIN_ROUTE_FILE='/etc/xlx-modern-control/route'
[[ -s "$ADMIN_ROUTE_FILE" ]] || fail 'Private Admin route file is missing.'
ADMIN_SLUG="$(tr -d '\r\n' < "$ADMIN_ROUTE_FILE")"
[[ "$ADMIN_SLUG" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || fail 'Private Admin route slug is invalid.'
ADMIN_HTML="$(mktemp /tmp/xlx-admin-readiness.XXXXXX.html)"
cleanup_admin_probe(){ rm -f "$ADMIN_HTML"; }
trap cleanup_admin_probe EXIT
"${CURL[@]}" "$BASE/$ADMIN_SLUG/" -o "$ADMIN_HTML" || fail 'Private Admin route HTTP probe failed.'
[[ -s "$ADMIN_HTML" ]] || fail 'Private Admin route returned an empty response.'
grep -Eq 'Restricted access|Acesso restrito' "$ADMIN_HTML" || fail 'Private Admin route did not render the authentication screen.'
cleanup_admin_probe
trap - EXIT
ok 'Private Admin route validated through the final web edge.'

printf 'ASSET_BUILD_TOKEN=%s\n' "$ASSET_TOKEN"
'''
replace_once("dashboard/install/fresh-install-parity.sh", old_routes, new_routes)

replace_once(
    "modules/70-production-parity.sh",
    '["/aprs-dprs/",200,"html"]',
    '["/aprs-dprs",200,"html"]',
)

Path("tests/test-admin-route-readiness.sh").write_text(r'''#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }

grep -Fq "ADMIN_SCHEME='http'" "$ROOT/modules/69-admin-page.sh" || fail 'Admin installer must probe HTTP when TLS is pending'
grep -Fq 'ADMIN_CURL=(curl' "$ROOT/modules/69-admin-page.sh" || fail 'Admin installer local route probe is missing'
grep -Fq "ADMIN_ROUTE_FILE='/etc/xlx-modern-control/route'" "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'final Admin route probe is missing'
grep -Fq '/ranking /refletores /certificado /aprs-dprs' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'canonical public route gate is incomplete'
grep -Fq '["/aprs-dprs",200,"html"]' "$ROOT/modules/70-production-parity.sh" || fail 'APRS self-test path must use canonical no-slash URL'
if grep -Fq '["/aprs-dprs/",200,"html"]' "$ROOT/modules/70-production-parity.sh"; then fail 'non-canonical APRS self-test path remains'; fi
printf 'OK | private Admin and canonical public route readiness contracts are enforced\n'
''', encoding="utf-8")
