<?php
$root = dirname(__DIR__);
$locales = ['pt-BR', 'en', 'es', 'fr', 'de', 'it'];
$baseline = require $root . '/dashboard/i18n/locales/en.php';
$baseKeys = array_keys($baseline);
sort($baseKeys);
foreach ($locales as $locale) {
    $data = require $root . '/dashboard/i18n/locales/' . $locale . '.php';
    if (!is_array($data)) {
        fwrite(STDERR, "[FAIL] locale $locale did not return an array\n");
        exit(1);
    }
    $keys = array_keys($data);
    sort($keys);
    $missing = array_values(array_diff($baseKeys, $keys));
    $extra = array_values(array_diff($keys, $baseKeys));
    if ($missing || $extra) {
        fwrite(STDERR, "[FAIL] locale $locale key mismatch\n");
        if ($missing) fwrite(STDERR, "missing: " . implode(', ', $missing) . "\n");
        if ($extra) fwrite(STDERR, "extra: " . implode(', ', $extra) . "\n");
        exit(1);
    }
}
echo "[OK] all dashboard locales have exact key parity with English\n";
