<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$logFile = '/var/log/xlx.log';
$statusCache = '/var/cache/xlx026-dashboard/status.json';

if (!is_readable($logFile)) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'error' => 'log_unavailable',
    ]);

    exit;
}

/*
 * Usa os dados já preparados pela API principal apenas para completar
 * nome, localização, protocolo, país, QRZ e gateway.
 *
 * Não consulta o banco de 20 MB nesta rota rápida.
 */
$connections = [];

if (is_readable($statusCache)) {
    $cached = json_decode(
        (string) file_get_contents($statusCache),
        true
    );

    if (
        is_array($cached)
        && isset($cached['connections'])
        && is_array($cached['connections'])
    ) {
        $connections = $cached['connections'];
    }
}

$handle = fopen($logFile, 'rb');

if ($handle === false) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'error' => 'log_open_failed',
    ]);

    exit;
}

$size = filesize($logFile);

if ($size === false) {
    $size = 0;
}

/*
 * 128 KB são suficientes para reconstruir as transmissões recentes
 * sem processar todo o histórico.
 */
$readSize = min($size, 131072);
$start = max(0, $size - $readSize);

if ($start > 0) {
    fseek($handle, $start);
    fgets($handle);
}

$raw = stream_get_contents($handle);
fclose($handle);

if ($raw === false) {
    $raw = '';
}

$active = [];
$recentProtocols = [];
$lines = preg_split('/\R/', $raw) ?: [];

foreach ($lines as $line) {
    if (
        preg_match(
            '/New client\s+([A-Z0-9]+)(?:\s+([A-Z0-9]+))?.*?' .
            'protocol\s+([A-Za-z0-9+_-]+)(?:.*?module\s+([A-Z]))?/i',
            $line,
            $match
        )
    ) {
        $call = strtoupper(trim($match[1]));
        $suffix = strtoupper(trim($match[2] ?? ''));
        $protocol = strtoupper(trim($match[3]));
        $module = strtoupper(trim($match[4] ?? '?'));

        $recentProtocols[
            $call . '|' . $suffix . '|' . $module
        ] = $protocol;

        $recentProtocols[
            $call . '||' . $module
        ] = $protocol;
    }

    if (
        preg_match(
            '/Opening stream on module\s+([A-Z])\s+' .
            'for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?\s+' .
            'with sid\s+(\d+)/i',
            $line,
            $match
        )
    ) {
        $module = strtoupper($match[1]);
        $call = strtoupper(trim($match[2]));
        $suffix = strtoupper(trim($match[3] ?? ''));
        $streamId = (int) $match[4];

        $timestamp = 0;

        if (
            preg_match(
                '/^(\d{1,2})\s+([A-Za-z]{3}),\s+' .
                '(\d{2}):(\d{2}):(\d{2}):/',
                $line,
                $dateMatch
            )
        ) {
            $monthNames = [
                'Jan' => 1,
                'Feb' => 2,
                'Mar' => 3,
                'Apr' => 4,
                'May' => 5,
                'Jun' => 6,
                'Jul' => 7,
                'Aug' => 8,
                'Sep' => 9,
                'Oct' => 10,
                'Nov' => 11,
                'Dec' => 12,
            ];

            $month = $monthNames[$dateMatch[2]] ?? 0;

            if ($month > 0) {
                $timestamp = mktime(
                    (int) $dateMatch[3],
                    (int) $dateMatch[4],
                    (int) $dateMatch[5],
                    $month,
                    (int) $dateMatch[1],
                    (int) date('Y')
                );
            }
        }

        $connection = null;

        foreach ($connections as $candidate) {
            if (
                strtoupper(
                    trim((string) ($candidate['callsign'] ?? ''))
                ) !== $call
            ) {
                continue;
            }

            if (
                strtoupper(
                    trim((string) ($candidate['module'] ?? ''))
                ) !== $module
            ) {
                continue;
            }

            $candidateSuffix = strtoupper(
                trim((string) ($candidate['suffix'] ?? ''))
            );

            if (
                $suffix !== ''
                && $candidateSuffix !== ''
                && $candidateSuffix !== $suffix
            ) {
                continue;
            }

            $connection = $candidate;
            break;
        }

        $protocol =
            $connection['protocol']
            ?? $recentProtocols[
                $call . '|' . $suffix . '|' . $module
            ]
            ?? $recentProtocols[
                $call . '||' . $module
            ]
            ?? 'Não identificado';

        /*
         * O módulo C é compartilhado por C4FM/YSF e DMR.
         * Como o mesmo indicativo e IP podem estar conectados pelos
         * dois protocolos, não tentamos adivinhar qual deles originou
         * o stream. A identificação pública segura é C4FM/DMR.
         */
        if ($module === 'C') {
            $protocol = 'C4FM/DMR';
        }

        $name = trim(
            (string) ($connection['name'] ?? '')
        );

        if ($name === '') {
            $name = $call;
        }

        $location = trim(
            (string) ($connection['location'] ?? '')
        );

        if ($location === '') {
            $location = 'Localização não informada';
        }

        $country = $connection['country'] ?? [
            'name' => 'País não informado',
            'flag' => '🌐',
        ];

        $gateway = trim(
            (string) (
                $connection['via']
                ?? $connection['peer']
                ?? ''
            )
        );

        /*
         * O indicativo informado no Opening stream fica disponível
         * imediatamente, sem aguardar a atualização da API geral.
         */
        if ($gateway === '') {
            $gateway = trim(
                $call . ($suffix !== '' ? ' ' . $suffix : '')
            );
        }

        if ($gateway === '') {
            $gateway = 'Gateway não identificado';
        }

        $active[$module] = [
            'key' => $module . ':' . $streamId,
            'module' => $module,
            'stream_id' => $streamId,
            'callsign' => $call,
            'suffix' => $suffix,
            'name' => $name,
            'location' => $location,
            'country' => $country,
            'protocol' => $protocol,
            'started_at' => $timestamp ?: time(),
            'qrz' =>
                $connection['qrz']
                ?? 'https://www.qrz.com/db/' .
                    rawurlencode($call),
            'gateway' => $gateway,
            'via' => $connection['via'] ?? '',
            'peer' => $connection['peer'] ?? '',
            'ip' => $connection['ip'] ?? '',
            'state' => 'transmitting',
        ];
    }

    if (
        preg_match(
            '/Closing stream of module\s+([A-Z])/i',
            $line,
            $match
        )
    ) {
        $module = strtoupper($match[1]);
        unset($active[$module]);
    }
}

$now = time();

foreach ($active as $module => $transmission) {
    if (
        empty($transmission['started_at'])
        || (
            $now - (int) $transmission['started_at']
        ) > 600
    ) {
        unset($active[$module]);
    }
}

echo json_encode(
    [
        'ok' => true,
        'generated_at' => $now,
        'active_count' => count($active),

        /*
         * Força objeto JSON vazio {} em vez de lista vazia [].
         */
        'active' => (object) $active,
    ],
    JSON_UNESCAPED_UNICODE
    | JSON_UNESCAPED_SLASHES
    | JSON_INVALID_UTF8_SUBSTITUTE
);
