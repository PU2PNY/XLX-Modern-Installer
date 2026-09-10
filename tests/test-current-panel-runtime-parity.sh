#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n "$ROOT/dashboard/install/fresh-install-parity.sh"
bash -n "$ROOT/modules/60-dashboard-modern.sh"
ok 'fresh-install parity scripts have valid Bash syntax'

# Final-render validation must run after post-install rendering and before later
# Admin/observability stages.
python3 - "$ROOT/modules/60-dashboard-modern.sh" <<'PY'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
a=s.index('install-dashboard.sh')
b=s.index('post-install.sh')
c=s.index('fresh-install-parity.sh')
d=s.index('65-callsign-directory.sh')
assert a < b < c < d, (a,b,c,d)
PY
ok 'parity gate runs on the final rendered dashboard copy'

# The exact source-code leak seen in the v1.2.11 screenshot must never return.
if grep -Fq 'root.innerHTML='"'"'<div class="hamwx-skeleton">${tr(' "$ROOT/dashboard/assets/ham-weather-widget.js"; then
  fail 'weather fallback still prints ${tr(...)} literally'
fi
grep -Fq "esc(tr('Não foi possível carregar clima e propagação agora.'" "$ROOT/dashboard/assets/ham-weather-widget.js" || fail 'safe translated weather fallback missing'
ok 'weather failure renders a translated visitor message'

# The old main-menu Bip proxy was removed from current production. Audio
# features remain in accessibility/Ao Vivo; the compatibility JS must not
# mutate the public navigation.
if grep -Eq '(createElement|insertAdjacentHTML|innerHTML).*(xlxmodern-menu-sound-control|>Bip<)' "$ROOT/dashboard/assets/history-sound-menu-v1.js"; then
  fail 'legacy Bip menu injector is active'
fi
grep -Fq 'XLX_CURRENT_MENU_PARITY_NO_BIP' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'static no-Bip parity rule missing'
ok 'legacy standalone Bip menu control cannot be exposed'

# A fresh installation of the same hostname must receive a new CSS/JS URL and
# cannot reuse browser cache from an older formatted VPS.
grep -Fq 'ASSET_TOKEN=' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'per-install asset token missing'
grep -Fq 'ASSET_REFERENCES_VERSIONED=' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'asset reference rewrite missing'
ok 'per-install asset cache invalidation is enforced'

# Health source currently contains historical exported URL artifacts on main.
# The installer must normalize all of them before modules/71 copies the file.
python3 - "$ROOT/observability/health/health_monitor.py" <<'PY'
import ast,re,sys
s=open(sys.argv[1],encoding='utf-8').read()
pat=re.compile(r'"\'\+PUBLIC_URL\+\'([^"\n]*)"')
fixed,n=pat.subn(lambda m: "PUBLIC_URL + '"+m.group(1)+"'", s)
assert n >= 1, 'expected historical PUBLIC_URL artifacts not found; remove runtime transform and fix test when source is cleaned'
assert "\"'+PUBLIC_URL+'" not in fixed
ast.parse(fixed)
PY
ok 'Health PUBLIC_URL normalization is deterministic and syntax-safe'

# Build every dashboard locale and syntax-check every generated JavaScript
# file, not only app.js. This catches translation corruption in secondary
# widgets such as weather, accessibility and APRS/D-PRS.
if command -v php >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  for locale in pt-BR en es fr de it; do
    target="$tmp/$locale"
    mkdir -p "$target"
    cp -a "$ROOT/dashboard/." "$target/"
    mkdir -p "$target/config"
    printf '%s\n' '<?php return []; ' > "$target/config/site.php"
    php "$ROOT/dashboard/i18n/build.php" "$target" "$locale" >/dev/null
    while IFS= read -r -d '' js; do
      node --check "$js" >/dev/null || fail "generated JS syntax failure: $locale ${js#$target/}"
    done < <(find "$target" -type f -name '*.js' -print0)
    if grep -RIF --include='*.js' -- 'root.innerHTML='"'"'<div class="hamwx-skeleton">${tr(' "$target" >/dev/null; then
      fail "literal weather interpolation returned in $locale build"
    fi
  done
  ok 'all generated JavaScript passes syntax checks in all six locales'
else
  printf '[SKIP] php/node unavailable; locale JS gate runs in CI.\n'
fi

# Runtime install must prove the same APIs used by Connected/Ao Vivo instead of
# accepting a dashboard that merely has files on disk.
grep -Fq 'api/status.php?history_hours=24&fresh_install_probe=1' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'status API runtime probe missing'
grep -Fq 'api/live.php?fresh_install_probe=1' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'live API runtime probe missing'
grep -Fq 'foreach(["xml","log","db"]' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'runtime source validation missing'
ok 'fresh install requires live status/live API and XML/log/DB sources'
