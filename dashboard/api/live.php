<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$logFile = '/var/log/xlx.log';
$statusCache = '/var/cache/xlx-dashboard/status.json';

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
$statusSnapshot = [];

if (is_readable($statusCache)) {
    $cached = json_decode(
        (string) file_get_contents($statusCache),
        true
    );

    if (is_array($cached)) {
        $statusSnapshot = $cached;

        if (
            isset($cached['connections'])
            && is_array($cached['connections'])
        ) {
            $connections = $cached['connections'];
        }
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

/* XLXMODERN_LOG260_COMPAT_V2: parser compatível XLXD 2.5/2.6 */
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
            'for\s+(?:client\s+)?([A-Z0-9\/\-]+)' .
            '(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?' .
            '(?:\s*\/\s*[A-Z0-9+_-]+)?' .
            '(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+' .
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


/* XLXMODERN_LIVE_OPERATOR_BRIDGE_V12 START */

/*
 * O stream_id é usado quando existe nos dois lados.
 *
 * Se o status.json não possuir stream_id, o match
 * seguro passa a ser:
 *
 *   módulo
 * + gateway/network_callsign
 * + started_at ±3 segundos
 * + identity_source xlxd-station-*
 *
 * Se os DOIS lados possuírem stream_id e eles forem
 * diferentes, a identidade é rejeitada.
 */

$xlxmodernBaseCallV12 = static function (
    $value
): string {
    $value = strtoupper(
        trim((string)$value)
    );

    if ($value === '') {
        return '';
    }

    $parts = preg_split(
        '/\s+/',
        $value
    ) ?: [];

    return trim(
        (string)(
            $parts[0]
            ?? ''
        )
    );
};

$xlxmodernGatewayPartsV12 = static function (
    $value
) use (
    $xlxmodernBaseCallV12
): array {
    $raw = strtoupper(
        trim((string)$value)
    );

    if (
        $raw === ''
        || $raw === 'NÃO IDENTIFICADO'
        || $raw === 'GATEWAY NÃO IDENTIFICADO'
    ) {
        return ['', ''];
    }

    $parts = preg_split(
        '/\s+/',
        $raw
    ) ?: [];

    $call = $xlxmodernBaseCallV12(
        $raw
    );

    $suffix = '';

    if (count($parts) >= 2) {
        $candidate = strtoupper(
            trim(
                (string)$parts[1]
            )
        );

        if (
            preg_match(
                '/^[A-Z0-9]$/',
                $candidate
            )
        ) {
            $suffix = $candidate;
        }
    }

    return [
        $call,
        $suffix
    ];
};

foreach (
    $active as $module => $transmission
) {
    /*
     * Primeiro normaliza o gateway bruto:
     *
     * PY4RWC B -> PY4RWC + suffix B
     * PU2PNY B -> PU2PNY + suffix B
     */

    [
        $liveGatewayBase,
        $liveGatewaySuffix
    ] = $xlxmodernGatewayPartsV12(
        $transmission['gateway']
        ?? ''
    );

    $liveClientBase =
        $xlxmodernBaseCallV12(
            $transmission['callsign']
            ?? ''
        );

    if ($liveGatewayBase !== '') {
        $active[$module]['gateway'] =
            $liveGatewayBase;

        if (
            trim(
                (string)(
                    $active[$module][
                        'gateway_suffix'
                    ]
                    ?? ''
                )
            ) === ''
            && $liveGatewaySuffix !== ''
        ) {
            $active[$module][
                'gateway_suffix'
            ] = $liveGatewaySuffix;
        }
    }

    if (
        $liveClientBase !== ''
        && trim(
            (string)(
                $active[$module][
                    'network_callsign'
                ]
                ?? ''
            )
        ) === ''
    ) {
        $active[$module][
            'network_callsign'
        ] = $liveClientBase;
    }

    /*
     * Identidade STATION disponível no cache?
     */

    $cachedTransmission =
        $statusSnapshot['modules']
            [$module]['transmission']
        ?? null;

    if (!is_array($cachedTransmission)) {
        continue;
    }

    $source = trim(
        (string)(
            $cachedTransmission[
                'identity_source'
            ]
            ?? ''
        )
    );

    if (
        $source === ''
        || strpos(
            $source,
            'xlxd-station'
        ) !== 0
    ) {
        continue;
    }

    /*
     * Mesmo módulo.
     */

    $liveModule = strtoupper(
        trim(
            (string)(
                $transmission['module']
                ?? $module
            )
        )
    );

    $cacheModule = strtoupper(
        trim(
            (string)(
                $cachedTransmission['module']
                ?? $module
            )
        )
    );

    if (
        $liveModule === ''
        || $liveModule !== $cacheModule
    ) {
        continue;
    }

    /*
     * Gateway/repetidora precisa bater.
     *
     * O client cru do live normalmente é:
     *   PY4RWC
     *
     * E no STATION:
     *   gateway/network_callsign = PY4RWC
     */

    $cacheGateway =
        $xlxmodernBaseCallV12(
            $cachedTransmission[
                'gateway'
            ]
            ?? ''
        );

    $cacheNetwork =
        $xlxmodernBaseCallV12(
            $cachedTransmission[
                'network_callsign'
            ]
            ?? ''
        );

    $gatewayMatch =
        $liveClientBase !== ''
        && (
            (
                $cacheGateway !== ''
                && $liveClientBase ===
                   $cacheGateway
            )
            ||
            (
                $cacheNetwork !== ''
                && $liveClientBase ===
                   $cacheNetwork
            )
            ||
            (
                $liveGatewayBase !== ''
                && $cacheGateway !== ''
                && $liveGatewayBase ===
                   $cacheGateway
            )
        );

    if (!$gatewayMatch) {
        continue;
    }

    /*
     * Horário é obrigatório.
     */

    $liveStart = (int)(
        $transmission['started_at']
        ?? 0
    );

    $cacheStart = (int)(
        $cachedTransmission['started_at']
        ?? 0
    );

    if (
        $liveStart <= 0
        || $cacheStart <= 0
        || abs(
            $liveStart
            - $cacheStart
        ) > 3
    ) {
        continue;
    }

    /*
     * Stream ID:
     *
     * - se existe nos dois lados: TEM que ser igual;
     * - se está ausente em um lado: gateway+hora
     *   continua sendo suficiente.
     */

    $liveStream = (int)(
        $transmission['stream_id']
        ?? 0
    );

    $cacheStream = (int)(
        $cachedTransmission['stream_id']
        ?? 0
    );

    if (
        $liveStream > 0
        && $cacheStream > 0
        && $liveStream !== $cacheStream
    ) {
        continue;
    }

    /*
     * Mesma transmissão comprovada.
     */

    foreach ([
        'callsign',
        'suffix',
        'name',
        'location',
        'country',
        'protocol',
        'qrz',
        'gateway',
        'gateway_suffix',
        'network_callsign',
        'operator_callsign',
        'operator_identity',
        'identity_source',
        'origin_match',
    ] as $field) {
        if (
            array_key_exists(
                $field,
                $cachedTransmission
            )
        ) {
            $active[$module][$field] =
                $cachedTransmission[$field];
        }
    }

    /*
     * Normaliza novamente após copiar.
     */

    [
        $finalGateway,
        $finalSuffix
    ] = $xlxmodernGatewayPartsV12(
        $active[$module]['gateway']
        ?? ''
    );

    if ($finalGateway !== '') {
        $active[$module]['gateway'] =
            $finalGateway;
    }

    if (
        trim(
            (string)(
                $active[$module][
                    'gateway_suffix'
                ]
                ?? ''
            )
        ) === ''
        && $finalSuffix !== ''
    ) {
        $active[$module][
            'gateway_suffix'
        ] = $finalSuffix;
    }

    /*
     * Campo diagnóstico.
     * O frontend pode ignorar.
     */

    $active[$module][
        'identity_match'
    ] = (
        $liveStream > 0
        && $cacheStream > 0
    )
        ? 'station-stream-time-gateway'
        : 'station-time-gateway';
}

/* XLXMODERN_LIVE_OPERATOR_BRIDGE_V12 END */

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
