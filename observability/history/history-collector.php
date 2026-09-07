<?php
declare(strict_types=1);
$dashboard=rtrim((string)(getenv('XLX_DASHBOARD_DIR')?:'/var/www/html/xlxd'),'/');
require $dashboard.'/api/common.php';
$dbDir='/var/lib/xlx-modern-history';
$dbPath=$dbDir.'/history.sqlite';
if(!is_dir($dbDir)) mkdir($dbDir,0750,true);
$db=new SQLite3($dbPath);
$db->busyTimeout(5000);
$db->exec('PRAGMA journal_mode=WAL');
$db->exec('PRAGMA synchronous=NORMAL');
$db->exec('CREATE TABLE IF NOT EXISTS history (
  event_key TEXT PRIMARY KEY,
  callsign TEXT NOT NULL,
  module TEXT NOT NULL,
  stream_id INTEGER NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NOT NULL,
  duration INTEGER NOT NULL,
  payload TEXT NOT NULL,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
)');
$db->exec('CREATE INDEX IF NOT EXISTS idx_history_started ON history(started_at DESC)');
$db->exec('CREATE INDEX IF NOT EXISTS idx_history_call_started ON history(callsign,started_at DESC)');
$connections=parse_xml_connections();
$tx=active_and_history($connections,5000,time()-86400);
$now=time();
$stmt=$db->prepare('INSERT INTO history(event_key,callsign,module,stream_id,started_at,ended_at,duration,payload,first_seen,last_seen)
VALUES(:k,:c,:m,:sid,:st,:en,:du,:pl,:fs,:ls)
ON CONFLICT(event_key) DO UPDATE SET callsign=excluded.callsign,module=excluded.module,duration=excluded.duration,payload=excluded.payload,last_seen=excluded.last_seen');
$db->exec('BEGIN IMMEDIATE');
$count=0;
foreach($tx['history'] as $h){
  $st=(int)($h['started_at']??0); $en=(int)($h['ended_at']??0); $sid=(int)($h['stream_id']??0);
  $mod=strtoupper(substr((string)($h['module']??''),0,1)); $call=norm_call((string)($h['callsign']??''));
  if($st<=0||$en<=0||$sid<=0||$mod===''||$call==='') continue;
  $key=implode('|',[$mod,$sid,$st,$en]);
  $payload=json_encode($h,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
  if($payload===false) continue;
  $stmt->bindValue(':k',$key,SQLITE3_TEXT); $stmt->bindValue(':c',$call,SQLITE3_TEXT); $stmt->bindValue(':m',$mod,SQLITE3_TEXT);
  $stmt->bindValue(':sid',$sid,SQLITE3_INTEGER); $stmt->bindValue(':st',$st,SQLITE3_INTEGER); $stmt->bindValue(':en',$en,SQLITE3_INTEGER);
  $stmt->bindValue(':du',max(0,(int)($h['duration']??($en-$st))),SQLITE3_INTEGER); $stmt->bindValue(':pl',$payload,SQLITE3_TEXT);
  $stmt->bindValue(':fs',$now,SQLITE3_INTEGER); $stmt->bindValue(':ls',$now,SQLITE3_INTEGER); $stmt->execute(); $count++;
}
$cutoff=$now-(31*86400);
$del=$db->prepare('DELETE FROM history WHERE started_at<:cut'); $del->bindValue(':cut',$cutoff,SQLITE3_INTEGER); $del->execute();
$db->exec('COMMIT');
$db->exec('PRAGMA wal_checkpoint(PASSIVE)');
$total=(int)$db->querySingle('SELECT COUNT(*) FROM history');
$min=(int)$db->querySingle('SELECT COALESCE(MIN(started_at),0) FROM history');
$max=(int)$db->querySingle('SELECT COALESCE(MAX(started_at),0) FROM history');
echo "ok inserted_or_updated=$count total=$total min=$min max=$max\n";
