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

// Install an inert optional-module hook in the rendered dashboard. The hook
// exposes Certificates only when the independently installed module files are
// present. It never creates certificate state, secrets or records.
$indexPath = rtrim($target, DIRECTORY_SEPARATOR) . '/index.php';
if (is_file($indexPath)) {
    $index = file_get_contents($indexPath);
    if ($index === false) {
        fwrite(STDERR, "ERROR: cannot read {$indexPath}\n");
        exit(9);
    }

    if (!str_contains($index, 'XLX_CERTIFICATES_OPTIONAL_HOOK_V1')) {
        $certificateTitle = var_export('Certificado de participação — ' . $title, true);
        $certificateDescription = var_export('Gere e valide certificados de participação do ' . $title . ' quando o módulo opcional estiver instalado.', true);

        $patches = [
            <<<'OLD'
$page = $_GET['page'] ?? 'ao-vivo';
$allowed = ['ao-vivo','modulos','conectados','ranking','refletores'];
OLD
            => <<<'NEW'
$page = $_GET['page'] ?? 'ao-vivo';
/* XLX_CERTIFICATES_OPTIONAL_HOOK_V1 */
$certificateEnabled = is_file(__DIR__.'/certificado-view.php')
    && is_file(__DIR__.'/certificado-config.php')
    && is_file(__DIR__.'/api/certificado.php');
$allowed = ['ao-vivo','modulos','conectados','ranking','refletores'];
if ($certificateEnabled) $allowed[] = 'certificado';
NEW,
            <<<'OLD'
  $html = '';
  foreach ($items as $slug => $label) {
OLD
            => <<<'NEW'
  if (is_file(__DIR__.'/certificado-view.php') && is_file(__DIR__.'/api/certificado.php')) {
    $items['certificado'] = 'Certificados';
  }
  $html = '';
  foreach ($items as $slug => $label) {
NEW,
            <<<'OLD'
];
$meta = $seo[$page];
OLD
            => "];\nif (\$certificateEnabled) {\n  \$seo['certificado'] = ['title'=>{$certificateTitle},'description'=>{$certificateDescription}];\n}\n\$meta = \$seo[\$page];\n",
            <<<'OLD'
<?php endif; ?>
</head>
OLD
            => <<<'NEW'
<?php endif; ?>
<?php if ($certificateEnabled): ?>
<link rel="stylesheet" href="assets/cert-event-alert-v1.css?v=1">
<?php endif; ?>
<?php if ($certificateEnabled && $page === 'certificado'): ?>
<link rel="stylesheet" href="assets/certificado.css?v=1">
<?php endif; ?>
</head>
NEW,
            <<<'OLD'
<?php endif; ?>

</main>
OLD
            => <<<'NEW'
<?php elseif ($certificateEnabled && $page === 'certificado'): ?>
<?php require __DIR__.'/certificado-view.php'; ?>
<?php endif; ?>

</main>
NEW,
            <<<'OLD'
<script src="assets/header-unificado-v1.js?v=20260807_032449"></script>
</body></html>
OLD
            => <<<'NEW'
<script src="assets/header-unificado-v1.js?v=20260807_032449"></script>
<?php if ($certificateEnabled): ?>
<script src="assets/cert-event-alert-v1.js?v=1" defer></script>
<?php endif; ?>
<?php if ($certificateEnabled && $page === 'certificado'): ?>
<script src="assets/vendor/qrcode.min.js?v=1"></script>
<script src="assets/certificado.js?v=1" defer></script>
<?php endif; ?>
</body></html>
NEW,
        ];

        foreach ($patches as $from => $to) {
            $count = 0;
            $index = str_replace($from, $to, $index, $count);
            if ($count !== 1) {
                fwrite(STDERR, "ERROR: optional certificate hook pattern mismatch in {$indexPath}\n");
                exit(10);
            }
        }

        if (file_put_contents($indexPath, $index) === false) {
            fwrite(STDERR, "ERROR: cannot write optional certificate hook to {$indexPath}\n");
            exit(11);
        }
        $changed++;
    }
}

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
