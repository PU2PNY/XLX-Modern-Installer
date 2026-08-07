<?php
declare(strict_types=1);
require __DIR__.'/common.php';

function safe_dashboard_url(mixed $value): string {
    $url=trim((string)$value);
    if($url==='')return '';
    $parts=parse_url($url);
    if(!is_array($parts))return '';
    $scheme=strtolower((string)($parts['scheme']??''));
    $host=trim((string)($parts['host']??''));
    return in_array($scheme,['http','https'],true)&&$host!==''?$url:'';
}

$list=array_map(static function(array $item): array {
    $item['dashboardurl']=safe_dashboard_url($item['dashboardurl']??'');
    return $item;
},fetch_reflectors());

json_out(['ok'=>true,'reflectors'=>$list,'count'=>count($list)]);
