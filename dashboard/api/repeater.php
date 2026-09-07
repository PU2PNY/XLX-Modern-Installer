<?php
declare(strict_types=1);
require __DIR__.'/common.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

$call=norm_call((string)($_GET['callsign']??''));
if($call==='' || !preg_match('/^[A-Z0-9]{3,10}$/',$call)){
    json_out(['ok'=>false,'error'=>'invalid_callsign'],400);
}

$cacheDir='/var/cache/xlx-dashboard/radioid-repeaters';
$cacheFile=$cacheDir.'/'.preg_replace('/[^A-Z0-9]/','',$call).'.json';
$ttl=86400;
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

$url='https://radioid.net/api/dmr/repeater/?'.http_build_query([
    'callsign'=>$call,
    'callsign_sel'=>'=',
    'per_page'=>10,
]);
$ctx=stream_context_create([
    'http'=>[
        'method'=>'GET',
        'timeout'=>2.5,
        'ignore_errors'=>true,
        'header'=>"User-Agent: XLX-Modern-Repeater-Enrichment/1.0\r\nAccept: application/json\r\n",
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
        json_out(['ok'=>true,'repeater'=>$cached]);
    }
    json_out(['ok'=>false,'error'=>'not_found'],404);
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
json_out(['ok'=>true,'repeater'=>$rep]);
