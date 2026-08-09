<?php
declare(strict_types=1);

header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store');

require dirname(__DIR__) . '/certificado-config.php';
require dirname(__DIR__) . '/api/common.php';
require dirname(__DIR__) . '/api/authorized-sync-v1.php';
if (is_file(dirname(__DIR__) . '/api/user-directory.php')) {
    require dirname(__DIR__) . '/api/user-directory.php';
}

function cert_json(array $payload, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function cert_data_dir(): string
{
    return getenv('XLX_CERT_DATA_DIR') ?: '/var/lib/xlx-certificates';
}
function cert_records_file(): string
{
    return cert_data_dir() . '/emissoes.jsonl';
}
function cert_key_file(): string
{
    return getenv('XLX_CERT_KEY_FILE') ?: '/etc/xlx-certificates/hmac.key';
}
function cert_clean_call(string $value): string
{
    $value = strtoupper(trim($value));
    $value = preg_replace('/[^A-Z0-9]/', '', $value) ?? '';
    if (!preg_match('/^[A-Z0-9]{3,12}$/', $value)) {
        return '';
    }
    return $value;
}
function cert_key(): string
{
    $key = @file_get_contents(cert_key_file());
    if ($key === false || trim($key) === '') {
        throw new RuntimeException('Chave de validação indisponível.');
    }
    return trim($key);
}
function cert_signature(array $record): string
{
    $parts = [
        (string)($record['id'] ?? ''),
        (string)($record['campaign_id'] ?? ''),
        (string)($record['callsign'] ?? ''),
        (string)($record['issued_at'] ?? ''),
        (string)($record['reflector'] ?? ''),
    ];
    return hash_hmac('sha256', implode('|', $parts), cert_key());
}
function cert_find_record(string $id): ?array
{
    if (!preg_match('/^[A-Z0-9-]{12,80}$/', $id)) return null;
    $path = cert_records_file();
    if (!is_readable($path)) return null;
    $handle = fopen($path, 'rb');
    if (!$handle) return null;
    $found = null;
    while (($line = fgets($handle)) !== false) {
        $row = json_decode(trim($line), true);
        if (is_array($row) && hash_equals((string)($row['id'] ?? ''), $id)) {
            $found = $row;
        }
    }
    fclose($handle);
    return $found;
}
function cert_existing_record(string $campaignId, string $callsign): ?array
{
    $path = cert_records_file();
    if (!is_readable($path)) return null;
    $handle = fopen($path, 'rb');
    if (!$handle) return null;
    $found = null;
    while (($line = fgets($handle)) !== false) {
        $row = json_decode(trim($line), true);
        if (!is_array($row)) continue;
        if (($row['campaign_id'] ?? '') === $campaignId && ($row['callsign'] ?? '') === $callsign) {
            $found = $row;
        }
    }
    fclose($handle);
    return $found;
}

function cert_activity(string $callsign, array $campaign): array
{
    $connections = parse_xml_connections_sync();
    if (function_exists('xlx_user_directory_apply')) {
        $connections = array_map('xlx_user_directory_apply', $connections);
    }

    $tx = active_and_history_sync(
        $connections,
        5000,
        (int)$campaign['start_ts']
    );

    $items = array_values(array_filter(
        $tx['history'],
        static fn(array $item): bool =>
            strtoupper((string)($item['callsign'] ?? '')) === $callsign
            && (int)($item['started_at'] ?? 0) >= (int)$campaign['start_ts']
            && (int)($item['started_at'] ?? 0) <= (int)$campaign['end_ts']
    ));

    if ($items === []) {
        return [
            'eligible' => false,
            'callsign' => $callsign,
            'name' => '',
            'location' => '',
            'country' => ['code' => '', 'name' => '', 'flag' => '🌐'],
            'stats' => [
                'transmissions' => 0,
                'duration_total' => 0,
                'protocols' => [],
                'modules' => [],
                'first_tx' => null,
                'last_tx' => null,
            ],
        ];
    }

    usort($items, static fn(array $a, array $b): int => (int)$a['started_at'] <=> (int)$b['started_at']);
    $latest = $items[array_key_last($items)];
    if (function_exists('xlx_user_directory_apply')) {
        $latest = xlx_user_directory_apply($latest);
    }

    $protocols = array_values(array_unique(array_filter(array_map(
        static fn(array $item): string => trim((string)($item['protocol'] ?? '')),
        $items
    ))));
    $modules = array_values(array_unique(array_filter(array_map(
        static fn(array $item): string => trim((string)($item['module'] ?? '')),
        $items
    ))));

    return [
        'eligible' => true,
        'callsign' => $callsign,
        'name' => trim((string)($latest['name'] ?? '')),
        'location' => trim((string)($latest['location'] ?? '')),
        'country' => $latest['country'] ?? country_for_call_sync($callsign),
        'stats' => [
            'transmissions' => count($items),
            'duration_total' => array_sum(array_map(static fn(array $item): int => max(0, (int)($item['duration'] ?? 0)), $items)),
            'protocols' => $protocols,
            'modules' => $modules,
            'first_tx' => (int)($items[0]['started_at'] ?? 0),
            'last_tx' => (int)($latest['started_at'] ?? 0),
        ],
    ];
}

function cert_public_record(array $record): array
{
    return [
        'id' => $record['id'],
        'campaign_id' => $record['campaign_id'],
        'campaign_title' => $record['campaign_title'],
        'callsign' => $record['callsign'],
        'name' => $record['name'],
        'location' => $record['location'],
        'country' => $record['country'],
        'stats' => $record['stats'],
        'issued_at' => $record['issued_at'],
        'reflector' => $record['reflector'],
        'reflector_title' => $record['reflector_title'],
        'signature' => cert_signature($record),
    ];
}

$action = strtolower(trim((string)($_GET['action'] ?? $_POST['action'] ?? 'campaign')));

try {
    if ($action === 'campaign') {
        cert_json(['ok' => true, 'campaign' => cert_current_campaign(), 'reflector' => cert_reflector()]);
    }

    if ($action === 'lookup') {
        $callsign = cert_clean_call((string)($_GET['callsign'] ?? ''));
        if ($callsign === '') cert_json(['ok' => false, 'error' => 'invalid_callsign'], 422);
        $campaign = cert_current_campaign();
        cert_json(['ok' => true, 'campaign' => $campaign, 'operator' => cert_activity($callsign, $campaign)]);
    }

    if ($action === 'issue') {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') cert_json(['ok' => false, 'error' => 'method_not_allowed'], 405);
        $callsign = cert_clean_call((string)($_POST['callsign'] ?? ''));
        if ($callsign === '') cert_json(['ok' => false, 'error' => 'invalid_callsign'], 422);

        $campaign = cert_current_campaign();
        $activity = cert_activity($callsign, $campaign);
        if (empty($activity['eligible'])) cert_json(['ok' => false, 'error' => 'not_eligible'], 409);

        $existing = cert_existing_record((string)$campaign['id'], $callsign);
        if ($existing !== null) cert_json(['ok' => true, 'reused' => true, 'certificate' => cert_public_record($existing)]);

        $reflector = cert_reflector();
        $record = [
            'id' => 'XLX-' . strtoupper(bin2hex(random_bytes(8))),
            'campaign_id' => (string)$campaign['id'],
            'campaign_title' => (string)$campaign['title'],
            'callsign' => $callsign,
            'name' => (string)$activity['name'],
            'location' => (string)$activity['location'],
            'country' => $activity['country'],
            'stats' => $activity['stats'],
            'issued_at' => time(),
            'reflector' => $reflector['name'],
            'reflector_title' => $reflector['title'],
        ];

        $path = cert_records_file();
        $handle = fopen($path, 'c+');
        if (!$handle) throw new RuntimeException('Registro de emissões indisponível.');
        if (!flock($handle, LOCK_EX)) throw new RuntimeException('Não foi possível bloquear registro de emissões.');

        rewind($handle);
        while (($line = fgets($handle)) !== false) {
            $row = json_decode(trim($line), true);
            if (is_array($row) && ($row['campaign_id'] ?? '') === $campaign['id'] && ($row['callsign'] ?? '') === $callsign) {
                flock($handle, LOCK_UN); fclose($handle);
                cert_json(['ok' => true, 'reused' => true, 'certificate' => cert_public_record($row)]);
            }
        }

        fseek($handle, 0, SEEK_END);
        $encoded = json_encode($record, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
        if ($encoded === false || fwrite($handle, $encoded . "\n") === false) {
            flock($handle, LOCK_UN); fclose($handle);
            throw new RuntimeException('Falha ao registrar emissão.');
        }
        fflush($handle); flock($handle, LOCK_UN); fclose($handle);
        cert_json(['ok' => true, 'reused' => false, 'certificate' => cert_public_record($record)]);
    }

    if ($action === 'verify' || $action === 'qr') {
        $id = strtoupper(trim((string)($_GET['id'] ?? '')));
        $signature = strtolower(trim((string)($_GET['sig'] ?? '')));
        $record = cert_find_record($id);
        $valid = $record !== null && preg_match('/^[a-f0-9]{64}$/', $signature) && hash_equals(cert_signature($record), $signature);

        if ($action === 'verify') {
            cert_json(['ok' => true, 'valid' => $valid, 'certificate' => $valid ? cert_public_record($record) : null]);
        }

        if (!$valid) {
            http_response_code(404); exit;
        }
        $reflector = cert_reflector();
        $domain = preg_replace('#^https?://#i', '', $reflector['domain']) ?? '';
        $url = 'https://' . $domain . '/certificado-validar.php?id=' . rawurlencode($id) . '&sig=' . rawurlencode($signature);
        $binary = '/usr/bin/qrencode';
        if (!is_executable($binary)) throw new RuntimeException('qrencode indisponível.');
        $descriptors = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
        $process = proc_open([$binary, '-t', 'PNG', '-o', '-', '-s', '6', '-m', '2', $url], $descriptors, $pipes);
        if (!is_resource($process)) throw new RuntimeException('Falha ao iniciar qrencode.');
        $png = stream_get_contents($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[1]); fclose($pipes[2]);
        $code = proc_close($process);
        if ($code !== 0 || $png === false || $png === '') throw new RuntimeException('Falha ao gerar QR: ' . trim((string)$stderr));
        header('Content-Type: image/png');
        header('Cache-Control: private, max-age=3600');
        echo $png; exit;
    }

    cert_json(['ok' => false, 'error' => 'unknown_action'], 404);
} catch (Throwable $exception) {
    cert_json(['ok' => false, 'error' => 'certificate_service_error'], 500);
}
