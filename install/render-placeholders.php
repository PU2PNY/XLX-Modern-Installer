<?php
declare(strict_types=1);

/*
 * XLX Modern Dashboard
 * Renderizador de parâmetros definidos durante a instalação.
 *
 * Uso:
 * php render-placeholders.php /var/www/html/xlx-dashboard
 */

$target = $argv[1] ?? '';

if ($target === '' || !is_dir($target)) {
    fwrite(STDERR, "ERROR: dashboard target not found: {$target}\n");
    exit(2);
}

$configFile = rtrim($target, DIRECTORY_SEPARATOR) . '/config/site.php';

if (!is_file($configFile)) {
    fwrite(STDERR, "ERROR: site configuration not found: {$configFile}\n");
    exit(3);
}

$config = require $configFile;

if (!is_array($config)) {
    fwrite(STDERR, "ERROR: invalid site configuration.\n");
    exit(4);
}

$reflector = $config['reflector'] ?? [];
$radio = $config['radio'] ?? [];

$required = [
    'reflector.name' => $reflector['name'] ?? '',
    'reflector.title' => $reflector['title'] ?? '',
    'reflector.description' => $reflector['description'] ?? '',
    'reflector.sysop_callsign' => $reflector['sysop_callsign'] ?? '',
    'reflector.location' => $reflector['location'] ?? '',
    'reflector.country' => $reflector['country'] ?? '',
    'reflector.domain' => $reflector['domain'] ?? '',
    'reflector.contact_email' => $reflector['contact_email'] ?? '',
    'radio.reflector_number' => $radio['reflector_number'] ?? '',
    'radio.reflector_short_number' => $radio['reflector_short_number'] ?? '',
    'radio.ysf_id' => $radio['ysf_id'] ?? '',
    'radio.dmr_tg' => $radio['dmr_tg'] ?? '',
];

foreach ($required as $name => $value) {
    if (trim((string)$value) === '') {
        fwrite(STDERR, "ERROR: required configuration missing: {$name}\n");
        exit(5);
    }
}

$domain = trim((string)$reflector['domain']);
$domain = preg_replace('#^https?://#i', '', $domain);
$domain = rtrim((string)$domain, '/');

$replacements = [
    '{{REFLECTOR_NAME}}' =>
        (string)$reflector['name'],

    '{{REFLECTOR_TITLE}}' =>
        (string)$reflector['title'],

    '{{REFLECTOR_DESCRIPTION}}' =>
        (string)$reflector['description'],

    '{{SYSOP_CALLSIGN}}' =>
        (string)$reflector['sysop_callsign'],

    '{{LOCATION}}' =>
        (string)$reflector['location'],

    '{{COUNTRY}}' =>
        (string)$reflector['country'],

    '{{DOMAIN}}' =>
        $domain,

    '{{REFLECTOR_DOMAIN}}' =>
        $domain,

    '{{CONTACT_EMAIL}}' =>
        (string)$reflector['contact_email'],

    '{{REFLECTOR_NUMBER}}' =>
        (string)$radio['reflector_number'],

    '{{REFLECTOR_SHORT_NUMBER}}' =>
        (string)$radio['reflector_short_number'],

    '{{YSF_ID}}' =>
        (string)$radio['ysf_id'],

    '{{DMR_TG}}' =>
        (string)$radio['dmr_tg'],
];

$allowedExtensions = [
    'php',
    'js',
    'css',
    'txt',
    'xml',
    'json',
    'webmanifest',
    'html',
    'htm',
];

$excludedFragments = [
    DIRECTORY_SEPARATOR . 'install' . DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR . 'i18n' . DIRECTORY_SEPARATOR . 'locales' . DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'site.php',
];

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $target,
        FilesystemIterator::SKIP_DOTS
    )
);

$filesChanged = 0;
$replacementCount = 0;

foreach ($iterator as $fileInfo) {
    if (!$fileInfo->isFile()) {
        continue;
    }

    $path = $fileInfo->getPathname();

    $skip = false;

    foreach ($excludedFragments as $fragment) {
        if (str_contains($path, $fragment)) {
            $skip = true;
            break;
        }
    }

    if ($skip) {
        continue;
    }

    $extension = strtolower(
        pathinfo($path, PATHINFO_EXTENSION)
    );

    if (!in_array($extension, $allowedExtensions, true)) {
        continue;
    }

    $contents = file_get_contents($path);

    if ($contents === false) {
        fwrite(STDERR, "ERROR: cannot read {$path}\n");
        exit(6);
    }

    $before = $contents;
    $fileReplacements = 0;

    foreach ($replacements as $token => $value) {
        $localCount = 0;

        $contents = str_replace(
            $token,
            $value,
            $contents,
            $localCount
        );

        $fileReplacements += $localCount;
    }

    if ($contents !== $before) {
        if (file_put_contents($path, $contents) === false) {
            fwrite(STDERR, "ERROR: cannot write {$path}\n");
            exit(7);
        }

        $filesChanged++;
        $replacementCount += $fileReplacements;
    }
}

/*
 * Verificação final:
 * nenhum token de instalação pode chegar ao painel publicado.
 */
$unresolved = [];

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $target,
        FilesystemIterator::SKIP_DOTS
    )
);

foreach ($iterator as $fileInfo) {
    if (!$fileInfo->isFile()) {
        continue;
    }

    $path = $fileInfo->getPathname();

    if (
        str_contains(
            $path,
            DIRECTORY_SEPARATOR . 'install' . DIRECTORY_SEPARATOR
        ) ||
        str_contains(
            $path,
            DIRECTORY_SEPARATOR . 'i18n' . DIRECTORY_SEPARATOR . 'locales' . DIRECTORY_SEPARATOR
        )
    ) {
        continue;
    }

    $extension = strtolower(
        pathinfo($path, PATHINFO_EXTENSION)
    );

    if (!in_array($extension, $allowedExtensions, true)) {
        continue;
    }

    $contents = file_get_contents($path);

    if (
        $contents !== false &&
        preg_match_all(
            '/\{\{[A-Z0-9_]+\}\}/',
            $contents,
            $matches
        )
    ) {
        foreach ($matches[0] as $token) {
            $unresolved[$token][] = $path;
        }
    }
}

if ($unresolved !== []) {
    fwrite(
        STDERR,
        "ERROR: unresolved dashboard placeholders:\n"
    );

    foreach ($unresolved as $token => $files) {
        fwrite(
            STDERR,
            ' - ' . $token . ': ' .
            implode(', ', array_unique($files)) .
            PHP_EOL
        );
    }

    exit(8);
}

printf(
    "Placeholder rendering: OK | files changed: %d | replacements: %d\n",
    $filesChanged,
    $replacementCount
);
