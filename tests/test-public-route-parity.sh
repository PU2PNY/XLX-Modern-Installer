#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }
for f in dashboard/support-native.php dashboard/assets/support-native.css dashboard/assets/support-native.js dashboard/simulado-anatel-view.php dashboard/simulado-anatel/index.php dashboard/assets/simulado-anatel.css dashboard/assets/simulado-anatel-questions.js dashboard/assets/simulado-anatel-engine.js dashboard/assets/simulado-anatel.js; do [[ -s "$ROOT/$f" ]] || fail "missing public parity component: $f"; done
grep -Fq "'suporte' => 'Suporte'" "$ROOT/dashboard/index.php" || fail 'Support nav route missing'
grep -Fq "'simulado-anatel' => 'Simulado ANATEL'" "$ROOT/dashboard/index.php" || fail 'ANATEL simulator nav route missing'
grep -Fq "require __DIR__.'/support-native.php'" "$ROOT/dashboard/index.php" || fail 'Support view wiring missing'
grep -Fq "require __DIR__.'/simulado-anatel-view.php'" "$ROOT/dashboard/index.php" || fail 'ANATEL simulator view wiring missing'
grep -Fq 'suporte /suporte;' "$ROOT/modules/70-nginx.sh" || fail 'Support Nginx redirect mapping missing'
grep -Fq 'simulado-anatel /simulado-anatel/;' "$ROOT/modules/70-nginx.sh" || fail 'ANATEL simulator Nginx mapping missing'
grep -Fq 'location = /simulado-anatel/' "$ROOT/modules/70-nginx.sh" || fail 'ANATEL simulator canonical route missing'
grep -Fq 'suporte simulado-anatel refletores' "$ROOT/dashboard/install/fresh-install-parity.sh" || fail 'Support/simulator runtime parity probe missing'
php -l "$ROOT/dashboard/index.php" >/dev/null
php -l "$ROOT/dashboard/support-native.php" >/dev/null
php -l "$ROOT/dashboard/simulado-anatel-view.php" >/dev/null
php -l "$ROOT/dashboard/simulado-anatel/index.php" >/dev/null
bash -n "$ROOT/modules/70-nginx.sh"
bash -n "$ROOT/dashboard/install/fresh-install-parity.sh"
ok 'Support and ANATEL simulator source/route parity is guarded'
