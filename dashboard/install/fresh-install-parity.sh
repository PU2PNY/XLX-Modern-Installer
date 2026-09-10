#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

DASH="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlxd}}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || printf 'dev')"

fail(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || fail 'Run as root / Execute como root.'
[[ -f "$DASH/index.php" ]] || fail "Dashboard index missing: $DASH/index.php"
[[ -f "$DASH/assets/app.js" ]] || fail "Dashboard app.js missing: $DASH/assets/app.js"
[[ -f "$DASH/assets/app.css" ]] || fail "Dashboard app.css missing: $DASH/assets/app.css"
[[ -f "$DASH/assets/ham-weather-widget.js" ]] || fail "Weather widget missing."
[[ -f "$DASH/config/site.php" ]] || fail "Dashboard site config missing."

# A reinstall of the same domain must never reuse JS/CSS cached from an older
# installation. Rewrite every local CSS/JS asset reference with a build token
# unique to this deployed copy, after i18n/template rendering has completed.
ASSET_TOKEN="${VERSION}-$(date -u +%Y%m%d%H%M%S)-$(stat -c %Y "$DASH/assets/app.js")"
python3 - "$DASH/index.php" "$ASSET_TOKEN" <<'PY'
import os,re,sys,tempfile
path=sys.argv[1]
token=sys.argv[2]
text=open(path,encoding='utf-8').read()
pattern=re.compile(r'(assets/[A-Za-z0-9._/-]+\.(?:css|js))(?:\?v=[^\"\'<>\s]*)?')
text,n=pattern.subn(lambda m: m.group(1)+'?v='+token,text)
fd,tmp=tempfile.mkstemp(prefix='.index.',suffix='.tmp',dir=os.path.dirname(path),text=True)
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f:
        f.write(text)
        f.flush(); os.fsync(f.fileno())
    os.chmod(tmp,0o644)
    os.replace(tmp,path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print(f'ASSET_REFERENCES_VERSIONED={n}')
PY

# Current public navigation: sound/beep functionality remains available through
# the panel/accessibility logic, but the obsolete standalone "Bip" menu proxy
# must never be visible. This static rule replaces the old MutationObserver
# approach and has no polling/runtime cost.
if ! grep -Fq 'XLX_CURRENT_MENU_PARITY_NO_BIP' "$DASH/assets/app.css"; then
cat >> "$DASH/assets/app.css" <<'CSS'

/* XLX_CURRENT_MENU_PARITY_NO_BIP */
.universal-nav .xlxmodern-menu-sound-control,
.universal-nav [data-xlx-sound-proxy="1"] {
  display: none !important;
  visibility: hidden !important;
  pointer-events: none !important;
}
CSS
fi

# Reject the exact broken weather fallback observed on fresh v1.2.11 installs:
# a single-quoted string containing ${tr(...)} prints source code to visitors.
if grep -Fq 'root.innerHTML='"'"'<div class="hamwx-skeleton">${tr(' "$DASH/assets/ham-weather-widget.js"; then
    fail 'Broken weather fallback interpolation detected after dashboard build.'
fi

# Reject stale DOM code that recreates the obsolete Bip proxy in public nav.
if grep -Eq '(createElement|insertAdjacentHTML|innerHTML).*(xlxmodern-menu-sound-control|>Bip<)' "$DASH/assets/history-sound-menu-v1.js" 2>/dev/null; then
    fail 'Legacy Bip menu injection detected.'
fi

# Syntax-check every deployed PHP file. JS syntax is checked in CI with Node;
# Debian 12 runtime does not need Node only for dashboard installation.
while IFS= read -r -d '' phpfile; do
    php -l "$phpfile" >/dev/null || fail "PHP syntax failure: $phpfile"
done < <(find "$DASH" -type f -name '*.php' -print0)

DOMAIN="$(php -r '$s=require $argv[1];echo strtolower((string)($s["reflector"]["domain"]??""));' "$DASH/config/site.php")"
[[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || fail 'Invalid dashboard domain in site config.'

SCHEME=http
PORT=80
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
    SCHEME=https
    PORT=443
fi
BASE="$SCHEME://$DOMAIN"
CURL=(curl --noproxy '*' -kfsS --max-time 20 --resolve "$DOMAIN:$PORT:127.0.0.1")

# The dashboard is not considered ready merely because files exist. Exercise
# the same live data APIs the browser uses through Apache on the local server.
status_json="$(${CURL[@]} "$BASE/api/status.php?history_hours=24&fresh_install_probe=1")" || fail 'status.php HTTP probe failed.'
printf '%s' "$status_json" | php -r '
$d=json_decode(stream_get_contents(STDIN),true);
if(!is_array($d)||empty($d["ok"])) exit(1);
if(!isset($d["modules"])||!is_array($d["modules"])||count($d["modules"])<1) exit(2);
$s=$d["sources"]??[];
foreach(["xml","log","db"] as $k){if(empty($s[$k])) exit(3);}
' || fail 'status.php JSON/source validation failed.'
ok 'status.php live data path validated.'

live_json="$(${CURL[@]} "$BASE/api/live.php?fresh_install_probe=1")" || fail 'live.php HTTP probe failed.'
printf '%s' "$live_json" | php -r '
$d=json_decode(stream_get_contents(STDIN),true);
if(!is_array($d)||empty($d["ok"])) exit(1);
' || fail 'live.php JSON validation failed.'
ok 'live.php data path validated.'

# Page routes must render through Apache. Empty current traffic is valid; a
# broken route, stale asset or server error is not.
for page in ao-vivo conectados modulos digital-lab certificado refletores; do
    "${CURL[@]}" "$BASE/?page=$page&fresh_install_probe=1" >/dev/null || fail "Dashboard route failed: $page"
done
ok 'Current dashboard routes validated.'

printf 'ASSET_BUILD_TOKEN=%s\n' "$ASSET_TOKEN"
printf 'PANEL_RUNTIME_PARITY=OK\n'
