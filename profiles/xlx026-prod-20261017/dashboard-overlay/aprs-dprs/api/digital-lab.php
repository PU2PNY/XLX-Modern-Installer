<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store, max-age=0');
header('Pragma: no-cache');

const SNAPSHOT = '/var/lib/xlx-aprs-dprs/public.json';
const MAX_BYTES = 2097152;

function respond(array $data, int $code = 200): never {
    http_response_code($code);
    $data['served_at'] = gmdate('c');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET');
    respond(['ok' => false, 'error' => 'method_not_allowed'], 405);
}

if (!is_file(SNAPSHOT) || !is_readable(SNAPSHOT)) {
    respond([
        'ok' => false,
        'configured' => false,
        'reason' => 'gateway_not_ready',
        'message' => 'Digital Lab aguardando ativação do gateway.'
    ]);
}

$size = filesize(SNAPSHOT);
if ($size === false || $size < 2 || $size > MAX_BYTES) {
    respond(['ok' => false, 'configured' => true, 'reason' => 'snapshot_invalid_size'], 503);
}

$raw = file_get_contents(SNAPSHOT);
if ($raw === false) {
    respond(['ok' => false, 'configured' => true, 'reason' => 'snapshot_read_failed'], 503);
}

try {
    $data = json_decode($raw, true, 64, JSON_THROW_ON_ERROR);
} catch (JsonException $e) {
    respond(['ok' => false, 'configured' => true, 'reason' => 'snapshot_invalid_json'], 503);
}

if (!is_array($data) || (int)($data['schema'] ?? 0) !== 1) {
    respond(['ok' => false, 'configured' => true, 'reason' => 'snapshot_schema_mismatch'], 503);
}

// Hard caps prevent a damaged snapshot from causing an oversized response.
$data['stations'] = array_slice(is_array($data['stations'] ?? null) ? $data['stations'] : [], 0, 60);
$data['events'] = array_slice(is_array($data['events'] ?? null) ? $data['events'] : [], 0, 50);
$data['commands'] = array_slice(is_array($data['commands'] ?? null) ? $data['commands'] : [], 0, 30);

$generated = strtotime((string)($data['generated_at'] ?? ''));
$data['stale'] = $generated === false || (time() - $generated) > 15;
$data['ok'] = true;
$data['configured'] = true;

respond($data);
