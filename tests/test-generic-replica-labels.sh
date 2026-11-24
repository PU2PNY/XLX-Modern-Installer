#!/usr/bin/env bash
# TEST-060: generic layout CSS, display-only labels and XLX026 leak removal.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/dashboard"
fail(){ echo "FAIL | $*"; exit 1; }
ok(){ echo "OK | $*"; }

CSS="$D/assets/header-layout-v5.css"
[ -f "$CSS" ] || fail "header-layout-v5.css missing"
if grep -Eq 'xlx-wa-support-float|callsign-lookup|lookup-table|xlx026-' "$CSS"; then fail "XLX026-specific selector in generic CSS"; fi
ok "generic CSS has no XLX026-only selectors"
last="$(grep -o 'assets/[A-Za-z0-9._-]*\.css?v=[A-Za-z0-9._-]*' "$D/index.php" | tail -1)"
case "$last" in assets/header-layout-v5.css*) ok "header-layout-v5.css is loaded last";; *) fail "CSS not last: $last";; esac

if grep -Eq 'TG 6 \(voz\)|A=4001, B=4002|TG 4003' "$D/index.php" "$D/config.php" "$D/assets/app.js"; then fail "hardcoded XLX026 DMR TG text remains"; fi
ok "no hardcoded DMR TG text"
if grep -Eqi 'suporte|anatel|labre|XRF026|4003' "$D/safari9-test.html"; then fail "XLX026-only block in safari9-test.html"; fi
ok "safari9-test.html is generic"
if grep -Eq "'(suporte|noticias)'" "$D/i18n/build.php"; then fail "suporte/noticias still in routeSlugs"; fi
ok "i18n routeSlugs generic"
grep -q 'dlabIsBrazil' "$D/digital-lab-native.php" || fail "Anatel link not country-gated"
ok "Anatel link gated by country"

php -r '
function cfg(){ return ["protocol_labels"=>["DMR"=>"Voz Digital"]]; }
$src=file_get_contents($argv[1]);
preg_match("/function protocol_token.*?function protocol_label\(string[^\n]*\n/s",$src,$m); eval($m[0]);
$c=[protocol_key("DMRM")==="DMR", protocol_label("DMRM")==="Voz Digital", protocol_key("Voz Digital")==="DMR", protocol_key("YSF")==="C4FM/YSF", protocol_key("DEXTRA")==="D-STAR/DExtra"];
if(in_array(false,$c,true)){ fwrite(STDERR,"label/key mismatch\n"); exit(1);} ' "$D/api/common.php" || fail "protocol_key/protocol_label"
ok "protocol_key stays canonical while protocol_label is overridable"
grep -q "protocol_key(\$m\[3\])==='DMR'" "$D/api/common.php" || fail "module C DMR rule must use raw protocol key"
grep -q "protocol_key(\$m\[3\])==='DMR'" "$D/api/authorized-sync-v1.php" || fail "module C DMR rule (authorized-sync) must use raw protocol key"
ok "module C DMR rule uses canonical protocol key"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config"; cp "$D/config.php" "$tmp/config.php"
echo "<?php return ['radio'=>['module_count'=>7,'ysf_id'=>'12345','module_labels'=>['A'=>'Foto']]];" > "$tmp/config/site.php"
php -r '$c=require $argv[1]."/config.php"; if($c["module_labels"]["A"]!=="Foto"||$c["module_labels"]["B"]!=="DV B"||!isset($c["modules"]["B"])||$c["modules"]["C"]["access"]!=="YSF 12345 • DMR TG 4003"){exit(1);}' "$tmp" || fail "module label defaults / raw letter keys"
ok "module labels default to DV <letter>; letters remain keys"
