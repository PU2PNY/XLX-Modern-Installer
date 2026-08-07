<?php

declare(strict_types=1);

require __DIR__ . '/common.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');

$cacheFile = '/var/cache/xlx-dashboard/status.json';
$lockFile  = '/var/cache/xlx-dashboard/status.lock';
$cacheTtl  = 1;

function send_cached_status(string $cacheFile,int $cacheTtl,bool $allowExpired=false): bool {
    if(!is_readable($cacheFile))return false;
    clearstatcache(true,$cacheFile);$mtime=filemtime($cacheFile);
    if(!$allowExpired&&($mtime===false||(time()-$mtime)>$cacheTtl))return false;
    $json=file_get_contents($cacheFile);if($json===false||$json==='')return false;
    $decoded=json_decode($json,true);if(!is_array($decoded)||empty($decoded['ok']))return false;
    header('X-XLX-Cache: '.($allowExpired?'stale-while-refresh':'fresh'));echo $json;return true;
}
if(send_cached_status($cacheFile,$cacheTtl))exit;
$lockHandle=fopen($lockFile,'c');
if($lockHandle===false){http_response_code(503);echo json_encode(['ok'=>false,'error'=>'status_lock_unavailable']);exit;}
try{
    if(!flock($lockHandle,LOCK_EX|LOCK_NB)){
        if(send_cached_status($cacheFile,$cacheTtl,true)){fclose($lockHandle);exit;}
        fclose($lockHandle);http_response_code(503);echo json_encode(['ok'=>false,'error'=>'status_refresh_in_progress']);exit;
    }
    if(send_cached_status($cacheFile,$cacheTtl)){flock($lockHandle,LOCK_UN);fclose($lockHandle);exit;}
    $connections=parse_xml_connections();$tx=active_and_history($connections);$online=online_index($connections);$modules=[];
    foreach(cfg()['modules'] as $letter=>$meta){
        $moduleConnections=array_values(array_filter($connections,static fn(array $connection):bool=>$connection['module']===$letter));
        $protocols=array_values(array_unique(array_filter(array_column($moduleConnections,'protocol'))));
        $lastTransmission=null;foreach($tx['history'] as $historyItem){if($historyItem['module']===$letter){$lastTransmission=$historyItem;break;}}
        $modules[$letter]=['module'=>$letter,'name'=>(string)($meta['name']??('Module '.$letter)),'configured_protocol'=>(string)($meta['protocol']??''),'access'=>(string)($meta['access']??''),'dmr_tg'=>(string)($meta['dmr_tg']??''),'ysf_dgid'=>(string)($meta['ysf_dgid']??''),'connected_count'=>count($moduleConnections),'protocols'=>$protocols,'transmission'=>$tx['active'][$letter]??null,'last_transmission'=>$lastTransmission];
    }
    $history=array_map(static function(array $historyItem)use($online):array{$historyItem['online']=!empty($online[$historyItem['callsign']]);return $historyItem;},$tx['history']);
    $reflectorCode=strtoupper((string)(cfg()['reflector_code']??''));
    $payload=['ok'=>true,'generated_at'=>time(),'server_name'=>(string)(cfg()['server_name']??'XLX'),'reflector_code'=>$reflectorCode,'dtmf_number'=>ctype_digit($reflectorCode)?(ltrim($reflectorCode,'0')?:'0'):'','locale'=>(string)(cfg()['locale']??'pt-BR'),'ysf_id'=>(string)(cfg()['ysf_id']??''),'dmr_tg'=>(string)(cfg()['dmr_tg']??''),'dmr_radio_tg'=>(string)(cfg()['dmr_radio_tg']??''),'active_count'=>count($tx['active']),'connected_count'=>count($connections),'modules'=>$modules,'history'=>$history,'connections'=>$connections,'sources'=>['xml'=>is_readable(cfg()['xml_path']),'log'=>is_readable(cfg()['log_path']),'db'=>is_readable(cfg()['users_db'])]];
    $json=json_encode($payload,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);if($json===false)throw new RuntimeException('Falha ao gerar JSON.');
    $temporaryFile=$cacheFile.'.'.getmypid().'.tmp';if(file_put_contents($temporaryFile,$json,LOCK_EX)===false)throw new RuntimeException('Falha ao gravar cache temporário.');if(!rename($temporaryFile,$cacheFile)){@unlink($temporaryFile);throw new RuntimeException('Falha ao publicar cache.');}
    echo $json;flock($lockHandle,LOCK_UN);fclose($lockHandle);
}catch(Throwable $exception){
    if(is_resource($lockHandle)){flock($lockHandle,LOCK_UN);fclose($lockHandle);}if(is_readable($cacheFile)){$fallback=file_get_contents($cacheFile);if($fallback!==false&&$fallback!==''){echo $fallback;exit;}}http_response_code(503);echo json_encode(['ok'=>false,'error'=>'status_temporarily_unavailable'],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
}
