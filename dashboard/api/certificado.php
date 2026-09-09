<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('X-Content-Type-Options: nosniff');

require __DIR__ . '/common.php';
require dirname(__DIR__) . '/certificado-config.php';
require dirname(__DIR__) . '/lib/certificate-signature.php';

const CERT_DATA_DIR = '/var/lib/xlx-certificates';
const CERT_RECORDS = CERT_DATA_DIR . '/emissoes.jsonl';
const CERT_RATE = CERT_DATA_DIR . '/rate.json';
const CERT_SECRET = '/etc/xlx-certificates/secret';

function cert_json(array $payload, int $status = 200): never
{
    http_response_code($status);

    echo json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE
        | JSON_UNESCAPED_SLASHES
        | JSON_INVALID_UTF8_SUBSTITUTE
    );

    exit;
}

function cert_normalize_call(string $input): string
{
    $input = strtoupper(trim($input));

    if (strlen($input) > 24) {
        return '';
    }

    if (str_contains($input, '/')) {
        $input = explode('/', $input, 2)[0];
    }

    $input = preg_replace('/[^A-Z0-9]/', '', $input) ?? '';

    if (!preg_match('/^[A-Z0-9]{3,10}$/', $input)) {
        return '';
    }

    return $input;
}

function cert_rate_guard(string $callsign): void
{
    $now = time();
    $window = 60;
    $max = 5;
    $key = hash('sha256', $callsign);

    $fh = fopen(CERT_RATE, 'c+');

    if (!$fh) {
        throw new RuntimeException('Não foi possível abrir controle de requisições.');
    }

    try {
        if (!flock($fh, LOCK_EX)) {
            throw new RuntimeException('Não foi possível bloquear controle de requisições.');
        }

        rewind($fh);
        $raw = stream_get_contents($fh);
        $data = json_decode($raw ?: '{}', true);

        if (!is_array($data)) {
            $data = [];
        }

        foreach ($data as $k => $timestamps) {
            if (!is_array($timestamps)) {
                unset($data[$k]);
                continue;
            }

            $timestamps = array_values(
                array_filter(
                    $timestamps,
                    static fn($ts): bool =>
                        is_numeric($ts) && (int)$ts >= ($now - $window)
                )
            );

            if ($timestamps) {
                $data[$k] = $timestamps;
            } else {
                unset($data[$k]);
            }
        }

        $current = $data[$key] ?? [];

        if (count($current) >= $max) {
            flock($fh, LOCK_UN);
            fclose($fh);

            cert_json([
                'ok' => false,
                'code' => 'MUITAS_TENTATIVAS',
                'message' => 'Muitas tentativas para este indicativo. Aguarde um minuto e tente novamente.',
            ], 429);
        }

        $current[] = $now;
        $data[$key] = $current;

        rewind($fh);
        ftruncate($fh, 0);
        fwrite(
            $fh,
            json_encode($data, JSON_UNESCAPED_SLASHES)
        );
        fflush($fh);
        flock($fh, LOCK_UN);
    } finally {
        if (is_resource($fh)) {
            fclose($fh);
        }
    }
}

function cert_find_activity(string $callsign, array $campaign): ?array
{
    $connections = parse_xml_connections();

    /*
     * O próprio parser oficial do painel é reutilizado.
     * Não copiamos nem reinventamos a interpretação dos logs.
     */
    $tx = active_and_history(
        $connections,
        10000,
        $campaign['start']->getTimestamp()
    );

    $rows = [];

    foreach (($tx['history'] ?? []) as $row) {
        $rows[] = $row;
    }

    foreach (($tx['active'] ?? []) as $row) {
        $rows[] = $row;
    }

    $startTs = $campaign['start']->getTimestamp();
    $endTs = min(
        $campaign['end']->getTimestamp(),
        time()
    );

    $filtered = [];
    $seen = [];

    foreach ($rows as $row) {
        if (($row['callsign'] ?? '') !== $callsign) {
            continue;
        }

        $started = (int)($row['started_at'] ?? 0);

        if ($started < $startTs || $started > $endTs) {
            continue;
        }

        $key = (string)($row['key'] ?? '');
        if ($key === '') {
            $key = implode('|', [
                $callsign,
                (string)($row['module'] ?? ''),
                (string)$started,
                (string)($row['stream_id'] ?? ''),
            ]);
        }

        if (isset($seen[$key])) {
            continue;
        }

        $seen[$key] = true;
        $filtered[] = $row;
    }

    if (!$filtered) {
        return null;
    }

    usort(
        $filtered,
        static fn(array $a, array $b): int =>
            ((int)($a['started_at'] ?? 0))
            <=>
            ((int)($b['started_at'] ?? 0))
    );

    $protocols = [];
    $modules = [];
    $duration = 0;

    foreach ($filtered as $row) {
        $protocol = trim((string)($row['protocol'] ?? ''));
        $module = trim((string)($row['module'] ?? ''));

        if ($protocol !== '' && $protocol !== 'Não identificado') {
            $protocols[$protocol] = true;
        }

        if ($module !== '' && $module !== '?') {
            $modules[$module] = true;
        }

        if (isset($row['duration'])) {
            $duration += max(0, (int)$row['duration']);
        } elseif (($row['state'] ?? '') === 'active') {
            $duration += max(
                0,
                time() - (int)($row['started_at'] ?? time())
            );
        }
    }

    $first = $filtered[0];
    $last = $filtered[count($filtered) - 1];

    $user = user_lookup($callsign);
    $country = country_for_call($callsign);

    $name = trim((string)($last['name'] ?? ''));
    if ($name === '' || $name === 'Não informado') {
        $name = trim((string)($user['name'] ?? ''));
    }
    if ($name === '') {
        $name = 'Não informado';
    }

    $location = trim((string)($last['location'] ?? ''));
    if ($location === '' || $location === 'Não informada') {
        $location = trim((string)($user['location'] ?? ''));
    }
    if ($location === '') {
        $location = 'Não informada';
    }

    return [
        'callsign' => $callsign,
        'name' => $name,
        'location' => $location,
        'country' => $country,
        'stats' => [
            'transmissions' => count($filtered),
            'duration_total' => $duration,
            'protocols' => array_keys($protocols),
            'modules' => array_keys($modules),
            'first_tx' => (int)($first['started_at'] ?? 0),
            'last_tx' => (int)($last['started_at'] ?? 0),
        ],
    ];
}

function cert_secret(): string
{
    $secret = trim((string)@file_get_contents(CERT_SECRET));

    if (strlen($secret) < 32) {
        throw new RuntimeException('Segredo de validação indisponível.');
    }

    return $secret;
}

function cert_token(array $record): string
{
    return xlx_cert_token_from_record($record, cert_secret());
}

function cert_verification_url(array $record): string
{
    /*
     * Rota canônica pública do certificado.
     *
     * O ID e o token/HMAC não são alterados.
     */
    $https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
    $scheme = $https ? 'https' : 'http';
    $host = strtolower((string)($_SERVER['HTTP_HOST'] ?? '{{REFLECTOR_DOMAIN}}'));
    if (!preg_match('/^[a-z0-9.-]+(?::[0-9]{1,5})?$/D', $host)) $host = '{{REFLECTOR_DOMAIN}}';
    return $scheme . '://' . $host . '/?page=certificado&validar='
        . rawurlencode((string)($record['id'] ?? ''))
        . '&token=' . rawurlencode(cert_token($record));
}

function cert_public_record(array $record): array
{
    $record['verification_url'] = cert_verification_url($record);
    return $record;
}

function cert_find_record_by_id(string $id): ?array
{
    $fh = @fopen(CERT_RECORDS, 'r');

    if (!$fh) {
        return null;
    }

    try {
        if (!flock($fh, LOCK_SH)) {
            return null;
        }

        while (($line = fgets($fh)) !== false) {
            $record = json_decode(trim($line), true);

            if (
                is_array($record)
                && hash_equals(
                    (string)($record['id'] ?? ''),
                    $id
                )
            ) {
                flock($fh, LOCK_UN);
                return $record;
            }
        }

        flock($fh, LOCK_UN);
    } finally {
        fclose($fh);
    }

    return null;
}

function cert_issue(
    string $callsign,
    array $activity,
    array $campaign
): array {
    $publicCampaign = cert_public_campaign($campaign);

    $fh = fopen(CERT_RECORDS, 'c+');

    if (!$fh) {
        throw new RuntimeException('Não foi possível abrir arquivo de emissões.');
    }

    try {
        if (!flock($fh, LOCK_EX)) {
            throw new RuntimeException('Não foi possível bloquear arquivo de emissões.');
        }

        rewind($fh);

        while (($line = fgets($fh)) !== false) {
            $existing = json_decode(trim($line), true);

            if (!is_array($existing)) {
                continue;
            }

            if (
                ($existing['callsign'] ?? '') === $callsign
                && ($existing['campaign']['id'] ?? '') === $publicCampaign['id']
            ) {
                flock($fh, LOCK_UN);

                return [
                    'record' => cert_public_record($existing),
                    'reused' => true,
                ];
            }
        }

        $year = (new DateTimeImmutable('now', cert_timezone()))->format('Y');
        $short = strtoupper(
            substr(
                preg_replace(
                    '/[^A-Z0-9]/',
                    '',
                    strtr(
                        iconv(
                            'UTF-8',
                            'ASCII//TRANSLIT//IGNORE',
                            $campaign['theme']
                        ) ?: $campaign['theme'],
                        ['-' => '']
                    )
                ) ?: 'CERT',
                0,
                6
            )
        );

        $random = strtoupper(bin2hex(random_bytes(4)));

        $record = [
            'id' => "{{REFLECTOR_NAME}}-$year-$short-$random",
            'callsign' => $activity['callsign'],
            'name' => $activity['name'],
            'location' => $activity['location'],
            'country' => $activity['country'],
            'campaign' => $publicCampaign,
            'stats' => $activity['stats'],
            'issued_at' => time(),
            'issued_at_iso' =>
                (new DateTimeImmutable('now', cert_timezone()))
                    ->format(DateTimeInterface::ATOM),
        ];

        fseek($fh, 0, SEEK_END);

        $json = json_encode(
            $record,
            JSON_UNESCAPED_UNICODE
            | JSON_UNESCAPED_SLASHES
            | JSON_INVALID_UTF8_SUBSTITUTE
        );

        if ($json === false) {
            throw new RuntimeException('Falha ao serializar certificado.');
        }

        if (fwrite($fh, $json . PHP_EOL) === false) {
            throw new RuntimeException('Falha ao registrar certificado.');
        }

        fflush($fh);

        if (function_exists('fsync')) {
            @fsync($fh);
        }

        flock($fh, LOCK_UN);

        return [
            'record' => cert_public_record($record),
            'reused' => false,
        ];
    } finally {
        if (is_resource($fh)) {
            fclose($fh);
        }
    }
}

try {
    $action = strtolower(
        trim(
            (string)(
                $_POST['acao']
                ?? $_GET['acao']
                ?? 'campanha'
            )
        )
    );

    if ($action === 'campanha') {
        $campaign = cert_current_campaign();

        cert_json([
            'ok' => true,
            'campaign' => cert_public_campaign($campaign),
        ]);
    }

    if ($action === 'validar') {
        $id = trim((string)($_GET['id'] ?? ''));
        $token = trim((string)($_GET['token'] ?? ''));

        if (
            !preg_match('/^' . preg_quote('{{REFLECTOR_NAME}}', '/') . '-[A-Z0-9-]{8,80}$/', $id)
            || strlen($token) < 20
            || strlen($token) > 100
        ) {
            cert_json([
                'ok' => false,
                'valid' => false,
                'message' => 'Código de certificado inválido.',
            ], 400);
        }

        $record = cert_find_record_by_id($id);

        if (!$record) {
            cert_json([
                'ok' => false,
                'valid' => false,
                'message' => 'Certificado não encontrado.',
            ], 404);
        }

        $expected = cert_token($record);

        if (!xlx_cert_token_valid($record, cert_secret(), $token)) {
            cert_json([
                'ok' => false,
                'valid' => false,
                'message' => 'Assinatura de validação inválida.',
            ], 403);
        }

        cert_json([
            'ok' => true,
            'valid' => true,
            'message' => 'Certificado autêntico — participação confirmada pelo {{REFLECTOR_NAME}}.',
            'certificate' => cert_public_record($record),
        ]);
    }

    if (!in_array($action, ['consultar', 'emitir'], true)) {
        cert_json([
            'ok' => false,
            'message' => 'Ação inválida.',
        ], 400);
    }

    $callsign = cert_normalize_call(
        (string)(
            $_POST['callsign']
            ?? $_GET['callsign']
            ?? ''
        )
    );

    if ($callsign === '') {
        cert_json([
            'ok' => false,
            'code' => 'INDICATIVO_INVALIDO',
            'message' => 'Digite um indicativo válido.',
        ], 422);
    }

    cert_rate_guard($callsign);

    $campaign = cert_current_campaign();
    $activity = cert_find_activity($callsign, $campaign);

    if (!$activity) {
        cert_json([
            'ok' => false,
            'code' => 'SEM_ATIVIDADE',
            'message' =>
                'Ainda não encontramos transmissão de '
                . $callsign
                . ' no período deste certificado. Faça uma transmissão pelo {{REFLECTOR_NAME}} e tente novamente.',
            'campaign' => cert_public_campaign($campaign),
        ], 422);
    }

    if ($action === 'consultar') {
        cert_json([
            'ok' => true,
            'eligible' => true,
            'campaign' => cert_public_campaign($campaign),
            'operator' => $activity,
        ]);
    }

    if (
        ($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST'
    ) {
        cert_json([
            'ok' => false,
            'message' => 'A emissão deve ser solicitada por POST.',
        ], 405);
    }

    $issued = cert_issue(
        $callsign,
        $activity,
        $campaign
    );

    cert_json([
        'ok' => true,
        'issued' => true,
        'reused' => $issued['reused'],
        'message' => $issued['reused']
            ? 'Este certificado já havia sido emitido. A mesma via foi liberada novamente.'
            : 'Certificado emitido e registrado com sucesso.',
        'certificate' => $issued['record'],
    ]);

} catch (Throwable $e) {
    error_log(
        '[{{REFLECTOR_NAME}} CERTIFICADO] '
        . $e->getMessage()
    );

    cert_json([
        'ok' => false,
        'message' => 'Não foi possível processar o certificado neste momento.',
    ], 500);
}
