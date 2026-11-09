#!/usr/bin/env bash
# Core dashboard pages (Ao vivo, Conectados, Módulos, Refletores, Ranking,
# accessibility, weather and MTR widgets) must be fully translated in every
# non-Portuguese build, without mixed-language fragments, and every generated
# JS/PHP file must remain syntactically valid.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

if ! command -v php >/dev/null 2>&1; then
  printf '[SKIP] PHP unavailable; core i18n check runs in CI.\n'
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

CORE_FILES=(
  index.php ranking-v2-view.php
  assets/app.js assets/ao-vivo-authorized-sync-v1.js assets/mtr.js
  assets/radioid-repeater-enrich-v1.js assets/helix-shadow-monitor-v1.js
)

# Mixed fragments observed before whole-phrase keys existed.
MIXED_FRAGMENTS=(
  'Waiting for a próxima' 'All os países' 'Failure ao carregar' 'Operator ouvido'
  'Protocol em uso' 'últimos 7 days' 'últimos 30 days' 'Time mais ativo'
  'Connected agora' 'Nenhuma station' 'estações connected' 'XLX zero vinte e seis'
)

for locale in en es fr de it; do
  target="$tmp/build-$locale"
  mkdir -p "$target"
  cp -a "$ROOT/dashboard/." "$target/"
  mkdir -p "$target/config"
  printf '%s\n' '<?php return []; ' > "$target/config/site.php"
  php "$ROOT/dashboard/i18n/build.php" "$target" "$locale" >/dev/null

  while IFS= read -r -d '' file; do
    php -l "$file" >/dev/null 2>&1 || fail "PHP syntax broken in $locale build: ${file#"$target/"}"
  done < <(find "$target" -name '*.php' -not -path '*/i18n/*' -print0)
  if command -v node >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      node --check "$file" >/dev/null 2>&1 || fail "JS syntax broken in $locale build: ${file#"$target/"}"
    done < <(find "$target" -name '*.js' -not -path '*/i18n/*' -print0)
  fi

  for fragment in "${MIXED_FRAGMENTS[@]}"; do
    for f in "${CORE_FILES[@]}"; do
      grep -qF -- "$fragment" "$target/$f" && fail "mixed-language fragment '$fragment' in $locale $f"
    done
  done

  # Every whole-phrase pt source key must be gone from the core files unless
  # the target translation is literally identical (e.g. Spanish 'Última consulta:').
  php -r '
    $pt = require $argv[1]; $tr = require $argv[2]; $dir = $argv[3]; $files = array_slice($argv, 4);
    $blob = "";
    foreach ($files as $f) { $blob .= file_get_contents($dir . "/" . $f); }
    $bad = [];
    foreach ($pt as $k => $v) {
      if (!str_starts_with($k, "core.fix.") || $v === ($tr[$k] ?? null)) continue;
      if (str_contains($blob, $v)) $bad[] = $v;
    }
    if ($bad) { fwrite(STDERR, implode("\n", $bad) . "\n"); exit(1); }
  ' "$ROOT/dashboard/i18n/locales/pt-BR.php" "$ROOT/dashboard/i18n/locales/$locale.php" "$target" "${CORE_FILES[@]}" \
    || fail "untranslated core phrase(s) remain in $locale build"

  # data-label (visible mobile caption) is translated.
  grep -qF 'data-label="Horário TX"' "$target/assets/app.js" && fail "data-label not translated in $locale"

  # Unknown-gateway sentinel is compared against the translated API label.
  grep -qF "String('Não identificado')" "$target/assets/app.js" && fail "unknown-gateway literal not translated in $locale"
done
ok 'core dashboard pages fully translated in en/es/fr/de/it with valid JS/PHP'

# Weather widget: es/fr/de/it get their own text, not English or Portuguese.
if command -v node >/dev/null 2>&1; then
  node - "$ROOT/dashboard/assets/ham-weather-widget.js" <<'JS' || fail 'weather widget translation table'
const src=require('fs').readFileSync(process.argv[2],'utf8');
const m=src.match(/const T=(\{.*?\});\n/s); if(!m) throw new Error('T table missing');
const T=JSON.parse(m[1]);
const en=[...src.matchAll(/tr\((?:'[^']*'|"[^"]*")\s*,\s*('([^']*)'|"([^"]*)")\)/g)].map(x=>x[2]??x[3]);
for(const l of ['es','fr','de','it']) for(const k of en){ if(!(k in T[l])) throw new Error(`${l} missing: ${k}`); }
JS
  ok 'weather widget has es/fr/de/it text for every visible label'
fi

# PHP sentinel: mb-safe uppercase so "Não identificado" is recognised.
grep -qF "mb_strtoupper(\$text, 'UTF-8')" "$ROOT/dashboard/api/live.php" || fail 'live.php gateway sentinel is not multibyte-safe'
ok 'live.php unknown-gateway sentinel is multibyte-safe'

# Helix badge must not rewrite the observed subtree unconditionally.
grep -qF 'dataset.helixSignature===signature' "$ROOT/dashboard/assets/helix-shadow-monitor-v1.js" || fail 'helix badge observer loop guard missing'
grep -qF 'document.hidden' "$ROOT/dashboard/assets/helix-shadow-monitor-v1.js" || fail 'helix polling does not pause on hidden tabs'
ok 'helix badge has observer-loop guard and pauses in hidden tabs'
