<?php

declare(strict_types=1);

function runCommand(array $command): array
{
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $process = proc_open(
        $command,
        $descriptors,
        $pipes,
        null,
        [
            'LANG' => 'C',
            'LC_ALL' => 'C',
        ]
    );

    if (!is_resource($process)) {
        return [
            'exit_code' => 127,
            'stdout' => '',
            'stderr' => 'Não foi possível iniciar o processo.',
        ];
    }

    fclose($pipes[0]);

    $stdout = (string) stream_get_contents(
        $pipes[1]
    );

    $stderr = (string) stream_get_contents(
        $pipes[2]
    );

    fclose($pipes[1]);
    fclose($pipes[2]);

    $exitCode = proc_close($process);

    return [
        'exit_code' => $exitCode,
        'stdout' => $stdout,
        'stderr' => $stderr,
    ];
}

function sameIp(
    string $first,
    string $second
): bool {
    $firstBinary = @inet_pton($first);
    $secondBinary = @inet_pton($second);

    return (
        $firstBinary !== false
        && $secondBinary !== false
        && $firstBinary === $secondBinary
    );
}

function measureTarget(string $ip): array
{
    $result = runCommand([
        '/usr/bin/timeout',
        '-k',
        '2s',
        '10s',
        '/usr/bin/mtr',
        '-r',
        '-C',
        '-c',
        '3',
        '-i',
        '1',
        '-n',
        $ip,
    ]);

    $lines = preg_split(
        '/\r\n|\n|\r/',
        trim($result['stdout'])
    );

    $targetRow = null;
    $lastRespondingRow = null;

    foreach ($lines as $index => $line) {
        if (
            $index === 0
            || trim($line) === ''
        ) {
            continue;
        }

        $row = str_getcsv($line);

        if (count($row) < 14) {
            continue;
        }

        $rowIp = trim(
            (string) ($row[5] ?? '')
        );

        if (
            $rowIp === ''
            || $rowIp === '???'
            || filter_var(
                $rowIp,
                FILTER_VALIDATE_IP
            ) === false
        ) {
            continue;
        }

        $sent = (int) (
            $row[7] ?? 0
        );

        $loss = (float) (
            $row[6] ?? 100
        );

        if (
            $sent > 0
            && $loss < 100
        ) {
            $lastRespondingRow = $row;
        }

        if (sameIp($rowIp, $ip)) {
            $targetRow = $row;
        }
    }

    $selectedRow = null;
    $routePartial = false;

    if ($targetRow !== null) {
        $targetSent = (int) (
            $targetRow[7] ?? 0
        );

        $targetLoss = (float) (
            $targetRow[6] ?? 100
        );

        if (
            $targetSent > 0
            && $targetLoss < 100
        ) {
            $selectedRow = $targetRow;
        }
    }

    if (
        $selectedRow === null
        && $lastRespondingRow !== null
    ) {
        $selectedRow = $lastRespondingRow;
        $routePartial = true;
    }

    if ($selectedRow === null) {
        return [
            'found' => false,
            'route_partial' => false,
            'average' => null,
            'loss' => null,
            'jitter' => null,
            'last' => null,
            'stderr' => trim(
                $result['stderr']
            ),
        ];
    }

    $sent = (int) (
        $selectedRow[7] ?? 0
    );

    $loss = round(
        (float) (
            $selectedRow[6] ?? 100
        ),
        1
    );

    if (
        $sent <= 0
        || $loss >= 100
    ) {
        return [
            'found' => true,
            'route_partial' => $routePartial,
            'average' => null,
            'loss' => $loss,
            'jitter' => null,
            'last' => null,
            'stderr' => trim(
                $result['stderr']
            ),
        ];
    }

    return [
        'found' => true,
        'route_partial' => $routePartial,
        'average' => round(
            (float) (
                $selectedRow[10] ?? 0
            ),
            1
        ),
        'loss' => $loss,
        'jitter' => round(
            (float) (
                $selectedRow[13] ?? 0
            ),
            1
        ),
        'last' => round(
            (float) (
                $selectedRow[9] ?? 0
            ),
            1
        ),
        'stderr' => trim(
            $result['stderr']
        ),
    ];
}

function readJsonFile(string $file): ?array
{
    if (!is_readable($file)) {
        return null;
    }

    $decoded = json_decode(
        (string) file_get_contents($file),
        true
    );

    return is_array($decoded)
        ? $decoded
        : null;
}

/*
 * Autoteste disponível somente pela linha de comando.
 */
if (
    PHP_SAPI === 'cli'
    && in_array(
        '--self-test',
        $argv ?? [],
        true
    )
) {
    $measurement = measureTarget(
        '1.1.1.1'
    );

    if (
        !$measurement['found']
        || $measurement['loss'] === null
    ) {
        fwrite(
            STDERR,
            "Autoteste MTR falhou.\n"
        );

        exit(1);
    }

    echo json_encode(
        [
            'ok' => true,
            'target_found' =>
                $measurement['found'],
            'average' =>
                $measurement['average'],
            'loss' =>
                $measurement['loss'],
            'jitter' =>
                $measurement['jitter'],
        ],
        JSON_PRETTY_PRINT
        | JSON_UNESCAPED_SLASHES
    );

    echo PHP_EOL;
    exit(0);
}

header(
    'Content-Type: application/json; charset=utf-8'
);

header(
    'Cache-Control: no-store, no-cache, must-revalidate, max-age=0'
);

header('Pragma: no-cache');

function respond(
    array $data,
    int $status = 200
): void {
    http_response_code($status);

    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE
        | JSON_UNESCAPED_SLASHES
        | JSON_INVALID_UTF8_SUBSTITUTE
    );

    exit;
}

$callsign = strtoupper(
    trim(
        (string) (
            $_GET['callsign']
            ?? ''
        )
    )
);

$suffix = strtoupper(
    trim(
        (string) (
            $_GET['suffix']
            ?? ''
        )
    )
);

$module = strtoupper(
    trim(
        (string) (
            $_GET['module']
            ?? ''
        )
    )
);

$key = trim(
    (string) (
        $_GET['key']
        ?? ''
    )
);

if (
    !preg_match(
        '/^[A-Z0-9]{3,10}$/',
        $callsign
    )
    || !preg_match(
        '/^[A-E]$/',
        $module
    )
    || (
        $suffix !== ''
        && !preg_match(
            '/^[A-Z0-9]{1,4}$/',
            $suffix
        )
    )
    || strlen($key) > 80
) {
    respond([
        'ok' => false,
        'error' => 'invalid_request',
    ], 400);
}

/*
 * Obtém o destino diretamente da mesma API rápida,
 * executando-a localmente pelo PHP CLI.
 *
 * Evita a cadeia:
 * mtr.php -> curl -> Apache -> live.php
 *
 * O navegador continua sem escolher nem enviar o endereço IP.
 */
$liveResult = runCommand([
    '/usr/bin/php',
    '-d',
    'date.timezone=America/Sao_Paulo',
    __DIR__ . '/live.php',
]);

$live = json_decode(
    trim($liveResult['stdout']),
    true
);

if (
    !is_array($live)
    || empty($live['ok'])
    || !isset($live['active'])
    || !is_array($live['active'])
) {
    respond([
        'ok' => false,
        'error' => 'live_unavailable',
    ], 503);
}

$transmission =
    $live['active'][$module]
    ?? null;

if (
    !is_array($transmission)
    || strtoupper(
        trim(
            (string) (
                $transmission['callsign']
                ?? ''
            )
        )
    ) !== $callsign
    || (
        $key !== ''
        && trim(
            (string) (
                $transmission['key']
                ?? ''
            )
        ) !== $key
    )
) {
    respond([
        'ok' => false,
        'state' => 'inactive',
    ], 409);
}

$gateway = trim(
    (string) (
        $transmission['gateway']
        ?? ''
    )
);

if ($gateway === '') {
    $gateway = trim(
        $callsign
        . (
            $suffix !== ''
                ? ' ' . $suffix
                : ''
        )
    );
}

$ip = trim(
    (string) (
        $transmission['ip']
        ?? ''
    )
);

if (
    !filter_var(
        $ip,
        FILTER_VALIDATE_IP,
        FILTER_FLAG_NO_PRIV_RANGE
        | FILTER_FLAG_NO_RES_RANGE
    )
) {
    respond([
        'ok' => true,
        'state' => 'waiting',
        'gateway' => $gateway,
        'status' => 'unknown',
        'status_label' =>
            'Aguardando rota',
        'avg_ms' => null,
        'loss_pct' => null,
        'jitter_ms' => null,
        'history' => [],
    ]);
}

$cacheDirectory =
    '/var/cache/xlx-dashboard/mtr';

$cacheTtl = 9;

$hash = hash(
    'sha256',
    'route-partial-v4|' . $ip
);

$cacheFile =
    $cacheDirectory
    . '/'
    . $hash
    . '.json';

$lockFile =
    $cacheDirectory
    . '/'
    . $hash
    . '.lock';

$cached = readJsonFile(
    $cacheFile
);

$cacheAge = is_file($cacheFile)
    ? time() - (int) filemtime($cacheFile)
    : PHP_INT_MAX;

if (
    is_array($cached)
    && $cacheAge <= $cacheTtl
) {
    $cached['gateway'] = $gateway;
    $cached['cached'] = true;
    $cached['cache_age'] = $cacheAge;

    respond($cached);
}

$targetLock = fopen(
    $lockFile,
    'c'
);

if ($targetLock === false) {
    respond([
        'ok' => false,
        'error' => 'lock_unavailable',
    ], 503);
}

if (
    !flock(
        $targetLock,
        LOCK_EX | LOCK_NB
    )
) {
    fclose($targetLock);

    if (is_array($cached)) {
        $cached['gateway'] = $gateway;
        $cached['cached'] = true;
        $cached['stale'] = true;

        respond($cached);
    }

    respond([
        'ok' => true,
        'state' => 'measuring',
        'gateway' => $gateway,
        'status' => 'unknown',
        'status_label' => 'Medindo',
        'avg_ms' => null,
        'loss_pct' => null,
        'jitter_ms' => null,
        'history' => [],
    ]);
}

/*
 * Revalida o cache depois de obter a trava.
 */
$cached = readJsonFile(
    $cacheFile
);

$cacheAge = is_file($cacheFile)
    ? time() - (int) filemtime($cacheFile)
    : PHP_INT_MAX;

if (
    is_array($cached)
    && $cacheAge <= $cacheTtl
) {
    flock(
        $targetLock,
        LOCK_UN
    );

    fclose($targetLock);

    $cached['gateway'] = $gateway;
    $cached['cached'] = true;
    $cached['cache_age'] = $cacheAge;

    respond($cached);
}

/*
 * Limite global de três processos MTR.
 */
$slotHandle = null;

for ($slot = 1; $slot <= 3; $slot++) {
    $candidate = fopen(
        $cacheDirectory
        . '/slot_'
        . $slot
        . '.lock',
        'c'
    );

    if (
        $candidate !== false
        && flock(
            $candidate,
            LOCK_EX | LOCK_NB
        )
    ) {
        $slotHandle = $candidate;
        break;
    }

    if ($candidate !== false) {
        fclose($candidate);
    }
}

if ($slotHandle === null) {
    flock(
        $targetLock,
        LOCK_UN
    );

    fclose($targetLock);

    if (is_array($cached)) {
        $cached['gateway'] = $gateway;
        $cached['cached'] = true;
        $cached['stale'] = true;

        respond($cached);
    }

    respond([
        'ok' => true,
        'state' => 'queued',
        'gateway' => $gateway,
        'status' => 'unknown',
        'status_label' => 'Na fila',
        'avg_ms' => null,
        'loss_pct' => null,
        'jitter_ms' => null,
        'history' => [],
    ]);
}

$measurement = measureTarget(
    $ip
);

flock(
    $slotHandle,
    LOCK_UN
);

fclose($slotHandle);

$average =
    $measurement['average'];

$loss =
    $measurement['loss'];

$jitter =
    $measurement['jitter'];

$status = 'unknown';
$statusLabel = 'Sem resposta';

$routePartial = !empty(
    $measurement['route_partial']
);

if (
    $routePartial
    && $average !== null
    && $loss !== null
    && $jitter !== null
) {
    /*
     * O destino bloqueia ICMP, mas há métricas válidas
     * do último salto respondente.
     */
    if (
        $average <= 150
        && $loss <= 5
        && $jitter <= 50
    ) {
        $status = 'warning';
        $statusLabel = 'Rota parcial';
    } else {
        $status = 'bad';
        $statusLabel = 'Rota parcial ruim';
    }
} elseif (
    $measurement['found']
    && $loss !== null
    && $loss >= 100
) {
    $status = 'bad';
    $statusLabel = 'Sem resposta';
} elseif (
    $average !== null
    && $loss !== null
    && $jitter !== null
) {
    if (
        $average <= 80
        && $loss <= 1
        && $jitter <= 20
    ) {
        $status = 'good';
        $statusLabel = 'Estável';
    } elseif (
        $average <= 150
        && $loss <= 5
        && $jitter <= 50
    ) {
        $status = 'warning';
        $statusLabel = 'Variação';
    } else {
        $status = 'bad';
        $statusLabel = 'Ruim';
    }
}

$history = [];

if (
    is_array($cached)
    && isset($cached['history'])
    && is_array($cached['history'])
) {
    $history = $cached['history'];
}

$history[] = $average;

$history = array_slice(
    $history,
    -8
);

$result = [
    'ok' => true,
    'state' => 'ready',
    'gateway' => $gateway,
    'status' => $status,
    'status_label' => $statusLabel,
    'route_partial' => $routePartial,
    'avg_ms' => $average,
    'loss_pct' => $loss,
    'jitter_ms' => $jitter,
    'history' => $history,
    'updated_at' => time(),
    'cycles' => 3,
    'cache_ttl' => $cacheTtl,
];

$tempFile =
    $cacheFile
    . '.tmp.'
    . getmypid();

$encoded = json_encode(
    $result,
    JSON_UNESCAPED_UNICODE
    | JSON_UNESCAPED_SLASHES
    | JSON_INVALID_UTF8_SUBSTITUTE
);

if (
    $encoded !== false
    && file_put_contents(
        $tempFile,
        $encoded,
        LOCK_EX
    ) !== false
) {
    rename(
        $tempFile,
        $cacheFile
    );

    chmod(
        $cacheFile,
        0640
    );
}

flock(
    $targetLock,
    LOCK_UN
);

fclose($targetLock);

if (
    trim(
        (string) (
            $measurement['stderr']
            ?? ''
        )
    ) !== ''
) {
    error_log(
        'XLX MTR: '
        . preg_replace(
            '/\s+/',
            ' ',
            trim(
                $measurement['stderr']
            )
        )
    );
}

/*
 * O IP utilizado não é devolvido nesta resposta.
 */
respond($result);
