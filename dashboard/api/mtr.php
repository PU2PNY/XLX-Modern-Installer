<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');

const PUBLIC_STATUS = '/var/cache/xlx-dashboard/status.json';
const PRIVATE_STATUS = '/var/cache/xlx-dashboard/status-private.json';
const CACHE_DIR = '/var/cache/xlx-dashboard/mtr';
const CACHE_TTL = 9;
const MAX_PRIVATE_CACHE_AGE = 20;
const MAX_WIDGETS = 3;

function respond(array $data, int $status = 200): never {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function readJsonFile(string $file): ?array {
    if (!is_readable($file)) return null;
    $decoded = json_decode((string)file_get_contents($file), true);
    return is_array($decoded) ? $decoded : null;
}

function runCommand(array $command): array {
    $process = proc_open($command,[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes,null,['LANG'=>'C','LC_ALL'=>'C']);
    if (!is_resource($process)) return ['exit_code'=>127,'stdout'=>'','stderr'=>'process_unavailable'];
    fclose($pipes[0]);
    $stdout=(string)stream_get_contents($pipes[1]);$stderr=(string)stream_get_contents($pipes[2]);
    fclose($pipes[1]);fclose($pipes[2]);
    return ['exit_code'=>proc_close($process),'stdout'=>$stdout,'stderr'=>$stderr];
}

function sameIp(string $first,string $second): bool {
    $a=@inet_pton($first);$b=@inet_pton($second);
    return $a!==false&&$b!==false&&$a===$b;
}

function publicIp(string $ip): ?string {
    $flags=FILTER_FLAG_NO_PRIV_RANGE|FILTER_FLAG_NO_RES_RANGE;
    return filter_var($ip,FILTER_VALIDATE_IP,$flags)!==false?$ip:null;
}

function measureTarget(string $ip): array {
    $result=runCommand(['/usr/bin/timeout','-k','2s','10s','/usr/bin/mtr','-r','-C','-c','3','-i','1','-n',$ip]);
    $lines=preg_split('/\R/',trim($result['stdout']))?:[];$targetRow=null;$lastRespondingRow=null;
    foreach($lines as $index=>$line){
        if($index===0||trim($line)==='')continue;
        $row=str_getcsv($line);if(count($row)<14)continue;
        $rowIp=trim((string)($row[5]??''));
        if($rowIp===''||$rowIp==='???'||filter_var($rowIp,FILTER_VALIDATE_IP)===false)continue;
        $sent=(int)($row[7]??0);$loss=(float)($row[6]??100);
        if($sent>0&&$loss<100)$lastRespondingRow=$row;
        if(sameIp($rowIp,$ip))$targetRow=$row;
    }
    $selected=null;$partial=false;
    if($targetRow!==null&&(int)($targetRow[7]??0)>0&&(float)($targetRow[6]??100)<100)$selected=$targetRow;
    if($selected===null&&$lastRespondingRow!==null){$selected=$lastRespondingRow;$partial=true;}
    if($selected===null)return ['found'=>false,'route_partial'=>false,'average'=>null,'loss'=>null,'jitter'=>null,'stderr'=>trim($result['stderr'])];
    $sent=(int)($selected[7]??0);$loss=round((float)($selected[6]??100),1);
    if($sent<=0||$loss>=100)return ['found'=>true,'route_partial'=>$partial,'average'=>null,'loss'=>$loss,'jitter'=>null,'stderr'=>trim($result['stderr'])];
    return ['found'=>true,'route_partial'=>$partial,'average'=>round((float)($selected[10]??0),1),'loss'=>$loss,'jitter'=>round((float)($selected[13]??0),1),'stderr'=>trim($result['stderr'])];
}

function safeGateway(array $connection,string $callsign,string $suffix): string {
    foreach(['via','peer'] as $field){$value=trim((string)($connection[$field]??''));if($value!==''&&$value!=='-')return mb_substr($value,0,80,'UTF-8');}
    return trim($callsign.($suffix!==''?' '.$suffix:''));
}

function selectConnection(array $connections,string $callsign,string $suffix,string $module,int $startedAt): ?array {
    $best=null;$bestScore=-PHP_INT_MAX;
    foreach($connections as $connection){
        $score=0;
        if(strtoupper(trim((string)($connection['callsign']??'')))===$callsign)$score+=120;else continue;
        $connectionModule=strtoupper(trim((string)($connection['module']??'')));
        if($connectionModule===$module)$score+=80;else $score-=100;
        $connectionSuffix=strtoupper(trim((string)($connection['suffix']??'')));
        if($suffix!==''&&$connectionSuffix===$suffix)$score+=25;elseif($suffix!==''&&$connectionSuffix!==''&&$connectionSuffix!==$suffix)$score-=30;
        $last=(int)($connection['last_activity']??0);
        if($last>0&&$startedAt>0){$distance=abs($startedAt-$last);if($distance<=10)$score+=40;elseif($distance<=60)$score+=25;elseif($distance<=300)$score+=10;else $score-=min(40,(int)floor($distance/300));}
        if($score>$bestScore){$bestScore=$score;$best=$connection;}
    }
    return $bestScore>=100?$best:null;
}

$callsign=strtoupper(trim((string)($_GET['callsign']??'')));
$suffix=strtoupper(trim((string)($_GET['suffix']??'')));
$module=strtoupper(trim((string)($_GET['module']??'')));
$key=trim((string)($_GET['key']??''));
if(!preg_match('/^[A-Z0-9]{3,10}$/',$callsign)||!preg_match('/^[A-E]$/',$module)||($suffix!==''&&!preg_match('/^[A-Z0-9]{1,4}$/',$suffix))||strlen($key)>80)respond(['ok'=>false,'error'=>'invalid_request'],400);

$public=readJsonFile(PUBLIC_STATUS);$private=readJsonFile(PRIVATE_STATUS);
$defaultGateway=trim($callsign.($suffix!==''?' '.$suffix:''));
if(!is_array($public)||empty($public['ok'])||!is_array($private)||empty($private['ok']))respond(['ok'=>true,'state'=>'waiting','gateway'=>$defaultGateway,'status'=>'unknown','status_label'=>'Aguardando estado','avg_ms'=>null,'loss_pct'=>null,'jitter_ms'=>null,'history'=>[]]);
if(time()-(int)($private['generated_at']??0)>MAX_PRIVATE_CACHE_AGE)respond(['ok'=>true,'state'=>'waiting','gateway'=>$defaultGateway,'status'=>'unknown','status_label'=>'Atualizando rota','avg_ms'=>null,'loss_pct'=>null,'jitter_ms'=>null,'history'=>[]]);
$transmission=$public['modules'][$module]['transmission']??null;
if(!is_array($transmission)||strtoupper(trim((string)($transmission['callsign']??'')))!==$callsign||($key!==''&&trim((string)($transmission['key']??''))!==$key))respond(['ok'=>false,'state'=>'inactive'],409);
$connection=selectConnection((array)($private['connections']??[]),$callsign,$suffix,$module,(int)($transmission['started_at']??0));
$gateway=safeGateway($connection??[],$callsign,$suffix);$ip=$connection!==null?publicIp(trim((string)($connection['ip']??''))):null;
if($ip===null)respond(['ok'=>true,'state'=>'waiting','gateway'=>$gateway,'status'=>'unknown','status_label'=>'Aguardando rota','avg_ms'=>null,'loss_pct'=>null,'jitter_ms'=>null,'history'=>[]]);

if(!is_dir(CACHE_DIR)&&!@mkdir(CACHE_DIR,0750,true)&&!is_dir(CACHE_DIR))respond(['ok'=>false,'error'=>'cache_unavailable'],503);
$hash=hash('sha256','route-partial-v5|'.$ip);$cacheFile=CACHE_DIR.'/'.$hash.'.json';$lockFile=CACHE_DIR.'/'.$hash.'.lock';
$cached=readJsonFile($cacheFile);$cacheAge=is_file($cacheFile)?time()-(int)filemtime($cacheFile):PHP_INT_MAX;
if(is_array($cached)&&$cacheAge<=CACHE_TTL){$cached['gateway']=$gateway;$cached['cached']=true;$cached['cache_age']=$cacheAge;respond($cached);}
$targetLock=fopen($lockFile,'c');if($targetLock===false)respond(['ok'=>false,'error'=>'lock_unavailable'],503);
if(!flock($targetLock,LOCK_EX|LOCK_NB)){fclose($targetLock);if(is_array($cached)){$cached['gateway']=$gateway;$cached['cached']=true;$cached['stale']=true;respond($cached);}respond(['ok'=>true,'state'=>'measuring','gateway'=>$gateway,'status'=>'unknown','status_label'=>'Medindo','avg_ms'=>null,'loss_pct'=>null,'jitter_ms'=>null,'history'=>[]]);}
$cached=readJsonFile($cacheFile);$cacheAge=is_file($cacheFile)?time()-(int)filemtime($cacheFile):PHP_INT_MAX;
if(is_array($cached)&&$cacheAge<=CACHE_TTL){flock($targetLock,LOCK_UN);fclose($targetLock);$cached['gateway']=$gateway;$cached['cached']=true;$cached['cache_age']=$cacheAge;respond($cached);}
$slotHandle=null;
for($slot=1;$slot<=MAX_WIDGETS;$slot++){$candidate=fopen(CACHE_DIR.'/slot_'.$slot.'.lock','c');if($candidate!==false&&flock($candidate,LOCK_EX|LOCK_NB)){$slotHandle=$candidate;break;}if($candidate!==false)fclose($candidate);}
if($slotHandle===null){flock($targetLock,LOCK_UN);fclose($targetLock);if(is_array($cached)){$cached['gateway']=$gateway;$cached['cached']=true;$cached['stale']=true;respond($cached);}respond(['ok'=>true,'state'=>'queued','gateway'=>$gateway,'status'=>'unknown','status_label'=>'Na fila','avg_ms'=>null,'loss_pct'=>null,'jitter_ms'=>null,'history'=>[]]);}
$measurement=measureTarget($ip);flock($slotHandle,LOCK_UN);fclose($slotHandle);
$average=$measurement['average'];$loss=$measurement['loss'];$jitter=$measurement['jitter'];$partial=!empty($measurement['route_partial']);$status='unknown';$statusLabel='Sem resposta';
if($partial&&$average!==null&&$loss!==null&&$jitter!==null){if($average<=150&&$loss<=5&&$jitter<=50){$status='warning';$statusLabel='Rota parcial';}else{$status='bad';$statusLabel='Rota parcial ruim';}}
elseif($measurement['found']&&$loss!==null&&$loss>=100){$status='bad';$statusLabel='Sem resposta';}
elseif($average!==null&&$loss!==null&&$jitter!==null){if($average<=80&&$loss<=1&&$jitter<=20){$status='good';$statusLabel='Estável';}elseif($average<=150&&$loss<=5&&$jitter<=50){$status='warning';$statusLabel='Variação';}else{$status='bad';$statusLabel='Ruim';}}
$history=is_array($cached['history']??null)?$cached['history']:[];$history[]=$average;$history=array_slice($history,-8);
$result=['ok'=>true,'state'=>'ready','gateway'=>$gateway,'status'=>$status,'status_label'=>$statusLabel,'route_partial'=>$partial,'avg_ms'=>$average,'loss_pct'=>$loss,'jitter_ms'=>$jitter,'history'=>$history,'updated_at'=>time(),'cycles'=>3,'cache_ttl'=>CACHE_TTL];
$encoded=json_encode($result,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
if($encoded!==false){$tmp=$cacheFile.'.tmp.'.getmypid();if(file_put_contents($tmp,$encoded,LOCK_EX)!==false){@chmod($tmp,0640);@rename($tmp,$cacheFile);}else{@unlink($tmp);}}
flock($targetLock,LOCK_UN);fclose($targetLock);
if(trim((string)($measurement['stderr']??''))!=='')error_log('XLX Modern Dashboard MTR: '.preg_replace('/\s+/',' ',trim((string)$measurement['stderr'])));
respond($result);
