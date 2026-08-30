<?php
declare(strict_types=1);

/**
 * Build-time translator for XLX Modern Dashboard.
 *
 * Usage:
 *   php i18n/build.php /var/www/html/xlx-dashboard en
 *
 * The installer copies a clean dashboard first and then runs this builder.
 * Translation is restricted to deployable dashboard source files. The i18n
 * engine itself, runtime configuration, databases and XLXD data are excluded.
 */

require_once __DIR__ . '/bootstrap.php';

$target = $argv[1] ?? '';
$requestedLocale = $argv[2] ?? 'pt-BR';
$locale = xlx_normalize_locale($requestedLocale);

if ($target === '' || !is_dir($target)) {
    fwrite(STDERR, "ERROR: dashboard directory not found: {$target}\n");
    exit(2);
}

$sourceMessages = xlx_load_messages('pt-BR');
$targetMessages = xlx_load_messages($locale);
$catalog = xlx_locale_catalog();

/*
 * Older catalogs used "{{REFLECTOR_NAME}} Brasil" as one branding token.
 * The public installer is now country-neutral. Normalize that legacy token
 * while translating so existing catalogs remain compatible and no new
 * installation inherits a fixed country name.
 */
$genericMessage = static function (string $text): string {
    return str_replace('{{REFLECTOR_NAME}} Brasil', '{{REFLECTOR_NAME}}', $text);
};

$allowedExtensions = ['php', 'js', 'css', 'html', 'htm', 'json', 'webmanifest'];
$excludedParts = [
    DIRECTORY_SEPARATOR . 'i18n' . DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'site.php',
];

/*
 * Route slugs are application identifiers, not user-facing copy. Some
 * translated source strings (for example "conectados") can be identical to a
 * slug. Protect quoted route identifiers before textual translation and
 * restore them afterwards so locale builds never change navigation semantics.
 */
$routeSlugs = [
    'ao-vivo',
    'modulos',
    'conectados',
    'ranking',
    'refletores',
    'noticias',
    'suporte',
    'certificado',
    'digital-lab',
];
$routeProtection = [];
foreach ($routeSlugs as $routeSlug) {
    $sentinel = '__XLX_ROUTE_' . strtoupper(str_replace('-', '_', $routeSlug)) . '__';
    $routeProtection["'{$routeSlug}'"] = "'{$sentinel}'";
    $routeProtection['"' . $routeSlug . '"'] = '"' . $sentinel . '"';
}
$routeRestore = array_flip($routeProtection);

$filesChanged = 0;
$replacementCount = 0;
$fileReport = [];
$htmlLocale = (string)($catalog[$locale]['html'] ?? $locale);
$ogLocale = (string)($catalog[$locale]['og'] ?? 'pt_BR');

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($target, FilesystemIterator::SKIP_DOTS)
);

foreach ($iterator as $fileInfo) {
    if (!$fileInfo->isFile()) {
        continue;
    }

    $path = $fileInfo->getPathname();
    $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    if (!in_array($extension, $allowedExtensions, true)) {
        continue;
    }

    foreach ($excludedParts as $part) {
        if (str_contains($path, $part)) {
            continue 2;
        }
    }

    $contents = file_get_contents($path);
    if ($contents === false) {
        fwrite(STDERR, "ERROR: cannot read {$path}\n");
        exit(3);
    }

    $before = $contents;
    $countForFile = 0;

    $contents = strtr($contents, $routeProtection);

    if ($locale !== 'pt-BR') {
        foreach ($sourceMessages as $key => $sourceText) {
            if (!array_key_exists($key, $targetMessages)) {
                continue;
            }

            $sourceText = $genericMessage((string)$sourceText);
            $translatedText = $genericMessage((string)$targetMessages[$key]);
            if ($sourceText === '' || $sourceText === $translatedText || strlen($sourceText) < 4) {
                continue;
            }

            $localCount = 0;
            $contents = str_replace($sourceText, $translatedText, $contents, $localCount);
            $countForFile += $localCount;
        }
    }

    $langCount = 0;
    $ogCount = 0;
    $dateLocaleCount = 0;
    $contents = str_replace('lang="pt-BR"', 'lang="' . $htmlLocale . '"', $contents, $langCount);
    $contents = str_replace('content="pt_BR"', 'content="' . $ogLocale . '"', $contents, $ogCount);

    if ($locale !== 'pt-BR' && $extension === 'js') {
        $contents = str_replace("toLocaleTimeString('pt-BR'", "toLocaleTimeString('{$htmlLocale}'", $contents, $dateLocaleCount);
        $contents = str_replace('toLocaleTimeString("pt-BR"', 'toLocaleTimeString("' . $htmlLocale . '"', $contents, $dateLocaleCount2);
        $dateLocaleCount += $dateLocaleCount2;
        $contents = str_replace("toLocaleString('pt-BR'", "toLocaleString('{$htmlLocale}'", $contents, $dateLocaleCount3);
        $contents = str_replace('toLocaleString("pt-BR"', 'toLocaleString("' . $htmlLocale . '"', $contents, $dateLocaleCount4);
        $dateLocaleCount += $dateLocaleCount3 + $dateLocaleCount4;
    }

    $contents = strtr($contents, $routeRestore);

    $countForFile += $langCount + $ogCount + $dateLocaleCount;

    if ($contents !== $before) {
        if (file_put_contents($path, $contents) === false) {
            fwrite(STDERR, "ERROR: cannot write {$path}\n");
            exit(4);
        }
        $filesChanged++;
        $replacementCount += $countForFile;
        $fileReport[str_replace(rtrim($target, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR, '', $path)] = $countForFile;
    }
}

$configFile = rtrim($target, DIRECTORY_SEPARATOR) . '/config/site.php';
if (is_file($configFile)) {
    $config = require $configFile;
    if (!is_array($config)) {
        fwrite(STDERR, "ERROR: invalid dashboard config: {$configFile}\n");
        exit(5);
    }

    $config['locale'] = [
        'default' => $locale,
        'html' => $htmlLocale,
        'og' => $ogLocale,
        'name' => (string)($catalog[$locale]['name'] ?? $locale),
    ];

    $export = "<?php\ndeclare(strict_types=1);\nreturn " . var_export($config, true) . ";\n";
    if (file_put_contents($configFile, $export) === false) {
        fwrite(STDERR, "ERROR: cannot update {$configFile}\n");
        exit(6);
    }
}

$report = [
    'locale' => $locale,
    'language' => xlx_locale_name($locale),
    'files_changed' => $filesChanged,
    'replacements' => $replacementCount,
    'files' => $fileReport,
    'generated_at_utc' => gmdate('c'),
];

$reportPath = rtrim($target, DIRECTORY_SEPARATOR) . '/config/i18n-build-report.json';
file_put_contents(
    $reportPath,
    json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n"
);

printf(
    "Dashboard language: %s (%s) | files changed: %d | replacements: %d\n",
    xlx_locale_name($locale),
    $locale,
    $filesChanged,
    $replacementCount
);
