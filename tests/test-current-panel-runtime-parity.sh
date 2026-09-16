#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n "$ROOT/dashboard/install/fresh-install-parity.sh"
bash -n "$ROOT/modules/60-dashboard-modern.sh"
ok 'fresh-install parity scripts have valid Bash syntax'

# Array expansion must stay quoted. The --noproxy '*' argument otherwise
# expands to filenames/directories in the repository and curl treats them as
# extra hosts/URLs (the clean-install failure reported as hosts like log/templates).
grep -Fq 'status_json="$("${CURL[@]}"' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'status curl array expansion is unquoted'
grep -Fq 'live_json="$("${CURL[@]}"' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'live curl array expansion is unquoted'
ok 'fresh-install curl array expansion is protected from wildcard globbing'

# Full-install runtime parity must validate the FINAL stack, never the temporary
# Apache state created by the upstream base installer.
python3 - "$ROOT/install.sh" "$ROOT/modules/60-dashboard-modern.sh" <<'PY'
import sys
install=open(sys.argv[1],encoding='utf-8').read()
module=open(sys.argv[2],encoding='utf-8').read()
a=install.index('modules/60-dashboard-modern.sh', install.index('execute_installer()'))
b=install.index('modules/70-nginx.sh', a)
c=install.index('modules/67-aprs-dprs.sh', b)
d=install.index('modules/71-observability.sh', c)
e=install.index('dashboard/install/fresh-install-parity.sh', d)
assert a < b < c < d < e, (a,b,c,d,e)
assert 'fresh-install-parity.sh' not in module
assert 'XLX_EXPECT_WEB_STACK=nginx' in install[e-200:e+300]
PY
ok 'full-install parity gate runs only after Nginx, APRS/D-PRS and observability'


# The upstream base installer starts Apache on port 80. The Nginx migration must
# stop Apache before the first Nginx start or a clean install fails with EADDRINUSE.
python3 - "$ROOT/modules/70-nginx.sh" <<'PYPORT'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
stop=s.index('systemctl disable --now apache2')
start=s.index('systemctl enable --now nginx')
assert stop < start, (stop,start)
PYPORT
ok 'Apache releases port 80 before Nginx starts'

# Preflight on a pristine Debian host must not require PHP before the base installer
# has had a chance to install it. Runtime provisioning still requires PHP.
python3 - "$ROOT/modules/67-aprs-dprs.sh" <<'PYAPRS'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
assert 'if command -v php >/dev/null 2>&1; then' in s
assert 'elif [[ "$MODE" != check ]]' in s
assert 'PHP CLI ausente para provisionar APRS/D-PRS.' in s
PYAPRS
ok 'clean-host APRS preflight does not require preinstalled PHP'

# Observability has the same clean-host contract: check mode may run before PHP exists.
python3 - "$ROOT/modules/71-observability.sh" <<'PYOBS'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
assert 'if command -v php >/dev/null 2>&1; then' in s
assert 'elif [[ "$MODE" != check ]]' in s
assert 'PHP CLI ausente para provisionar observabilidade.' in s
PYOBS
ok 'clean-host observability preflight does not require preinstalled PHP'

# A nonzero Health bootstrap count must identify the exact checks instead of
# printing only an opaque warnings_or_failures=N total.
grep -Fq 'HEALTH_NON_OK=' "$ROOT/modules/71-observability.sh" || fail 'Health bootstrap non-OK count missing'
grep -Fq '[WARNING] Health check {key}:' "$ROOT/modules/71-observability.sh" || fail 'Health bootstrap per-check diagnostic missing'
grep -Fq '/var/lib/xlx-modern-health-monitor/operational.json' "$ROOT/modules/71-observability.sh" || fail 'Health bootstrap diagnostic is not based on the generated snapshot'
ok 'Health bootstrap reports each non-OK check without failing expected warning states'

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

# Health source must already be correct in Git. Installation/parity may validate it,
# but must never rewrite tracked source files in the user's clone.
python3 - "$ROOT/observability/health/health_monitor.py" "$ROOT/dashboard/install/fresh-install-parity.sh" <<'PYHEALTH'
import ast,sys
health=open(sys.argv[1],encoding='utf-8').read()
parity=open(sys.argv[2],encoding='utf-8').read()
assert "\"'+PUBLIC_URL+'" not in health, 'historical PUBLIC_URL artifact remains in Git source'
ast.parse(health)
for route in ("/api/status.php?history_hours=24&control=1", "/api/status.php?control=1"):
    assert "PUBLIC_URL + '"+route+"'" in health, f'runtime PUBLIC_URL expression missing: {route}'
assert "with open(path,'w'" not in parity, 'fresh-install parity still rewrites Health source'
assert 'Health source is immutable and URL expressions are valid.' in parity
PYHEALTH
ok 'Health source is clean in Git and fresh-install parity is read-only for installer source'

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
grep -Fq 'Runtime XML/log/database sources are readable by www-data.' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'filesystem runtime source validation missing'
grep -Fq 'foreach(["xml","log","db"]' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'status payload source validation missing'
grep -Fq 'Final web stack is Nginx + PHP-FPM; Apache is inactive.' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'final Nginx stack gate missing'
ok 'fresh install requires live status/live API and XML/log/DB sources'

for entry in install.sh recover-incomplete-install.sh tests/run-all.sh; do
  grep -Fq 'export PYTHONDONTWRITEBYTECODE=1' "$ROOT/$entry" || fail "$entry does not prevent Python bytecode pollution"
done
ok 'installer, recovery and regression suite prevent Python bytecode pollution'
