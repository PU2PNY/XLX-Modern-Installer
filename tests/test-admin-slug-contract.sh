#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }
ok(){ printf 'OK | %s\n' "$*"; }

module_reserved="$(sed -n "s/^reserved='\(.*\)'$/\1/p" "$ROOT/modules/69-admin-page.sh")"
vendor_reserved="$(sed -n "s/^[[:space:]]*local reserved_admin_slug='\(.*\)'$/\1/p" "$ROOT/vendor/pp5pk-installer/installer.sh")"
[[ -n "$module_reserved" ]] || fail 'module reserved slug contract missing'
[[ -n "$vendor_reserved" ]] || fail 'questionnaire reserved slug contract missing'
[[ "$module_reserved" == "$vendor_reserved" ]] || fail 'questionnaire and Admin module reserved slug contracts differ'

valid(){
  local value="$1"
  [[ "$value" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || return 1
  [[ ! "$value" =~ $module_reserved ]]
}

valid controle || fail 'controle must be accepted as a private Admin route'
valid admin || fail 'admin must remain accepted'
for value in ao-vivo conectados ranking refletores assets api config flags install certificado digital-lab aprs aprs-dprs; do
  if valid "$value"; then fail "reserved public route accepted: $value"; fi
done
if valid a; then fail 'one-character slug accepted'; fi
if valid '../admin'; then fail 'unsafe slug accepted'; fi
ok 'Admin slug questionnaire and installation contract are synchronized'
