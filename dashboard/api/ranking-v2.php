<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

require_once __DIR__.'/common.php';

$f='/var/lib/xlx-ranking/ranking.json';

if(is_readable($f)){
    $j=json_decode((string)file_get_contents($f),true);
    if(is_array($j) && !empty($j['ok'])){
        $j['age_seconds']=max(0,time()-(int)($j['generated_at']??0));
        echo json_encode($j,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
        exit;
    }
}

function rank_rows(array $map,int $limit=10): array {
    arsort($map,SORT_NUMERIC);
    $out=[];
    foreach(array_slice($map,0,$limit,true) as $label=>$value){
        $out[]=['label'=>(string)$label,'value'=>(int)$value];
    }
    return $out;
}

function rank_period(array $history,int $from): array {
    $tx=[];
    $air=[];
    $hours=[];
    $modules=[];
    $calls=[];
    $count=0;
    $airtime=0;

    foreach($history as $row){
        $started=(int)($row['started_at']??0);
        if($started<$from) continue;

        $call=trim((string)($row['callsign']??''));
        if($call==='') $call='N/A';
        $duration=max(0,(int)($row['duration']??0));
        $module=trim((string)($row['module']??''));
        if($module==='') $module='?';
        $hour=date('H:00',$started?:time());

        $count++;
        $airtime+=$duration;
        $calls[$call]=true;
        $tx[$call]=($tx[$call]??0)+1;
        $air[$call]=($air[$call]??0)+$duration;
        $hours[$hour]=($hours[$hour]??0)+1;
        $modules[$module]=($modules[$module]??0)+1;
    }

    return [
        'tx_count'=>$count,
        'airtime_seconds'=>$airtime,
        'unique_callsigns'=>count($calls),
        'top_tx'=>rank_rows($tx),
        'top_airtime'=>rank_rows($air),
        'hours'=>rank_rows($hours,24),
        'modules'=>rank_rows($modules,26),
    ];
}

$connections=parse_xml_connections();
$data=active_and_history($connections,500);
$history=$data['history']??[];
$now=time();
$today=strtotime('today',$now)?:($now-86400);
$week=$now-(7*86400);
$month=strtotime(date('Y-m-01 00:00:00',$now))?:($now-(31*86400));
$oldest=null;
foreach($history as $row){
    $ts=(int)($row['started_at']??0);
    if($ts>0 && ($oldest===null || $ts<$oldest)) $oldest=$ts;
}

$out=[
    'ok'=>true,
    'source'=>'log_fallback',
    'generated_at'=>$now,
    'age_seconds'=>0,
    'coverage'=>[
        'today_complete'=>$oldest!==null && $oldest<=$today,
        'week_complete'=>$oldest!==null && $oldest<=$week,
        'month_complete'=>$oldest!==null && $oldest<=$month,
    ],
    'periods'=>[
        'today'=>rank_period($history,$today),
        'week'=>rank_period($history,$week),
        'month'=>rank_period($history,$month),
    ],
];

echo json_encode($out,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
