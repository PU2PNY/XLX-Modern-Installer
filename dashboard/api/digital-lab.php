<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store, max-age=0');
header('Pragma: no-cache');

const SNAPSHOT = '/var/lib/xlx-aprs-dprs/public.json';
const DMR_STATE = '/var/lib/xlx-modern-dmr-data/state.json';
const MAX_BYTES = 2097152;
const DMR_STATE_MAX_BYTES = 1048576;
const DMR_TA_ACTIVE_SECONDS = 900;

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

// Recent DMR Talker Alias is broadcast by the radio itself. Expose only the
// resolved callsign + alias metadata; never expose DMR ID or raw payload.
$data['dmr_talker_alias'] = [];
if (is_file(DMR_STATE) && is_readable(DMR_STATE)) {
    $dmrSize = filesize(DMR_STATE);
    if ($dmrSize !== false && $dmrSize >= 2 && $dmrSize <= DMR_STATE_MAX_BYTES) {
        $dmrRaw = file_get_contents(DMR_STATE);
        if ($dmrRaw !== false) {
            try {
                $dmrState = json_decode($dmrRaw, true, 32, JSON_THROW_ON_ERROR);
                $taRows = is_array($dmrState['talker_alias'] ?? null) ? $dmrState['talker_alias'] : [];
                foreach ($taRows as $row) {
                    if (!is_array($row)) continue;
                    $call = strtoupper(trim((string)($row['callsign'] ?? '')));
                    $alias = trim((string)($row['alias'] ?? ''));
                    $seen = trim((string)($row['last_seen'] ?? ''));
                    $seenTs = strtotime($seen);
                    if (!preg_match('/^[A-Z0-9]{3,8}(?:-[0-9]{1,2})?$/', $call)) continue;
                    if ($alias === '' || $seenTs === false || (time() - $seenTs) > DMR_TA_ACTIVE_SECONDS) continue;
                    $alias = preg_replace('/[\x00-\x1F\x7F]/u', ' ', $alias) ?? '';
                    $alias = trim(preg_replace('/\s+/u', ' ', $alias) ?? '');
                    if ($alias === '') continue;
                    $data['dmr_talker_alias'][] = [
                        'callsign' => $call,
                        'alias' => mb_substr($alias, 0, 80, 'UTF-8'),
                        'tg' => (int)($row['tg'] ?? 0),
                        'module' => preg_match('/^[A-Z]$/', (string)($row['module'] ?? '')) ? (string)$row['module'] : '',
                        'last_seen' => $seen,
                        'confidence' => 'radio-reported',
                    ];
                    if (count($data['dmr_talker_alias']) >= 30) break;
                }
            } catch (Throwable $e) {
                $data['dmr_talker_alias'] = [];
            }
        }
    }
}

$generated = strtotime((string)($data['generated_at'] ?? ''));
$data['stale'] = $generated === false || (time() - $generated) > 15;
$data['ok'] = true;
$data['configured'] = true;

respond($data);
