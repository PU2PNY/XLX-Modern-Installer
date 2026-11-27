#!/usr/bin/env bash
# Long Portuguese texts of the native APRS / D-PRS page (APRS guide, SSID table,
# FAQ, rules) and of the certificate canvas (messages, labels, month names) must
# be translated by WHOLE SENTENCE (keys dlab.* and certjs.*) in en/es/fr/de/it,
# the generated PHP/JS must stay syntactically valid, and the callsign must never
# be translated as "area code"/"prefix".
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

if ! command -v php >/dev/null 2>&1; then
  printf '[SKIP] PHP unavailable; long-text i18n check runs in CI.\n'
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

FILES=(digital-lab-native.php assets/certificado.js)
BAD_CALLSIGN_TERMS=('Vorwahl' 'código de área' 'indicatif régional' 'il tuo prefisso' 'Ihren Code')

for locale in en es fr de it; do
  target="$tmp/build-$locale"
  mkdir -p "$target"
  cp -a "$ROOT/dashboard/." "$target/"
  mkdir -p "$target/config"
  printf '%s\n' '<?php return []; ' > "$target/config/site.php"
  php "$ROOT/dashboard/i18n/build.php" "$target" "$locale" >/dev/null

  php -l "$target/digital-lab-native.php" >/dev/null 2>&1 || fail "PHP syntax broken in $locale digital-lab-native.php"
  if command -v node >/dev/null 2>&1; then
    node --check "$target/assets/certificado.js" >/dev/null 2>&1 || fail "JS syntax broken in $locale certificado.js"
  fi

  php -r '
    $pt = require $argv[1]; $tr = require $argv[2]; $dir = $argv[3]; $files = array_slice($argv, 4);
    $blob = "";
    foreach ($files as $f) { $blob .= file_get_contents($dir . "/" . $f); }
    $bad = [];
    foreach ($pt as $k => $v) {
      if (!preg_match("/^(dlab|certjs)\\./", $k)) continue;
      if (!isset($tr[$k]) || $tr[$k] === "") { $bad[] = "$k missing"; continue; }
      if ($v === $tr[$k]) continue;                     // identical word in this language
      if (str_contains($blob, $v)) $bad[] = $k . ": " . mb_substr($v, 0, 70);
    }
    if ($bad) { fwrite(STDERR, implode("\n", $bad) . "\n"); exit(1); }
  ' "$ROOT/dashboard/i18n/locales/pt-BR.php" "$ROOT/dashboard/i18n/locales/$locale.php" "$target" "${FILES[@]}" \
    || fail "untranslated long text(s) remain in $locale build"

  for term in "${BAD_CALLSIGN_TERMS[@]}"; do
    grep -qF -- "$term" "$ROOT/dashboard/i18n/locales/$locale.php" && fail "callsign mistranslated as '$term' in $locale catalog"
  done
done
ok 'long APRS/D-PRS and certificate texts translated by whole sentence in en/es/fr/de/it'
