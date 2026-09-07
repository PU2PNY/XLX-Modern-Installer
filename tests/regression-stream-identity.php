<?php
declare(strict_types=1);
function norm_call(string $v): string { $v=strtoupper(trim($v)); return trim((string)((preg_split('/\s+/',$v)?:[])[0]??'')); }
function mask_ip(string $ip): string { if(filter_var($ip,FILTER_VALIDATE_IP,FILTER_FLAG_IPV4)){ $p=explode('.',$ip); return $p[0].'.'.$p[1].'.x.x'; } return ''; }
require dirname(__DIR__).'/dashboard/api/identity-safe.php';
function expect_same($actual,$expected,string $label): void { if($actual!==$expected){ fwrite(STDERR,"FAIL: $label\n"); exit(1); } }
$other=[['callsign'=>'PU2PNY','suffix'=>'B','module'=>'C','protocol'=>'C4FM/YSF','last_activity'=>1000,'via'=>'','peer'=>'','ip'=>'10.0.0.1']];
$r=xlxmodern_exact_tx_origin($other,'PU2OJI','B','C');
expect_same($r['gateway'],'PU2OJI','another station in same module is never selected');
expect_same($r['origin_match'],'log-client','missing exact connection uses log client');
$exact=[['callsign'=>'PU2OJI','suffix'=>'B','module'=>'C','via'=>'PU2PNY','peer'=>'PY3KDA','ip'=>'192.0.2.10']];
$r=xlxmodern_exact_tx_origin($exact,'PU2OJI','B','C');
expect_same($r['gateway'],'PU2OJI','via/peer never replace gateway');
expect_same($r['via'],'PU2PNY','via remains metadata');
expect_same($r['peer'],'PY3KDA','peer remains metadata');
expect_same($r['origin_match'],'exata','exact connection is identified');
$wrongModule=[['callsign'=>'PU2OJI','suffix'=>'B','module'=>'D','via'=>'OTHER']];
expect_same(xlxmodern_exact_tx_origin($wrongModule,'PU2OJI','B','C')['origin_match'],'log-client','different module is rejected');
$wrongSuffix=[['callsign'=>'PY4RWC','suffix'=>'C','module'=>'C','via'=>'OTHER']];
$r=xlxmodern_exact_tx_origin($wrongSuffix,'PY4RWC','B','C');
expect_same($r['origin_match'],'log-client','different explicit suffix is rejected');
expect_same($r['gateway'],'PY4RWC','real network client remains gateway');
expect_same(xlxmodern_history_state(['online'=>true,'callsign'=>'PU2XYY','gateway'=>'PY2LSB','identity_source'=>'xlxd-station-stream']),'Online','Online has priority over Link');
expect_same(xlxmodern_history_state(['online'=>false,'callsign'=>'PY1RV','gateway'=>'PY1RO','identity_source'=>'xlxd-station-stream']),'Link','STATION-proven remote operator is Link');
expect_same(xlxmodern_history_state(['online'=>false,'callsign'=>'PU2KMV','gateway'=>'PU2KMV']),'Offline','direct inactive station is Offline');
expect_same(xlxmodern_history_state(['online'=>false,'callsign'=>'ABC123','gateway'=>'XYZ999','identity_source'=>'']),'Offline','different gateway without STATION is never Link');
$station=['callsign'=>'PS7JAP','gateway'=>'PY4RWC','gateway_suffix'=>'B','network_callsign'=>'PY4RWC','identity_source'=>'xlxd-station-stream'];
expect_same(xlxmodern_enforce_safe_origin($station,$other),$station,'STATION identity is preserved');
$source=(string)file_get_contents(dirname(__DIR__).'/dashboard/assets/ao-vivo-authorized-sync-v1.js');
foreach(['Nº','País','Status','Indicativo','Nome','Hotspot / Repetidora','Cidade','Protocolo','Módulo','Tempo de transmissão'] as $label){ if(strpos($source,$label)===false){ fwrite(STDERR,"FAIL: missing history column $label\n"); exit(1); } }
if(strpos($source,"source.indexOf('xlxd-station') === 0")===false){ fwrite(STDERR,"FAIL: Link must require STATION source\n"); exit(1); }
fwrite(STDOUT,"OK: stream identity regression suite passed\n");
