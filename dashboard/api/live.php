<?php
declare(strict_types=1);

$config = require dirname(__DIR__) . '/config.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');

$logFile = (string)($config['log_path'] ?? '/var/log/xlx.log');
$privateStatusCache = '/var/cache/xlx-dashboard/status-private.json';

if (!is_readable($logFile)) {http_response_code(503);echo json_encode(['ok'=>false,'error'=>'log_unavailable']);exit;}

$connections = [];
if (is_readable($privateStatusCache)) {
    $cached=json_decode((string)file_get_contents($privateStatusCache),true);
    if(is_array($cached)&&isset($cached['connections'])&&is_array($cached['connections']))$connections=$cached['connections'];
}

function live_timestamp(string $line): int {
    if (preg_match('/^(\d{1,2})\s+([A-Za-z]{3}),\s+(\d{2}):(\d{2}):(\d{2}):/', $line, $m)) {
        $months=['Jan'=>1,'Feb'=>2,'Mar'=>3,'Apr'=>4,'May'=>5,'Jun'=>6,'Jul'=>7,'Aug'=>8,'Sep'=>9,'Oct'=>10,'Nov'=>11,'Dec'=>12];
        $month=$months[$m[2]]??0;
        if($month){$year=(int)date('Y');$ts=mktime((int)$m[3],(int)$m[4],(int)$m[5],$month,(int)$m[1],$year);if($ts>time()+86400)$ts=mktime((int)$m[3],(int)$m[4],(int)$m[5],$month,(int)$m[1],$year-1);return $ts;}
    }
    return time();
}
function live_country(string $call): array {
    $c=strtoupper(trim($call));$p=substr($c,0,2);
    if(in_array($p,['PP','PQ','PR','PS','PT','PU','PV','PW','PX','PY','ZV','ZW','ZX','ZY','ZZ'],true))return ['code'=>'BR','name'=>'Brasil','flag'=>'🇧🇷'];
    if(str_starts_with($c,'K')||str_starts_with($c,'N')||str_starts_with($c,'W')||preg_match('/^A[A-L]/',$c))return ['code'=>'US','name'=>'Estados Unidos','flag'=>'🇺🇸'];
    if(str_starts_with($c,'VE')||str_starts_with($c,'VA'))return ['code'=>'CA','name'=>'Canadá','flag'=>'🇨🇦'];
    if(str_starts_with($c,'LU'))return ['code'=>'AR','name'=>'Argentina','flag'=>'🇦🇷'];
    if(str_starts_with($c,'CX'))return ['code'=>'UY','name'=>'Uruguai','flag'=>'🇺🇾'];
    if(str_starts_with($c,'CE'))return ['code'=>'CL','name'=>'Chile','flag'=>'🇨🇱'];
    if(str_starts_with($c,'CT'))return ['code'=>'PT','name'=>'Portugal','flag'=>'🇵🇹'];
    if(str_starts_with($c,'EA'))return ['code'=>'ES','name'=>'Espanha','flag'=>'🇪🇸'];
    if(preg_match('/^(G|M|2E)/',$c))return ['code'=>'GB','name'=>'Reino Unido','flag'=>'🇬🇧'];
    if(str_starts_with($c,'F'))return ['code'=>'FR','name'=>'França','flag'=>'🇫🇷'];
    if(str_starts_with($c,'DL'))return ['code'=>'DE','name'=>'Alemanha','flag'=>'🇩🇪'];
    if(str_starts_with($c,'I'))return ['code'=>'IT','name'=>'Itália','flag'=>'🇮🇹'];
    if(str_starts_with($c,'JA'))return ['code'=>'JP','name'=>'Japão','flag'=>'🇯🇵'];
    return ['code'=>'','name'=>'País não identificado','flag'=>'🌐'];
}
function live_match(array $connections,string $call,string $suffix,string $module,int $ts): ?array {
    $best=null;$score=-PHP_INT_MAX;
    foreach($connections as $c){$s=0;if(($c['callsign']??'')===$call)$s+=100;else continue;if(($c['module']??'')===$module)$s+=70;else $s-=70;if($suffix!==''&&($c['suffix']??'')===$suffix)$s+=20;$age=abs($ts-(int)($c['last_activity']??0));if($age<=10)$s+=30;elseif($age<=120)$s+=10;if($s>$score){$score=$s;$best=$c;}}
    return $score>=80?$best:null;
}
function live_gateway(?array $connection,string $callsign): string {
    foreach(['via','peer'] as $field){$value=trim((string)($connection[$field]??''));if($value!==''&&$value!=='-'&&filter_var($value,FILTER_VALIDATE_IP)===false)return mb_substr($value,0,80,'UTF-8');}
    return $callsign;
}

$handle=fopen($logFile,'rb');if($handle===false){http_response_code(503);echo json_encode(['ok'=>false,'error'=>'log_open_failed']);exit;}
$size=filesize($logFile)?:0;$read=min($size,131072);$start=max(0,$size-$read);if($start>0){fseek($handle,$start);fgets($handle);} $raw=stream_get_contents($handle)?:'';fclose($handle);
$active=[];$recent=[];
foreach(preg_split('/\R/',$raw)?:[] as $line){
    if(preg_match('/New client\s+([A-Z0-9]+)(?:\s+([A-Z0-9]+))?.*?protocol\s+([A-Za-z0-9+_-]+)(?:.*?module\s+([A-Z]))?/i',$line,$m)){$call=strtoupper(trim($m[1]));$suffix=strtoupper(trim($m[2]??''));$module=strtoupper(trim($m[4]??'?'));$recent[$call.'|'.$suffix.'|'.$module]=strtoupper(trim($m[3]));$recent[$call.'||'.$module]=strtoupper(trim($m[3]));}
    if(preg_match('/Opening stream on module\s+([A-Z])\s+for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?\s+with sid\s+(\d+)/i',$line,$m)){
        $module=strtoupper($m[1]);$call=strtoupper(trim($m[2]));$suffix=strtoupper(trim($m[3]??''));$sid=(int)$m[4];$ts=live_timestamp($line);$c=live_match($connections,$call,$suffix,$module,$ts);
        $protocol=(string)($c['protocol']??($recent[$call.'|'.$suffix.'|'.$module]??$recent[$call.'||'.$module]??($config['modules'][$module]['protocol']??'Não identificado')));
        $active[$module]=['key'=>$module.':'.$sid,'module'=>$module,'stream_id'=>$sid,'callsign'=>$call,'suffix'=>$suffix,'name'=>(string)($c['name']??$call),'location'=>(string)($c['location']??'Não informada'),'country'=>(array)($c['country']??live_country($call)),'protocol'=>$protocol,'started_at'=>$ts,'qrz'=>'https://www.qrz.com/db/'.rawurlencode($call),'gateway'=>live_gateway($c,$call),'state'=>'transmitting'];
    }
    if(preg_match('/Closing stream of module\s+([A-Z])/i',$line,$m))unset($active[strtoupper($m[1])]);
}
foreach($active as $m=>$tx){if(time()-(int)$tx['started_at']>600)unset($active[$m]);}
echo json_encode(['ok'=>true,'generated_at'=>time(),'active_count'=>count($active),'active'=>$active],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
