<?php
declare(strict_types=1);
require __DIR__.'/common.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=30, stale-while-revalidate=60');
$days=(int)($_GET['days']??7);
if(!in_array($days,[7,30],true)) json_out(['ok'=>false,'error'=>'invalid_days'],400);
$dbPath='/var/lib/xlx-modern-history/history.sqlite';
if(!is_readable($dbPath)) json_out(['ok'=>true,'days'=>$days,'generated_at'=>time(),'coverage_since'=>0,'groups'=>[]]);
$db=new SQLite3($dbPath,SQLITE3_OPEN_READONLY); $db->busyTimeout(2000);
$since=time()-($days*86400);
$connections=parse_xml_connections(); $online=online_index($connections);
$call=norm_call((string)($_GET['callsign']??''));
$decode=function(string $raw) use($online): ?array {
  $x=json_decode($raw,true); if(!is_array($x)) return null;
  $c=norm_call((string)($x['callsign']??'')); $x['online']=$c!==''&&!empty($online[$c]); return $x;
};
$coverage=(int)$db->querySingle('SELECT COALESCE(MIN(started_at),0) FROM history');
if($call!==''){
  $cntStmt=$db->prepare('SELECT COUNT(*) FROM history WHERE callsign=:c AND started_at>=:s');
  $cntStmt->bindValue(':c',$call,SQLITE3_TEXT); $cntStmt->bindValue(':s',$since,SQLITE3_INTEGER); $count=(int)$cntStmt->execute()->fetchArray(SQLITE3_NUM)[0];
  $st=$db->prepare('SELECT payload FROM history WHERE callsign=:c AND started_at>=:s ORDER BY started_at DESC LIMIT 1000');
  $st->bindValue(':c',$call,SQLITE3_TEXT); $st->bindValue(':s',$since,SQLITE3_INTEGER); $rs=$st->execute(); $items=[];
  while($row=$rs->fetchArray(SQLITE3_ASSOC)){ $x=$decode((string)$row['payload']); if($x!==null)$items[]=$x; }
  echo json_encode(['ok'=>true,'days'=>$days,'generated_at'=>time(),'coverage_since'=>$coverage,'callsign'=>$call,'count'=>$count,'truncated'=>$count>1000,'items'=>$items],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE); exit;
}
$sql='SELECT h.callsign,h.payload,g.tx_count,g.total_duration,g.last_started FROM history h JOIN (
 SELECT callsign,COUNT(*) tx_count,SUM(duration) total_duration,MAX(started_at) last_started
 FROM history WHERE started_at>=:s GROUP BY callsign
) g ON g.callsign=h.callsign AND g.last_started=h.started_at
WHERE h.rowid=(SELECT h2.rowid FROM history h2 WHERE h2.callsign=g.callsign AND h2.started_at=g.last_started ORDER BY h2.rowid DESC LIMIT 1)
ORDER BY g.last_started DESC LIMIT 2000';
$st=$db->prepare($sql); $st->bindValue(':s',$since,SQLITE3_INTEGER); $rs=$st->execute(); $groups=[];
while($row=$rs->fetchArray(SQLITE3_ASSOC)){
  $x=$decode((string)$row['payload']); if($x===null) continue;
  $x['tx_count']=(int)$row['tx_count']; $x['total_duration']=(int)$row['total_duration']; $x['started_at']=(int)$row['last_started']; $groups[]=$x;
}
echo json_encode(['ok'=>true,'days'=>$days,'generated_at'=>time(),'coverage_since'=>$coverage,'groups'=>$groups],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
