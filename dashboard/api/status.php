<?php

declare(strict_types=1);

require __DIR__ . '/common.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');

$cacheFile = '/var/cache/xlx-dashboard/status.json';
$privateCacheFile = '/var/cache/xlx-dashboard/status-private.json';
$lockFile = '/var/cache/xlx-dashboard/status.lock';
$cacheTtl = 1;

function status_cache_is_public_safe(mixed $value): bool {
    if (!is_array($value)) return true;
    $forbidden = ['ip'=>true,'endpoint_ip'=>true,'via'=>true,'peer'=>true];
    foreach ($value as $key => $child) {
        if (is_string($key) && isset($forbidden[strtolower($key)])) return false;
        if (is_array($child) && !status_cache_is_public_safe($child)) return false;
    }
    return true;
}

function status_read_cached(string $cacheFile, int $cacheTtl, bool $allowExpired = false): ?string {
    if (!is_readable($cacheFile)) return null;
    clearstatcache(true, $cacheFile);
    $mtime = filemtime($cacheFile);
    if (!$allowExpired && ($mtime === false || (time() - $mtime) > $cacheTtl)) return null;
    $json = file_get_contents($cacheFile);
    if ($json === false || $json === '') return null;
    $decoded = json_decode($json, true);
    return is_array($decoded) && !empty($decoded['ok']) && status_cache_is_public_safe($decoded) ? $json : null;
}

function status_atomic_write(string $path, string $json, int $mode = 0640): void {
    $tmp = $path . '.' . getmypid() . '.tmp';
    if (file_put_contents($tmp, $json, LOCK_EX) === false) throw new RuntimeException('Falha ao gravar cache temporário.');
    @chmod($tmp, $mode);
    if (!rename($tmp, $path)) {@unlink($tmp);throw new RuntimeException('Falha ao publicar cache.');}
}

function status_public_connection(array $connection): array {
    unset($connection['ip'], $connection['via'], $connection['peer'], $connection['endpoint_ip']);
    return $connection;
}

function status_public_tx(?array $tx): ?array {
    if ($tx === null) return null;
    unset($tx['ip'], $tx['endpoint_ip'], $tx['via'], $tx['peer']);
    $gateway=trim((string)($tx['gateway']??''));
    if($gateway!==''&&filter_var($gateway,FILTER_VALIDATE_IP)!==false)$tx['gateway']=trim((string)($tx['callsign']??''))?:'Não identificado';
    return $tx;
}

$cached = status_read_cached($cacheFile, $cacheTtl);
if ($cached !== null) {header('X-XLX-Cache: fresh');echo $cached;exit;}

$lockHandle = fopen($lockFile, 'c');
if ($lockHandle === false) {http_response_code(503);echo json_encode(['ok'=>false,'error'=>'status_lock_unavailable']);exit;}

try {
    if (!flock($lockHandle, LOCK_EX | LOCK_NB)) {
        $stale = status_read_cached($cacheFile, $cacheTtl, true);
        fclose($lockHandle);
        if ($stale !== null) {header('X-XLX-Cache: stale-while-refresh');echo $stale;exit;}
        http_response_code(503);echo json_encode(['ok'=>false,'error'=>'status_refresh_in_progress']);exit;
    }

    $cached = status_read_cached($cacheFile, $cacheTtl);
    if ($cached !== null) {flock($lockHandle, LOCK_UN);fclose($lockHandle);header('X-XLX-Cache: fresh');echo $cached;exit;}

    $connections = parse_xml_connections();
    $tx = active_and_history($connections);
    $online = online_index($connections);
    $modules = [];

    foreach (cfg()['modules'] as $letter => $meta) {
        $moduleConnections = array_values(array_filter($connections, static fn(array $connection): bool => ($connection['module'] ?? '') === $letter));
        $protocols = array_values(array_unique(array_filter(array_column($moduleConnections, 'protocol'))));
        $lastTransmission = null;
        foreach ($tx['history'] as $historyItem) {
            if (($historyItem['module'] ?? '') === $letter) {$lastTransmission = status_public_tx($historyItem);break;}
        }
        $modules[$letter] = [
            'module'=>$letter,
            'name'=>(string)($meta['name']??('Module '.$letter)),
            'configured_protocol'=>(string)($meta['protocol']??''),
            'access'=>(string)($meta['access']??''),
            'dmr_tg'=>(string)($meta['dmr_tg']??''),
            'ysf_dgid'=>(string)($meta['ysf_dgid']??''),
            'connected_count'=>count($moduleConnections),
            'protocols'=>$protocols,
            'transmission'=>status_public_tx($tx['active'][$letter]??null),
            'last_transmission'=>$lastTransmission,
        ];
    }

    $history = array_map(static function(array $historyItem) use ($online): array {
        $historyItem['online'] = !empty($online[$historyItem['callsign'] ?? '']);
        return status_public_tx($historyItem) ?? [];
    }, $tx['history']);
    $publicConnections = array_map('status_public_connection', $connections);
    $reflectorCode = strtoupper((string)(cfg()['reflector_code'] ?? ''));
    $generatedAt = time();

    $payload = [
        'ok'=>true,'generated_at'=>$generatedAt,'server_name'=>(string)(cfg()['server_name']??'XLX'),
        'reflector_code'=>$reflectorCode,'dtmf_number'=>ctype_digit($reflectorCode)?(ltrim($reflectorCode,'0')?:'0'):'',
        'locale'=>(string)(cfg()['locale']??'pt-BR'),'ysf_id'=>(string)(cfg()['ysf_id']??''),
        'dmr_tg'=>(string)(cfg()['dmr_tg']??''),'dmr_radio_tg'=>(string)(cfg()['dmr_radio_tg']??''),
        'active_count'=>count($tx['active']),'connected_count'=>count($connections),'modules'=>$modules,'history'=>$history,
        'connections'=>$publicConnections,
        'sources'=>['xml'=>is_readable(cfg()['xml_path']),'log'=>is_readable(cfg()['log_path']),'db'=>is_readable(cfg()['users_db'])],
    ];
    $privatePayload = ['ok'=>true,'generated_at'=>$generatedAt,'connections'=>$connections];

    $json=json_encode($payload,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
    $privateJson=json_encode($privatePayload,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);
    if($json===false||$privateJson===false)throw new RuntimeException('Falha ao gerar JSON.');

    status_atomic_write($privateCacheFile,$privateJson,0640);
    status_atomic_write($cacheFile,$json,0640);
    echo $json;
    flock($lockHandle,LOCK_UN);fclose($lockHandle);
} catch (Throwable $exception) {
    if (is_resource($lockHandle)) {flock($lockHandle,LOCK_UN);fclose($lockHandle);}
    $fallback=status_read_cached($cacheFile,$cacheTtl,true);
    if($fallback!==null){echo $fallback;exit;}
    http_response_code(503);
    echo json_encode(['ok'=>false,'error'=>'status_temporarily_unavailable'],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
}
