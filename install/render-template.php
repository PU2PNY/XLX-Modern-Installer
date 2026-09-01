<?php
declare(strict_types=1);

/**
 * Render installation placeholders in a copied XLX dashboard.
 *
 * Usage:
 *   php render-template.php /var/www/html/xlx-dashboard
 */

$target = $argv[1] ?? '';
if ($target === '' || !is_dir($target)) {
    fwrite(STDERR, "ERROR: dashboard directory not found: {$target}\n");
    exit(2);
}

$configFile = rtrim($target, DIRECTORY_SEPARATOR) . '/config/site.php';
if (!is_file($configFile)) {
    fwrite(STDERR, "ERROR: dashboard config not found: {$configFile}\n");
    exit(3);
}

$config = require $configFile;
if (!is_array($config) || !isset($config['reflector']) || !is_array($config['reflector'])) {
    fwrite(STDERR, "ERROR: invalid dashboard configuration.\n");
    exit(4);
}

$r = $config['reflector'];
$name = trim((string)($r['name'] ?? ''));
$title = trim((string)($r['title'] ?? $name));
$description = trim((string)($r['description'] ?? ''));
$sysop = trim((string)($r['sysop_callsign'] ?? ''));
$location = trim((string)($r['location'] ?? ''));
$country = trim((string)($r['country'] ?? ''));
$domain = trim((string)($r['domain'] ?? ''));
$email = trim((string)($r['contact_email'] ?? ''));

if ($name === '' || $title === '' || $domain === '') {
    fwrite(STDERR, "ERROR: reflector name, title and domain are required.\n");
    exit(5);
}

$domain = preg_replace('~^https?://~i', '', $domain) ?? $domain;
$domain = rtrim($domain, '/');
$baseUrl = 'https://' . $domain;

// More-specific legacy placeholders must be rendered before REFLECTOR_NAME.
$replacements = [
    'https://{{REFLECTOR_NAME}}.net' => $baseUrl,
    '{{REFLECTOR_NAME}} Brasil' => $title,
    '{{REFLECTOR_TITLE}}' => $title,
    '{{REFLECTOR_DESCRIPTION}}' => $description,
    '{{SYSOP_CALLSIGN}}' => $sysop,
    '{{LOCATION}}' => $location,
    '{{COUNTRY}}' => $country,
    '{{DOMAIN}}' => $domain,
    '{{CONTACT_EMAIL}}' => $email,
    '{{REFLECTOR_NAME}}' => $name,
];

$allowed = ['php', 'js', 'html', 'htm', 'json', 'webmanifest', 'css'];
$excluded = [
    DIRECTORY_SEPARATOR . 'install' . DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR . 'i18n' . DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR,
];

$changed = 0;
$replaced = 0;
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($target, FilesystemIterator::SKIP_DOTS)
);

foreach ($iterator as $fileInfo) {
    if (!$fileInfo->isFile()) continue;
    $path = $fileInfo->getPathname();
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    if (!in_array($ext, $allowed, true)) continue;

    foreach ($excluded as $part) {
        if (str_contains($path, $part)) continue 2;
    }

    $contents = file_get_contents($path);
    if ($contents === false) {
        fwrite(STDERR, "ERROR: cannot read {$path}\n");
        exit(6);
    }

    $before = $contents;
    foreach ($replacements as $from => $to) {
        $count = 0;
        $contents = str_replace($from, $to, $contents, $count);
        $replaced += $count;
    }

    if ($contents !== $before) {
        if (file_put_contents($path, $contents) === false) {
            fwrite(STDERR, "ERROR: cannot write {$path}\n");
            exit(7);
        }
        $changed++;
    }
}

/*
 * Certificates are intentionally independent from the dashboard router.
 * extras/certificados/install.sh publishes certificado.php and appends its
 * menu integration to app.js only when the optional module is installed.
 * Keeping this renderer free of certificate-route patches prevents a normal
 * dashboard build from depending on a particular index.php layout.
 */

// The historical dashboard template referenced assets/logo-REFLECTOR.jpeg.
// If that generated name does not exist, reuse the first packaged logo asset.
$assets = rtrim($target, DIRECTORY_SEPARATOR) . '/assets';
$expectedLogo = $assets . '/logo-' . $name . '.jpeg';
if (is_dir($assets) && !is_file($expectedLogo)) {
    $candidates = [];
    foreach (['logo-*.jpeg', 'logo-*.jpg', 'logo-*.png', 'logo-*.webp'] as $pattern) {
        $matches = glob($assets . '/' . $pattern) ?: [];
        foreach ($matches as $candidate) {
            if (is_file($candidate)) $candidates[] = $candidate;
        }
    }
    if ($candidates !== []) {
        sort($candidates, SORT_NATURAL | SORT_FLAG_CASE);
        copy($candidates[0], $expectedLogo);
    }
}

/*
 * Version local CSS/JS references by the actual file content.
 *
 * This makes dashboard updates immediately visible without requiring users
 * to clear browser caches or press Ctrl+F5. Only local assets already carrying
 * a ?v= query in index.php are rewritten; no external URL is touched.
 */
$indexFile = rtrim($target, DIRECTORY_SEPARATOR) . '/index.php';
if (is_file($indexFile)) {
    $indexContents = file_get_contents($indexFile);
    if ($indexContents === false) {
        fwrite(STDERR, "ERROR: cannot read {$indexFile}\n");
        exit(7);
    }

    $versioned = preg_replace_callback(
        '~(?P<prefix>(?:href|src)=["\'])(?P<asset>assets/[^"\'?]+\.(?:css|js))\?v=[^"\']+(?P<suffix>["\'])~i',
        static function (array $match) use ($target): string {
            $relative = $match['asset'];
            $assetFile = rtrim($target, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative);

            if (!is_file($assetFile)) {
                return $match[0];
            }

            $hash = hash_file('sha256', $assetFile);
            if ($hash === false || $hash === '') {
                return $match[0];
            }

            return $match['prefix'] . $relative . '?v=' . substr($hash, 0, 12) . $match['suffix'];
        },
        $indexContents
    );

    if ($versioned === null) {
        fwrite(STDERR, "ERROR: asset cache version rendering failed.\n");
        exit(7);
    }

    if ($versioned !== $indexContents) {
        if (file_put_contents($indexFile, $versioned) === false) {
            fwrite(STDERR, "ERROR: cannot write {$indexFile}\n");
            exit(7);
        }
        $changed++;
    }
}

// Refuse deployment when unresolved installation placeholders remain in the
// main dashboard source. This prevents publishing a half-rendered template.
$unresolved = [];
foreach (['index.php', 'assets/app.js'] as $relative) {
    $path = rtrim($target, DIRECTORY_SEPARATOR) . '/' . $relative;
    if (!is_file($path)) continue;
    $contents = file_get_contents($path) ?: '';
    if (preg_match_all('/\{\{[A-Z0-9_]+\}\}/', $contents, $matches)) {
        foreach ($matches[0] as $token) $unresolved[$token] = true;
    }
}

if ($unresolved !== []) {
    fwrite(STDERR, "ERROR: unresolved dashboard placeholders: " . implode(', ', array_keys($unresolved)) . "\n");
    exit(8);
}

printf("Dashboard template rendered: %d files changed, %d replacements.\n", $changed, $replaced);
