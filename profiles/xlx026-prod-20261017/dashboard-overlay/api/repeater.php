<?php
declare(strict_types=1);
require __DIR__.'/common.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

$call=norm_call((string)($_GET['callsign']??''));
if($call==='' || !preg_match('/^[A-Z0-9]{3,10}$/',$call)){
    json_out(['ok'=>false,'error'=>'invalid_callsign'],400);
}

$cacheDir='/var/cache/xlx026-dashboard/radioid-repeaters';
$cacheKey=preg_replace('/[^A-Z0-9]/','',$call);
$cacheFile=$cacheDir.'/'.$cacheKey.'.json';
$missFile=$cacheDir.'/'.$cacheKey.'.miss';
$lockFile=$cacheDir.'/'.$cacheKey.'.lock';
$ttl=86400;
$negativeTtl=21600;
$now=time();

$readCache=static function(string $file): ?array {
    if(!is_readable($file)) return null;
    $raw=@file_get_contents($file);
    $j=is_string($raw)?json_decode($raw,true):null;
    return is_array($j)?$j:null;
};

$cached=$readCache($cacheFile);
if($cached!==null && ($now-(int)($cached['fetched_at']??0))<$ttl){
    $cached['cache']='fresh';
    json_out(['ok'=>true,'repeater'=>$cached]);
}

/*
 * Cache negativo: indicativos inexistentes no RadioID deixam de gerar
 * uma chamada externa por navegador. A validade curta permite que um
 * cadastro novo apareça no mesmo dia.
 */
if(is_file($missFile) && ($now-(int)@filemtime($missFile))<$negativeTtl){
    json_out(['ok'=>false,'error'=>'not_found','cache'=>'negative'],404);
}

/*
 * Colapsa consultas simultâneas do mesmo indicativo. Sem isto, vários
 * navegadores podem consultar o RadioID ao mesmo tempo no primeiro acesso.
 */
$lock=@fopen($lockFile,'c');
if($lock!==false){
    @flock($lock,LOCK_EX);

    $cached=$readCache($cacheFile);
    if($cached!==null && ($now-(int)($cached['fetched_at']??0))<$ttl){
        $cached['cache']='fresh';
        @flock($lock,LOCK_UN);
        @fclose($lock);
        json_out(['ok'=>true,'repeater'=>$cached]);
    }

    if(is_file($missFile) && ($now-(int)@filemtime($missFile))<$negativeTtl){
        @flock($lock,LOCK_UN);
        @fclose($lock);
        json_out(['ok'=>false,'error'=>'not_found','cache'=>'negative'],404);
    }
}

$url='https://radioid.net/api/dmr/repeater/?'.http_build_query([
    'callsign'=>$call,
    'callsign_sel'=>'=',
    'per_page'=>10,
]);
$ctx=stream_context_create([
    'http'=>[
        'method'=>'GET',
        'timeout'=>2.0,
        'ignore_errors'=>true,
        'header'=>"User-Agent: XLX026-Repeater-Enrichment/1.0 contact=PU2PNY\r\nAccept: application/json\r\n",
    ],
    'ssl'=>['verify_peer'=>true,'verify_peer_name'=>true],
]);
$raw=@file_get_contents($url,false,$ctx);
$data=is_string($raw)?json_decode($raw,true):null;
$rows=is_array($data)&&is_array($data['results']??null)?$data['results']:[];
$best=null;
foreach($rows as $row){
    if(norm_call((string)($row['callsign']??''))===$call){$best=$row;break;}
}

if(!is_array($best)){
    if($cached!==null){
        $cached['cache']='stale';
        if(is_resource($lock)){
            @flock($lock,LOCK_UN);
            @fclose($lock);
        }
        json_out(['ok'=>true,'repeater'=>$cached]);
    }

    @file_put_contents($missFile,(string)$now,LOCK_EX);
    @chmod($missFile,0640);
    if(is_resource($lock)){
        @flock($lock,LOCK_UN);
        @fclose($lock);
    }
    json_out(['ok'=>false,'error'=>'not_found','cache'=>'negative-new'],404);
}

$rep=[
    'callsign'=>$call,
    'frequency'=>trim((string)($best['frequency']??'')),
    'offset'=>trim((string)($best['offset']??'')),
    'city'=>trim((string)($best['city']??'')),
    'state'=>trim((string)($best['state']??'')),
    'country'=>trim((string)($best['country']??'')),
    'color_code'=>isset($best['color_code'])?(string)$best['color_code']:'',
    'status'=>trim((string)($best['status']??'')),
    'network'=>trim((string)($best['ipsc_network']??'')),
    'coverage'=>trim((string)($best['coverage']??'')),
    'trustee'=>is_array($best['trustee']??null)?array_values(array_map('strval',$best['trustee'])):[],
    'talkgroups'=>is_array($best['talkgroups']??null)?$best['talkgroups']:[],
    'source'=>'RadioID.net',
    'source_url'=>'https://radioid.net/',
    'fetched_at'=>$now,
    'cache'=>'fresh',
];
$tmp=$cacheFile.'.'.getmypid().'.tmp';
if(@file_put_contents($tmp,json_encode($rep,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES),LOCK_EX)!==false){
    @chmod($tmp,0640);
    @rename($tmp,$cacheFile);
}
@unlink($missFile);
if(is_resource($lock)){
    @flock($lock,LOCK_UN);
    @fclose($lock);
}
json_out(['ok'=>true,'repeater'=>$rep]);
