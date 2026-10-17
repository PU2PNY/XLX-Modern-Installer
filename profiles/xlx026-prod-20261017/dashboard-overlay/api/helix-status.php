<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
$path='/run/xlx-helix-monitor/public.json';
$default=['ok'=>true,'mode'=>'off','shadow_active'=>false,'process_active'=>false,'ai_connected'=>false,'anomaly'=>false,'updated_at'=>0];
if (!is_readable($path)) { echo json_encode($default); exit; }
clearstatcache(true,$path);
$size=@filesize($path);
if ($size===false || $size<2 || $size>8192) { echo json_encode($default); exit; }
$d=json_decode((string)@file_get_contents($path),true);
if (!is_array($d)) { echo json_encode($default); exit; }
$out=[
 'ok'=>true,
 'mode'=>in_array(($d['mode']??'off'),['shadow','process'],true)?(string)$d['mode']:'off',
 'shadow_active'=>!empty($d['shadow_active']),
 'process_active'=>!empty($d['process_active']),
 'helix_active'=>!empty($d['helix_active']),
 'socket_ready'=>!empty($d['socket_ready']),
 'xuvd_active'=>!empty($d['xuvd_active']),
 'xlxd_active'=>!empty($d['xlxd_active']),
 'candidate_ok'=>!empty($d['candidate_ok']),
 'recent_helix_ok'=>max(0,(int)($d['recent_helix_ok']??0)),
 'recent_fallback'=>max(0,(int)($d['recent_fallback']??0)),
 'recent_consecutive_max'=>max(0,(int)($d['recent_consecutive_max']??0)),
 'recent_stream_disabled'=>!empty($d['recent_stream_disabled']),
 'last_observed_at'=>max(0,(int)($d['last_observed_at']??0)),
 'ai_connected'=>!empty($d['ai_connected']),
 'ai_last_analysis_at'=>max(0,(int)($d['ai_last_analysis_at']??0)),
 'ai_last_ok'=>!empty($d['ai_last_ok']),
 'ai_summary'=>substr(trim((string)($d['ai_summary']??'')),0,240),
 'anomaly'=>!empty($d['anomaly']),
 'updated_at'=>max(0,(int)($d['updated_at']??0)),
];
echo json_encode($out,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);