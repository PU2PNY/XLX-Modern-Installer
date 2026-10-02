#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/dashboard/api/common.php"
STATUS="$ROOT/dashboard/api/status.php"

fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

php -l "$COMMON" >/dev/null
php -l "$STATUS" >/dev/null

XLX_TEST_COMMON="$COMMON" php <<'PHP'
<?php
require getenv('XLX_TEST_COMMON');

$rows = [
    ['callsign'=>'PU2AAA','suffix'=>'B','protocol'=>'DMR','module'=>'C','connected_at'=>100,'last_activity'=>110,'ip'=>'10.0.0.1'],
    ['callsign'=>'PU2AAA','suffix'=>'B','protocol'=>'DMR','module'=>'C','connected_at'=>120,'last_activity'=>200,'ip'=>'10.0.0.2'],
    ['callsign'=>'PU2AAA','suffix'=>'B','protocol'=>'C4FM/YSF','module'=>'C','connected_at'=>130,'last_activity'=>130,'ip'=>'10.0.0.3'],
    ['callsign'=>'PU2AAA','suffix'=>'B','protocol'=>'DMR','module'=>'D','connected_at'=>140,'last_activity'=>140,'ip'=>'10.0.0.4'],
    ['callsign'=>'PU2AAA','suffix'=>'G','protocol'=>'DMR','module'=>'C','connected_at'=>150,'last_activity'=>150,'ip'=>'10.0.0.5'],
    ['callsign'=>'PU2OLD','directory_callsign'=>'PU2NEW','suffix'=>'B','protocol'=>'DMR','module'=>'C','connected_at'=>160,'last_activity'=>160,'ip'=>'10.0.0.6'],
    ['callsign'=>'PU2NEW','directory_callsign'=>'PU2NEW','suffix'=>'B','protocol'=>'DMR','module'=>'C','connected_at'=>170,'last_activity'=>170,'ip'=>'10.0.0.7'],
];

$out = canonical_connections($rows);

if (count($out) !== 5) {
    fwrite(STDERR, "expected 5 canonical rows, got ".count($out)."\n");
    exit(1);
}

$selected = null;
foreach ($out as $row) {
    if (
        $row['callsign'] === 'PU2AAA'
        && $row['suffix'] === 'B'
        && $row['protocol'] === 'DMR'
        && $row['module'] === 'C'
    ) {
        $selected = $row;
        break;
    }
}

if ($selected === null) {
    fwrite(STDERR, "canonical DMR/C row missing\n");
    exit(1);
}

if ((int)$selected['last_activity'] !== 200 || (int)$selected['connected_at'] !== 120) {
    fwrite(STDERR, "canonical row did not keep most recently active session\n");
    exit(1);
}

$aliasRows = array_values(array_filter(
    $out,
    static fn(array $row): bool =>
        ($row['directory_callsign'] ?? '') === 'PU2NEW'
        && ($row['protocol'] ?? '') === 'DMR'
        && ($row['module'] ?? '') === 'C'
));
if (count($aliasRows) !== 1 || ($aliasRows[0]['callsign'] ?? '') !== 'PU2NEW') {
    fwrite(STDERR, "resolved callsign alias did not collapse to one canonical station\n");
    exit(1);
}

$selfRows = [
    ['callsign'=>'PU2SYS','suffix'=>'G','protocol'=>'D-STAR/DExtra','module'=>'A','connected_at'=>10,'last_activity'=>10,'via'=>'','peer'=>'','ip'=>'203.0.113.10'],
    ['callsign'=>'PU2SYS','suffix'=>'H','protocol'=>'D-STAR/DExtra','module'=>'B','connected_at'=>11,'last_activity'=>11,'via'=>'','peer'=>'','ip'=>'203.0.113.10'],
    ['callsign'=>'PU2SYS','suffix'=>'I','protocol'=>'D-STAR/DExtra','module'=>'C','connected_at'=>12,'last_activity'=>12,'via'=>'','peer'=>'','ip'=>'203.0.113.10'],
    ['callsign'=>'PU2SYS','suffix'=>'J','protocol'=>'D-STAR/DExtra','module'=>'D','connected_at'=>13,'last_activity'=>13,'via'=>'','peer'=>'','ip'=>'203.0.113.10'],
    ['callsign'=>'PU2SYS','suffix'=>'K','protocol'=>'D-STAR/DExtra','module'=>'E','connected_at'=>14,'last_activity'=>14,'via'=>'','peer'=>'','ip'=>'203.0.113.10'],
    ['callsign'=>'PU2SYS','suffix'=>'B','protocol'=>'C4FM/YSF','module'=>'C','connected_at'=>20,'last_activity'=>30,'via'=>'','peer'=>'','ip'=>'198.51.100.20'],
    ['callsign'=>'PU2REMOTE','suffix'=>'B','protocol'=>'D-STAR/DExtra','module'=>'D','connected_at'=>21,'last_activity'=>31,'via'=>'','peer'=>'','ip'=>'198.51.100.21'],
    ['callsign'=>'PU2LOCAL','suffix'=>'B','protocol'=>'DMR','module'=>'C','connected_at'=>22,'last_activity'=>32,'via'=>'','peer'=>'','ip'=>'203.0.113.10'],
];

$public = public_connections($selfRows, ['203.0.113.10']);

if (count($public) !== 3) {
    fwrite(STDERR, "expected 3 public rows after self-node filtering, got ".count($public)."\n");
    exit(1);
}

foreach ($public as $row) {
    if (
        ($row['protocol'] ?? '') === 'D-STAR/DExtra'
        && ($row['ip'] ?? '') === '203.0.113.10'
    ) {
        fwrite(STDERR, "synthetic XLXD self DExtra node remained public\n");
        exit(1);
    }
}
PHP
ok 'duplicate sessions, aliases and synthetic XLXD self DExtra nodes are filtered safely'

grep -Fq '$rawConnections = array_map(' "$STATUS" || fail 'raw connection list missing'
grep -Fq 'xlxd_self_addresses()' "$STATUS" || fail 'XLXD self-address source is not wired into status.php'
grep -Fq '$connections = public_connections(' "$STATUS" || fail 'public connection filtering missing'
grep -Fq '$rawConnections,' "$STATUS" || fail 'TX/history no longer receives raw connections'
ok 'status keeps raw endpoints for TX correlation while exposing canonical connected rows'
