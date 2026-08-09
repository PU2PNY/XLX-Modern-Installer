<?php
declare(strict_types=1);

function cert_site_config(): array
{
    static $config;
    if (is_array($config)) return $config;

    $path = __DIR__ . '/config/site.php';
    if (!is_file($path)) {
        throw new RuntimeException('Configuração do refletor não encontrada.');
    }
    $loaded = require $path;
    if (!is_array($loaded)) {
        throw new RuntimeException('Configuração do refletor inválida.');
    }
    return $config = $loaded;
}

function cert_reflector(): array
{
    $config = cert_site_config();
    $reflector = (array)($config['reflector'] ?? []);
    return [
        'name' => trim((string)($reflector['name'] ?? 'XLX')),
        'title' => trim((string)($reflector['title'] ?? $reflector['name'] ?? 'XLX')),
        'domain' => trim((string)($reflector['domain'] ?? '')),
        'country' => trim((string)($reflector['country'] ?? '')),
        'sysop_callsign' => trim((string)($reflector['sysop_callsign'] ?? '')),
    ];
}

function cert_timezone(): DateTimeZone
{
    $config = cert_site_config();
    $name = trim((string)($config['timezone'] ?? 'UTC'));
    try {
        return new DateTimeZone($name !== '' ? $name : 'UTC');
    } catch (Throwable $exception) {
        return new DateTimeZone('UTC');
    }
}

function cert_is_brazil(string $country): bool
{
    $value = strtolower(trim($country));
    $ascii = @iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $value);
    $value = strtolower($ascii !== false ? $ascii : $value);
    return in_array($value, ['br', 'brasil', 'brazil'], true);
}

function cert_campaign(
    string $id,
    string $title,
    string $subtitle,
    string $theme,
    DateTimeImmutable $start,
    DateTimeImmutable $end
): array {
    return [
        'id' => $id,
        'title' => $title,
        'subtitle' => $subtitle,
        'theme' => $theme,
        'start_ts' => $start->getTimestamp(),
        'end_ts' => $end->getTimestamp(),
        'period_label' => $start->format('d/m/Y') === $end->format('d/m/Y')
            ? $start->format('d/m/Y')
            : $start->format('d/m/Y') . ' – ' . $end->format('d/m/Y'),
    ];
}

function cert_nth_weekday(int $year, int $month, int $weekday, int $nth, DateTimeZone $tz): DateTimeImmutable
{
    $date = new DateTimeImmutable(sprintf('%04d-%02d-01 00:00:00', $year, $month), $tz);
    while ((int)$date->format('N') !== $weekday) {
        $date = $date->modify('+1 day');
    }
    return $date->modify('+' . max(0, $nth - 1) . ' weeks');
}

function cert_current_campaign(?DateTimeImmutable $now = null): array
{
    $site = cert_site_config();
    $reflector = cert_reflector();
    $tz = cert_timezone();
    $now ??= new DateTimeImmutable('now', $tz);
    $now = $now->setTimezone($tz);
    $year = (int)$now->format('Y');
    $title = $reflector['title'];

    $specials = [];

    $hamDay = new DateTimeImmutable("{$year}-04-18 00:00:00", $tz);
    $specials[] = cert_campaign(
        "world-amateur-radio-day-{$year}",
        "Dia Mundial do Radioamador {$year}",
        "Participação registrada em {$title}",
        'radioamador',
        $hamDay,
        $hamDay->setTime(23, 59, 59)
    );

    $certConfig = (array)($site['certificates'] ?? []);
    $anniversary = trim((string)($certConfig['anniversary'] ?? ''));
    if (preg_match('/^(\d{2})-(\d{2})$/', $anniversary, $match)) {
        $month = (int)$match[1];
        $day = (int)$match[2];
        if (checkdate($month, $day, $year)) {
            $official = new DateTimeImmutable(sprintf('%04d-%02d-%02d 00:00:00', $year, $month, $day), $tz);
            $specials[] = cert_campaign(
                'reflector-anniversary-' . strtolower($reflector['name']) . '-' . $year,
                "Semana de Aniversário {$title} {$year}",
                'Data oficial: ' . $official->format('d/m'),
                'aniversario',
                $official->modify('-2 days'),
                $official->modify('+2 days')->setTime(23, 59, 59)
            );
        }
    }

    if (cert_is_brazil($reflector['country'])) {
        $mother = cert_nth_weekday($year, 5, 7, 2, $tz);
        $father = cert_nth_weekday($year, 8, 7, 2, $tz);
        $independence = new DateTimeImmutable("{$year}-09-07 00:00:00", $tz);
        $brRadio = new DateTimeImmutable("{$year}-11-05 00:00:00", $tz);

        $specials[] = cert_campaign("dia-das-maes-{$year}", "Dia das Mães {$year}", "Edição especial de {$title}", 'familia', $mother, $mother->setTime(23, 59, 59));
        $specials[] = cert_campaign("dia-dos-pais-{$year}", "Dia dos Pais {$year}", "Edição especial de {$title}", 'familia', $father, $father->setTime(23, 59, 59));
        $specials[] = cert_campaign("independencia-brasil-{$year}", "Independência do Brasil {$year}", "Participação registrada em {$title}", 'brasil', $independence, $independence->setTime(23, 59, 59));
        $specials[] = cert_campaign("dia-radioamador-brasileiro-{$year}", "Dia do Radioamador Brasileiro {$year}", "Participação registrada em {$title}", 'radioamador', $brRadio, $brRadio->setTime(23, 59, 59));
    }

    $timestamp = $now->getTimestamp();
    foreach ($specials as $campaign) {
        if ($timestamp >= $campaign['start_ts'] && $timestamp <= $campaign['end_ts']) {
            return $campaign;
        }
    }

    $start = $now->setTime(0, 0, 0);
    $end = $now->setTime(23, 59, 59);
    return cert_campaign(
        'participacao-' . $now->format('Y-m-d'),
        'Certificado de Participação',
        "Atividade registrada em {$title}",
        'participacao',
        $start,
        $end
    );
}
