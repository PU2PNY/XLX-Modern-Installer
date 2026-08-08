<?php
declare(strict_types=1);

/**
 * XLX Modern Dashboard internationalization helpers.
 *
 * The dashboard can be built in one default language during installation.
 * Runtime language selection may also use these helpers in future releases.
 */

function xlx_locale_catalog(): array
{
    return [
        'pt-BR' => ['name' => 'Português (Brasil)', 'html' => 'pt-BR', 'og' => 'pt_BR'],
        'en'    => ['name' => 'English',            'html' => 'en',    'og' => 'en_US'],
        'es'    => ['name' => 'Español',            'html' => 'es',    'og' => 'es_ES'],
        'fr'    => ['name' => 'Français',           'html' => 'fr',    'og' => 'fr_FR'],
        'de'    => ['name' => 'Deutsch',            'html' => 'de',    'og' => 'de_DE'],
        'it'    => ['name' => 'Italiano',           'html' => 'it',    'og' => 'it_IT'],
    ];
}

function xlx_supported_locales(): array
{
    return array_keys(xlx_locale_catalog());
}

function xlx_normalize_locale(string $locale, string $fallback = 'pt-BR'): string
{
    $locale = trim(str_replace('_', '-', $locale));
    if ($locale === '') {
        return $fallback;
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

    return $fallback;
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

function xlx_locale_html(string $locale): string
{
    $catalog = xlx_locale_catalog();
    $locale = xlx_normalize_locale($locale);
    return (string)($catalog[$locale]['html'] ?? 'pt-BR');
}

function xlx_locale_og(string $locale): string
{
    $catalog = xlx_locale_catalog();
    $locale = xlx_normalize_locale($locale);
    return (string)($catalog[$locale]['og'] ?? 'pt_BR');
}

function xlx_locale_name(string $locale): string
{
    $catalog = xlx_locale_catalog();
    $locale = xlx_normalize_locale($locale);
    return (string)($catalog[$locale]['name'] ?? $locale);
}
