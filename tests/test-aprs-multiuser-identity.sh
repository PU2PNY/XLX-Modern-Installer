#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
API="$ROOT/dashboard/api/digital-lab-operator.php"
JS="$ROOT/dashboard/assets/digital-lab-operator.js"
HTML="$ROOT/dashboard/digital-lab-native.php"

grep -F "ownOperatorMessages(" "$API" >/dev/null
grep -F "message_scope'] = 'own'" "$API" >/dev/null
grep -F "message_scope'] = 'global'" "$API" >/dev/null
grep -F "'error' => 'self_destination'" "$API" >/dev/null
grep -F "'service' => \$serviceCall" "$API" >/dev/null
grep -F "historyWrap.hidden=!canSend" "$JS" >/dev/null
grep -F "Minhas mensagens enviadas" "$JS" >/dev/null
grep -F "self_destination:'Próprio gateway — sem ACK'" "$JS" >/dev/null
grep -F "próprio indicativo do gateway" "$JS" >/dev/null
grep -F "dlabMessageHistoryScope" "$HTML" >/dev/null
grep -F "digital-lab-operator.js?v=1.2.10" "$HTML" >/dev/null

if grep -F "unset(\$operator['messages'])" "$API" >/dev/null; then
  echo "FAIL | non-admin messages are still removed instead of filtered"
  exit 1
fi

php -l "$API" >/dev/null
node --check "$JS"

echo "aprs_multiuser_identity=PASS"
