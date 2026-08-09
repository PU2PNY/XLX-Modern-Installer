<?php

declare(strict_types=1);

require __DIR__ . '/common.php';
require __DIR__ . '/authorized-sync-v1.php';
require __DIR__ . '/user-directory.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$defaultHistoryLimit = (int)cfg()['history_limit'];
$requestedHistoryLimit = isset($_GET['history'])
    ? (int)$_GET['history']
    : $defaultHistoryLimit;

$requestedHistoryHours = isset($_GET['history_hours'])
    ? (int)$_GET['history_hours']
    : 0;

$is24HourHistory = $requestedHistoryHours === 24;

$historyLimit = $is24HourHistory
    ? 5000
    : (
        in_array($requestedHistoryLimit, [30, 150], true)
            ? $requestedHistoryLimit
            : $defaultHistoryLimit
    );

$historySince = $is24HourHistory
    ? time() - 86400
    : null;

$cacheVariant = $is24HourHistory
    ? '-24h'
    : (
        $historyLimit === $defaultHistoryLimit
            ? ''
            : '-' . $historyLimit
    );

$cacheFile = '/var/cache/xlx-dashboard/status' . $cacheVariant . '.json';
$lockFile  = '/var/cache/xlx-dashboard/status' . $cacheVariant . '.lock';
$cacheTtl  = 1;

function send_cached_status(
    string $cacheFile,
    int $cacheTtl,
    bool $allowExpired = false
): bool {
    if (!is_readable($cacheFile)) {
        return false;
    }

    clearstatcache(true, $cacheFile);
    $mtime = filemtime($cacheFile);

    if (
        !$allowExpired &&
        ($mtime === false || (time() - $mtime) > $cacheTtl)
    ) {
        return false;
    }

    $json = file_get_contents($cacheFile);

    if ($json === false || $json === '') {
        return false;
    }

    $decoded = json_decode($json, true);

    if (!is_array($decoded) || empty($decoded['ok'])) {
        return false;
    }

    header(
        'X-{{REFLECTOR_NAME}}-Cache: ' .
        ($allowExpired ? 'stale-while-refresh' : 'fresh')
    );

    echo $json;
    return true;
}

if (send_cached_status($cacheFile, $cacheTtl)) {
    exit;
}

$lockHandle = fopen($lockFile, 'c');

if ($lockHandle === false) {
    http_response_code(503);
    echo json_encode(
        ['ok' => false, 'error' => 'status_lock_unavailable'],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    exit;
}

try {
    if (!flock($lockHandle, LOCK_EX | LOCK_NB)) {
        if (send_cached_status($cacheFile, $cacheTtl, true)) {
            fclose($lockHandle);
            exit;
        }

        fclose($lockHandle);
        http_response_code(503);
        echo json_encode(
            ['ok' => false, 'error' => 'status_refresh_in_progress'],
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
        exit;
    }

    if (send_cached_status($cacheFile, $cacheTtl)) {
        flock($lockHandle, LOCK_UN);
        fclose($lockHandle);
        exit;
    }

    $connections = array_map(
        'xlx_user_directory_apply',
        parse_xml_connections_sync()
    );

    $tx = active_and_history_sync(
        $connections,
        $historyLimit,
        $historySince
    );

    foreach ($tx['active'] as $module => $transmission) {
        $tx['active'][$module] = xlx_user_directory_apply($transmission);
    }
    $tx['history'] = array_map('xlx_user_directory_apply', $tx['history']);

    $online = online_index($connections);
    $modules = [];

    foreach (cfg()['modules'] as $letter => $meta) {
        $moduleConnections = array_values(
            array_filter(
                $connections,
                static fn(array $connection): bool =>
                    $connection['module'] === $letter
            )
        );

        $protocols = array_values(
            array_unique(
                array_filter(array_column($moduleConnections, 'protocol'))
            )
        );

        $lastTransmission = null;
        foreach ($tx['history'] as $historyItem) {
            if ($historyItem['module'] === $letter) {
                $lastTransmission = $historyItem;
                break;
            }
        }

        $modules[$letter] = [
            'module' => $letter,
            'name' => $meta['name'],
            'configured_protocol' => $meta['protocol'],
            'access' => $meta['access'],
            'connected_count' => count($moduleConnections),
            'protocols' => $protocols,
            'transmission' => $tx['active'][$letter] ?? null,
            'last_transmission' => $lastTransmission,
        ];
    }

    $history = array_map(
        static function (array $historyItem) use ($online): array {
            $historyItem['online'] = !empty($online[$historyItem['callsign']]);
            return $historyItem;
        },
        $tx['history']
    );

    $payload = [
        'ok' => true,
        'generated_at' => time(),
        'server_name' => cfg()['server_name'],
        'active_count' => count($tx['active']),
        'connected_count' => count($connections),
        'modules' => $modules,
        'history' => $history,
        'connections' => $connections,
        'sources' => [
            'xml' => is_readable(cfg()['xml_path']),
            'log' => is_readable(cfg()['log_path']),
            'db' => is_readable(cfg()['users_db']),
            'overrides' => is_readable((string)(cfg()['users_override_db'] ?? '')),
        ],
    ];

    $json = json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES |
        JSON_INVALID_UTF8_SUBSTITUTE
    );

    if ($json === false) {
        throw new RuntimeException('Falha ao gerar JSON.');
    }

    $temporaryFile = $cacheFile . '.' . getmypid() . '.tmp';
    if (file_put_contents($temporaryFile, $json, LOCK_EX) === false) {
        throw new RuntimeException('Falha ao gravar cache temporário.');
    }
    if (!rename($temporaryFile, $cacheFile)) {
        @unlink($temporaryFile);
        throw new RuntimeException('Falha ao publicar cache.');
    }

    echo $json;
    flock($lockHandle, LOCK_UN);
    fclose($lockHandle);
} catch (Throwable $exception) {
    if (is_resource($lockHandle)) {
        flock($lockHandle, LOCK_UN);
        fclose($lockHandle);
    }

    if (is_readable($cacheFile)) {
        $fallback = file_get_contents($cacheFile);
        if ($fallback !== false && $fallback !== '') {
            echo $fallback;
            exit;
        }
    }

    http_response_code(503);
    echo json_encode(
        ['ok' => false, 'error' => 'status_temporarily_unavailable'],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
}
