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

$genericMessage = static function (string $text): string {
    return str_replace('{{REFLECTOR_NAME}} Brasil', '{{REFLECTOR_NAME}}', $text);
};

$allowedExtensions = ['php', 'js', 'html', 'htm'];
$excludedParts = [
    DIRECTORY_SEPARATOR . 'i18n' . DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'site.php',
];

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
$routeRestore = [];
foreach ($routeSlugs as $routeIndex => $routeSlug) {
    $sentinel = '__XLX_ROUTE_' . $routeIndex . '__';
    $routeProtection["'{$routeSlug}'"] = "'{$sentinel}'";
    $routeProtection['"' . $routeSlug . '"'] = '"' . $sentinel . '"';
    $routeRestore[$sentinel] = $routeSlug;
}

$protectTechnical = static function (string $text, array &$restore): string {
    $n = 0;
    $protect = static function (string $value) use (&$restore, &$n): string {
        $token = '__XLX_TECH_' . $n++ . '__';
        $restore[$token] = $value;
        return $token;
    };

    $text = preg_replace_callback(
        "~\\b(?:class|id|name|for|type|value|href|src|action|data-[a-z0-9_-]+)=(\"[^\"]*\"|'[^']*')~iu",
        static function (array $m) use ($protect): string {
            $eq = strpos($m[0], '=');
            return substr($m[0], 0, $eq + 1) . $protect(substr($m[0], $eq + 1));
        },
        $text
    ) ?? $text;

    $text = preg_replace_callback(
        "~(?:https?://[^\\s\"'<>]+|(?:assets|api|config|flags|install)/[A-Za-z0-9_./?=&%#{}-]+|[A-Za-z0-9_.-]+\\.(?:css|js|php|png|jpe?g|svg|webp|ico|json|sqlite|db|service|timer|socket|sh)(?:\\?[A-Za-z0-9_=&.%#{}-]+)?)~u",
        static fn(array $m): string => $protect($m[0]),
        $text
    ) ?? $text;

    $text = preg_replace_callback(
        '~\\b[A-Za-z_$][A-Za-z0-9_$]*(?=\\s*\\()~u',
        static fn(array $m): string => $protect($m[0]),
        $text
    ) ?? $text;

    return $text;
};

/*
 * Raw source replacement is unsafe inside code string literals when a target
 * translation contains the delimiter. Protect exact PHP/JavaScript literals
 * before the general translation pass and restore them with delimiter-aware
 * escaping afterwards. This preserves the visible translation while keeping
 * generated source syntactically valid in every locale.
 */
$protectCodeTranslatedLiterals = static function (
    string $text,
    array $replacements,
    string $extension,
    array &$restore
): string {
    if (!in_array($extension, ['php', 'js'], true)) {
        return $text;
    }

    $protect = [];
    $n = 0;
    foreach ($replacements as $sourceText => $translatedText) {
        $pairs = [];

        $singleSource = "'" . addcslashes($sourceText, "\\'\n\r\t") . "'";
        $singleTarget = "'" . addcslashes($translatedText, "\\'\n\r\t") . "'";
        $pairs[] = [$singleSource, $singleTarget];

        $doubleChars = $extension === 'php' ? "\\\"$\n\r\t" : "\\\"\n\r\t";
        $doubleSource = '"' . addcslashes($sourceText, $doubleChars) . '"';
        $doubleTarget = '"' . addcslashes($translatedText, $doubleChars) . '"';
        $pairs[] = [$doubleSource, $doubleTarget];

        if ($extension === 'js') {
            // Escape backticks, backslashes and '$' so translated text cannot
            // accidentally create a ${...} interpolation in a template literal.
            $templateChars = "\\`$\n\r\t";
            $templateSource = '`' . addcslashes($sourceText, $templateChars) . '`';
            $templateTarget = '`' . addcslashes($translatedText, $templateChars) . '`';
            $pairs[] = [$templateSource, $templateTarget];
        }

        foreach ($pairs as [$sourceLiteral, $targetLiteral]) {
            if (!str_contains($text, $sourceLiteral)) {
                continue;
            }
            $token = '__XLX_I18N_LITERAL_' . $n++ . '__';
            $protect[$sourceLiteral] = $token;
            $restore[$token] = $targetLiteral;
        }
    }

    if ($protect === []) {
        return $text;
    }
    uksort($protect, static fn(string $a, string $b): int => strlen($b) <=> strlen($a));
    return strtr($text, $protect);
};

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

    $technicalRestore = [];
    $contents = $protectTechnical($contents, $technicalRestore);

    if ($locale !== 'pt-BR') {
        $replacements = [];
        foreach ($sourceMessages as $key => $sourceText) {
            if (!array_key_exists($key, $targetMessages)) {
                continue;
            }
            $sourceText = $genericMessage((string)$sourceText);
            $translatedText = $genericMessage((string)$targetMessages[$key]);
            if ($sourceText === '' || $sourceText === $translatedText || strlen($sourceText) < 4) {
                continue;
            }
            $replacements[$sourceText] = $translatedText;
        }
        uksort($replacements, static fn(string $a, string $b): int => strlen($b) <=> strlen($a));
        $beforeTranslation = $contents;

        $literalRestore = [];
        $contents = $protectCodeTranslatedLiterals($contents, $replacements, $extension, $literalRestore);
        $contents = strtr($contents, $replacements);
        if ($literalRestore) {
            $contents = strtr($contents, $literalRestore);
        }
        if (preg_match('/__XLX_I18N_LITERAL_[A-Z0-9_]+__/', $contents, $literalLeak)) {
            fwrite(STDERR, "ERROR: unresolved protected code literal {$literalLeak[0]} in {$path}\n");
            exit(8);
        }

        if ($contents !== $beforeTranslation) {
            $countForFile++;
        }
    }

    if ($technicalRestore) {
        $contents = strtr($contents, $technicalRestore);
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
    if (preg_match('/__XLX_ROUTE_[A-Z0-9_]+__/', $contents, $routeLeak)) {
        fwrite(STDERR, "ERROR: unresolved protected route {$routeLeak[0]} in {$path}\n");
        exit(7);
    }

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
