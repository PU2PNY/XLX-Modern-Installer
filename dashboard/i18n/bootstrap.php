<?php
declare(strict_types=1);

/**
 * XLX Modern Dashboard i18n bootstrap.
 * This file is intentionally not wired into the production dashboard yet.
 * It provides the translation engine that will be enabled after all visible
 * PHP and JavaScript strings have been inventoried and migrated.
 */

function xlx_supported_locales(): array
{
    return ['pt-BR', 'en', 'es', 'fr', 'de', 'it'];
}

function xlx_normalize_locale(string $locale): string
{
    $locale = trim(str_replace('_', '-', $locale));
    if ($locale === '') {
        return 'pt-BR';
    }

    foreach (xlx_supported_locales() as $supported) {
        if (strcasecmp($locale, $supported) === 0) {
            return $supported;
        }
    }

    $short = strtolower(substr($locale, 0, 2));
    foreach (xlx_supported_locales() as $supported) {
        if (strtolower(substr($supported, 0, 2)) === $short) {
            return $supported;
        }
    }

    return 'pt-BR';
}

function xlx_load_messages(string $locale): array
{
    $locale = xlx_normalize_locale($locale);
    $base = __DIR__ . '/locales/';
    $fallbackFile = $base . 'pt-BR.php';
    $localeFile = $base . $locale . '.php';

    $fallback = is_file($fallbackFile) ? require $fallbackFile : [];
    $messages = is_file($localeFile) ? require $localeFile : [];

    return array_replace($fallback, $messages);
}

function xlx_t(array $messages, string $key, array $replace = []): string
{
    $text = (string)($messages[$key] ?? $key);
    foreach ($replace as $name => $value) {
        $text = str_replace('{' . $name . '}', (string)$value, $text);
    }
    return $text;
}
