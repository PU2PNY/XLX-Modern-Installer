<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

$f='/var/lib/xlx026-ranking/ranking.json';

if(!is_readable($f)){
 http_response_code(503);
 echo json_encode(['ok'=>false,'error'=>'ranking_unavailable']);
 exit;
}

$j=json_decode((string)file_get_contents($f),true);

if(!is_array($j) || empty($j['ok'])){
 http_response_code(503);
 echo json_encode(['ok'=>false,'error'=>'ranking_invalid']);
 exit;
}

$j['age_seconds']=max(0,time()-(int)($j['generated_at']??0));
echo json_encode($j,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
