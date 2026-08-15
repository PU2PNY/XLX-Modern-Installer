<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=300');

const CACHE_TTL = 900;
const MAX_ITEMS = 5;

$cacheFile = sys_get_temp_dir() . '/xlx026_ham_news_v1.json';

function out(array $data): never
{
    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES |
        JSON_INVALID_UTF8_SUBSTITUTE
    );
    exit;
}

if (
    is_file($cacheFile) &&
    (time() - (int) @filemtime($cacheFile)) < CACHE_TTL
) {
    $cached = @file_get_contents($cacheFile);

    if ($cached !== false && json_decode($cached, true) !== null) {
        echo $cached;
        exit;
    }
}

function cleanText(string $text): string
{
    $text = html_entity_decode(
        strip_tags($text),
        ENT_QUOTES | ENT_HTML5,
        'UTF-8'
    );

    return trim((string) preg_replace('/\s+/u', ' ', $text));
}

function fetchUrl(string $url): ?string
{
    if (function_exists('curl_init')) {

        $ch = curl_init($url);

        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_MAXREDIRS      => 4,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_USERAGENT      => 'XLX026-HamNews/1.0 (+https://{{DOMAIN}})',
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_ENCODING       => '',
        ]);

        $body = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);

        curl_close($ch);

        if (is_string($body) && $code >= 200 && $code < 400) {
            return $body;
        }
    }

    $ctx = stream_context_create([
        'http' => [
            'timeout' => 10,
            'header' =>
                "User-Agent: XLX026-HamNews/1.0\r\n" .
                "Accept: text/html,application/xhtml+xml,application/xml\r\n"
        ]
    ]);

    $body = @file_get_contents($url, false, $ctx);

    return is_string($body) ? $body : null;
}

function absoluteUrl(string $href, string $base): ?string
{
    $href = trim(html_entity_decode($href, ENT_QUOTES | ENT_HTML5));

    if (
        $href === '' ||
        $href[0] === '#' ||
        stripos($href, 'javascript:') === 0 ||
        stripos($href, 'mailto:') === 0
    ) {
        return null;
    }

    if (preg_match('#^https?://#i', $href)) {
        return $href;
    }

    $p = parse_url($base);

    if (!$p || empty($p['host'])) {
        return null;
    }

    $scheme = $p['scheme'] ?? 'https';

    if (substr($href, 0, 2) === '//') {
        return $scheme . ':' . $href;
    }

    if (substr($href, 0, 1) === '/') {
        return $scheme . '://' . $p['host'] . $href;
    }

    $path = $p['path'] ?? '/';
    $dir = rtrim(dirname($path), '/');

    return $scheme . '://' . $p['host'] . $dir . '/' . $href;
}

function isAllowed(string $url, string $source): bool
{
    $host = strtolower((string) parse_url($url, PHP_URL_HOST));
    $path = strtolower((string) parse_url($url, PHP_URL_PATH));

    if ($source === 'ANATEL') {

        if ($host !== 'www.gov.br' && $host !== 'gov.br') {
            return false;
        }

        return strpos(
            $path,
            '/anatel/pt-br/assuntos/noticias/'
        ) !== false;
    }

    if ($source === 'LABRE') {

        if (
            $host !== 'labre.org.br' &&
            $host !== 'www.labre.org.br'
        ) {
            return false;
        }

        if ($path === '' || $path === '/') {
            return false;
        }

        $blocked = [
            '/wp-content/',
            '/wp-admin/',
            '/feed/',
            '/tag/',
            '/category/'
        ];

        foreach ($blocked as $x) {
            if (strpos($path, $x) !== false) {
                return false;
            }
        }

        return true;
    }

    return false;
}

function parseOfficialPage(
    string $url,
    string $source,
    int $limit
): array {

    $html = fetchUrl($url);

    if (!$html) {
        return [];
    }

    if (!class_exists('DOMDocument')) {
        return [];
    }

    libxml_use_internal_errors(true);

    $dom = new DOMDocument();

    @$dom->loadHTML(
        '<?xml encoding="utf-8" ?>' . $html,
        LIBXML_NOWARNING | LIBXML_NOERROR
    );

    libxml_clear_errors();

    $xpath = new DOMXPath($dom);

    $items = [];
    $seen = [];

    foreach ($xpath->query('//a[@href]') as $a) {

        $title = cleanText((string) $a->textContent);

        if (strlen($title) < 24 || strlen($title) > 240) {
            continue;
        }

        $href = absoluteUrl(
            (string) $a->getAttribute('href'),
            $url
        );

        if (!$href || !isAllowed($href, $source)) {
            continue;
        }

        $key = strtolower(
            preg_replace('/[^a-z0-9]+/i', '', $title)
        );

        if ($key === '' || isset($seen[$key])) {
            continue;
        }

        $seen[$key] = true;

        $items[] = [
            'title'     => $title,
            'url'       => $href,
            'published' => null,
            'source'    => $source,
            'direct'    => true
        ];

        if (count($items) >= $limit) {
            break;
        }
    }

    return $items;
}

function parseRssFallback(
    string $rssUrl,
    string $source,
    int $limit
): array {

    $xmlText = fetchUrl($rssUrl);

    if (!$xmlText || !function_exists('simplexml_load_string')) {
        return [];
    }

    libxml_use_internal_errors(true);
    $xml = simplexml_load_string($xmlText);
    libxml_clear_errors();

    if (!$xml || !isset($xml->channel->item)) {
        return [];
    }

    $items = [];
    $seen = [];

    foreach ($xml->channel->item as $item) {

        $title = cleanText((string) $item->title);
        $url   = trim((string) $item->link);

        if ($title === '' || $url === '') {
            continue;
        }

        $key = strtolower(
            preg_replace('/[^a-z0-9]+/i', '', $title)
        );

        if ($key === '' || isset($seen[$key])) {
            continue;
        }

        $seen[$key] = true;

        $ts = strtotime((string) $item->pubDate);

        $items[] = [
            'title' => $title,
            'url' => $url,
            'published' => $ts ? date(DATE_ATOM, $ts) : null,
            'source' => $source,
            'direct' => false
        ];

        if (count($items) >= $limit) {
            break;
        }
    }

    return $items;
}

function mergeItems(array $primary, array $fallback, int $limit): array
{
    $out = [];
    $seen = [];

    foreach (array_merge($primary, $fallback) as $item) {

        $key = strtolower(
            preg_replace(
                '/[^a-z0-9]+/i',
                '',
                (string) ($item['title'] ?? '')
            )
        );

        if ($key === '' || isset($seen[$key])) {
            continue;
        }

        $seen[$key] = true;
        $out[] = $item;

        if (count($out) >= $limit) {
            break;
        }
    }

    return $out;
}


/*
 * FONTES OFICIAIS
 */

$anatelOfficial = parseOfficialPage(
    'https://www.gov.br/anatel/pt-br/assuntos/noticias',
    'ANATEL',
    MAX_ITEMS
);

$labreOfficial = [];

foreach ([
    'https://www.labre.org.br/',
    'https://labre.org.br/'
] as $labreUrl) {

    $labreOfficial = parseOfficialPage(
        $labreUrl,
        'LABRE',
        MAX_ITEMS
    );

    if (count($labreOfficial) >= 2) {
        break;
    }
}


/*
 * FALLBACK DE INDEXACAO.
 * Continua limitado aos dominios oficiais.
 */

$anatelFallback = [];

if (count($anatelOfficial) < MAX_ITEMS) {

    $anatelFallback = parseRssFallback(
        'https://news.google.com/rss/search?q=site%3Agov.br%2Fanatel%2Fpt-br%2Fassuntos%2Fnoticias&hl=pt-BR&gl=BR&ceid=BR%3Apt-419',
        'ANATEL',
        MAX_ITEMS
    );
}

$labreFallback = [];

if (count($labreOfficial) < MAX_ITEMS) {

    $labreFallback = parseRssFallback(
        'https://news.google.com/rss/search?q=site%3Alabre.org.br&hl=pt-BR&gl=BR&ceid=BR%3Apt-419',
        'LABRE',
        MAX_ITEMS
    );
}

$anatel = mergeItems(
    $anatelOfficial,
    $anatelFallback,
    MAX_ITEMS
);

$labre = mergeItems(
    $labreOfficial,
    $labreFallback,
    MAX_ITEMS
);

$data = [
    'ok' => true,
    'generated_at' => date(DATE_ATOM),
    'cache_seconds' => CACHE_TTL,

    'anatel' => $anatel,
    'labre' => $labre,

    'status' => [
        'anatel_direct' => count($anatelOfficial),
        'labre_direct' => count($labreOfficial),
        'anatel_total' => count($anatel),
        'labre_total' => count($labre)
    ]
];

$json = json_encode(
    $data,
    JSON_UNESCAPED_UNICODE |
    JSON_UNESCAPED_SLASHES |
    JSON_INVALID_UTF8_SUBSTITUTE
);

if ($json !== false) {
    @file_put_contents($cacheFile, $json, LOCK_EX);
    echo $json;
    exit;
}

out([
    'ok' => false,
    'error' => 'Falha ao gerar JSON.'
]);
