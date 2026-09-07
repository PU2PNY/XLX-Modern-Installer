<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$logFile='/var/log/xlx.log';
$statusCache='/var/cache/xlx-dashboard/status.json';

if(!is_readable($logFile)){
    http_response_code(503);
    echo json_encode(['ok'=>false,'error'=>'log_unavailable']);
    exit;
}

/* Fast route: only the status cache and the last 128 KiB of the XLXD log. */
$statusSnapshot=[];
$connections=[];
if(is_readable($statusCache)){
    $cached=json_decode((string)file_get_contents($statusCache),true);
    if(is_array($cached)){
        $statusSnapshot=$cached;
        if(isset($cached['connections']) && is_array($cached['connections'])) $connections=$cached['connections'];
    }
}

$handle=fopen($logFile,'rb');
if($handle===false){
    http_response_code(503);
    echo json_encode(['ok'=>false,'error'=>'log_open_failed']);
    exit;
}
$size=filesize($logFile); if($size===false) $size=0;
$readSize=min($size,131072);
$start=max(0,$size-$readSize);
if($start>0){ fseek($handle,$start); fgets($handle); }
$raw=stream_get_contents($handle); fclose($handle);
if($raw===false) $raw='';

$baseCall=static function($value): string {
    $value=strtoupper(trim((string)$value));
    if($value==='') return '';
    return trim((string)((preg_split('/\s+/',$value)?:[])[0]??''));
};
$parseTime=static function(string $line): int {
    if(preg_match('/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})([+\-]\d{4})?/',$line,$m)){
        $t=strtotime($m[1].($m[2]??'')); if($t!==false) return $t;
    }
    if(preg_match('/^(\d{1,2})\s+([A-Za-z]{3}),\s+(\d{2}):(\d{2}):(\d{2}):/',$line,$m)){
        $months=['Jan'=>1,'Feb'=>2,'Mar'=>3,'Apr'=>4,'May'=>5,'Jun'=>6,'Jul'=>7,'Aug'=>8,'Sep'=>9,'Oct'=>10,'Nov'=>11,'Dec'=>12];
        $month=$months[$m[2]]??0;
        if($month>0) return mktime((int)$m[3],(int)$m[4],(int)$m[5],$month,(int)$m[1],(int)date('Y'));
    }
    return time();
};

$active=[];
$recentProtocols=[];
foreach(preg_split('/\R/',$raw)?:[] as $line){
    if(preg_match('/New client\s+([A-Z0-9]+)(?:\s+([A-Z0-9]+))?.*?protocol\s+([A-Za-z0-9+_-]+)(?:.*?module\s+([A-Z]))?/i',$line,$m)){
        $call=strtoupper(trim($m[1]));
        $suffix=strtoupper(trim($m[2]??''));
        $module=strtoupper(trim($m[4]??'?'));
        $recentProtocols[$call.'|'.$suffix.'|'.$module]=strtoupper(trim($m[3]));
        $recentProtocols[$call.'||'.$module]=strtoupper(trim($m[3]));
    }

    if(preg_match('/Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s*\/\s*[A-Z0-9+_-]+)?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)/i',$line,$m)){
        $module=strtoupper($m[1]);
        $call=$baseCall($m[2]);
        $suffix=strtoupper(trim($m[3]??''));
        $streamId=(int)$m[4];
        $timestamp=$parseTime($line);

        /* Exact connection only: same callsign + module + compatible suffix. */
        $connection=null;
        foreach($connections as $candidate){
            if($baseCall($candidate['callsign']??'')!==$call) continue;
            if(strtoupper(trim((string)($candidate['module']??'')))!==$module) continue;
            $candidateSuffix=strtoupper(trim((string)($candidate['suffix']??'')));
            if($suffix!=='' && $candidateSuffix!=='' && $candidateSuffix!==$suffix) continue;
            $connection=$candidate;
            break;
        }

        $protocol=(string)($connection['protocol']??$recentProtocols[$call.'|'.$suffix.'|'.$module]??$recentProtocols[$call.'||'.$module]??'Não identificado');
        if($module==='C' && ($protocol==='' || strtoupper($protocol)==='NÃO IDENTIFICADO')) $protocol='C4FM/DMR';

        $name=trim((string)($connection['name']??'')); if($name==='') $name=$call;
        $location=trim((string)($connection['location']??'')); if($location==='') $location='Localização não informada';
        $country=$connection['country']??['name'=>'País não informado','flag'=>'🌐'];

        $active[$module]=[
            'key'=>$module.':'.$streamId,
            'module'=>$module,
            'stream_id'=>$streamId,
            'callsign'=>$call,
            'suffix'=>$suffix,
            'network_callsign'=>$call,
            'network_suffix'=>$suffix,
            'name'=>$name,
            'location'=>$location,
            'country'=>$country,
            'protocol'=>$protocol,
            'started_at'=>$timestamp,
            'qrz'=>$connection['qrz']??'https://www.qrz.com/db/'.rawurlencode($call),
            'gateway'=>$call,
            'via'=>$connection['via']??'',
            'peer'=>$connection['peer']??'',
            'ip'=>$connection['ip']??'',
            'origin_match'=>$connection!==null?'exata':'log-client',
            'state'=>'transmitting',
        ];
    }

    if(preg_match('/Closing stream of module\s+([A-Z])/i',$line,$m)) unset($active[strtoupper($m[1])]);
}

$now=time();
foreach($active as $module=>$transmission){
    if(empty($transmission['started_at']) || ($now-(int)$transmission['started_at'])>600){ unset($active[$module]); continue; }

    /*
     * Merge a STATION identity only when the cached status proves the same
     * transmission by module, network gateway, start time and stream id.
     */
    $cachedTransmission=$statusSnapshot['modules'][$module]['transmission']??null;
    if(!is_array($cachedTransmission)) continue;
    $source=trim((string)($cachedTransmission['identity_source']??''));
    if($source==='' || !str_starts_with($source,'xlxd-station')) continue;

    $cacheModule=strtoupper(trim((string)($cachedTransmission['module']??$module)));
    if($cacheModule!==$module) continue;

    $cacheGateway=$baseCall($cachedTransmission['gateway']??'');
    $cacheNetwork=$baseCall($cachedTransmission['network_callsign']??'');
    if($call='' /* harmless local reset; value below comes from transmission */){}
    $liveNetwork=$baseCall($transmission['network_callsign']??$transmission['callsign']??'');
    if($liveNetwork==='' || ($liveNetwork!==$cacheGateway && $liveNetwork!==$cacheNetwork)) continue;

    $liveStart=(int)($transmission['started_at']??0);
    $cacheStart=(int)($cachedTransmission['started_at']??0);
    if($liveStart<=0 || $cacheStart<=0 || abs($liveStart-$cacheStart)>3) continue;

    $liveStream=(int)($transmission['stream_id']??0);
    $cacheStream=(int)($cachedTransmission['stream_id']??0);
    if($liveStream>0 && $cacheStream>0 && $liveStream!==$cacheStream) continue;

    foreach(['callsign','suffix','name','location','country','protocol','qrz','gateway','gateway_suffix','network_callsign','network_suffix','operator_callsign','operator_identity','identity_source','origin_match'] as $field){
        if(array_key_exists($field,$cachedTransmission)) $active[$module][$field]=$cachedTransmission[$field];
    }
    $active[$module]['gateway']=$baseCall($active[$module]['gateway']??'')?:$liveNetwork;
    $active[$module]['identity_match']='station-stream-time-gateway';
}

echo json_encode([
    'ok'=>true,
    'generated_at'=>$now,
    'active_count'=>count($active),
    'active'=>(object)$active,
],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
