<?php
/*
 * XLX026 — header compartilhado.
 * Fonte visual: /simulado-anatel/index.html
 * O HTML é lido do Simulado; somente o estado ACTIVE muda por página.
 */
$source = '/var/www/html/xlxd-novo/simulado-anatel/index.html';

if (!is_file($source)) {
    echo '<!-- XLX026: fonte do header do Simulado ausente -->';
    return;
}

$html = file_get_contents($source);
if ($html === false) {
    echo '<!-- XLX026: falha ao ler header do Simulado -->';
    return;
}

if (!preg_match('~<header\b[^>]*\bclass=(["\'])[^"\']*\bpanel-shell-header\b[^"\']*\1[^>]*>.*?</header>~is', $html, $m)) {
    echo '<!-- XLX026: header do Simulado não localizado -->';
    return;
}

$header = $m[0];

$pageKey = isset($page) ? (string)$page : '';
$activeHref = [
    'ao-vivo'     => '/ao-vivo',
    'conectados'  => '/conectados',
    'suporte'     => '/suporte',
    'modulos'     => '/modulos',
    'aprs-dprs'   => '/aprs-dprs/',
    'ranking'     => '/ranking',
    'certificado' => '/certificado',
    'refletores'  => '/refletores',
    'noticias'    => '/noticias',
][$pageKey] ?? '';

$header = preg_replace_callback('~<a\b[^>]*>~i', static function ($match) use ($activeHref) {
    $tag = $match[0];

    if (!preg_match('~\bhref=(["\'])(.*?)\1~i', $tag, $hrefMatch)) {
        return $tag;
    }

    $href = $hrefMatch[2];

    // Remove somente marcadores de página ativa do HTML fonte.
    $tag = preg_replace('~\s+aria-current=(["\'])page\1~i', '', $tag);
    $tag = preg_replace_callback('~\sclass=(["\'])(.*?)\1~i', static function ($cm) {
        $classes = preg_split('/\s+/', trim($cm[2]));
        $classes = array_values(array_filter($classes, static fn($c) => $c !== '' && $c !== 'active'));
        return $classes ? ' class="' . htmlspecialchars(implode(' ', $classes), ENT_QUOTES, 'UTF-8') . '"' : '';
    }, $tag);

    if ($activeHref !== '' && rtrim($href, '/') === rtrim($activeHref, '/')) {
        if (preg_match('~\sclass=(["\'])(.*?)\1~i', $tag)) {
            $tag = preg_replace_callback('~\sclass=(["\'])(.*?)\1~i', static function ($cm) {
                $classes = trim($cm[2] . ' active');
                return ' class="' . htmlspecialchars($classes, ENT_QUOTES, 'UTF-8') . '"';
            }, $tag, 1);
        } else {
            $tag = preg_replace('~>$~', ' class="active">', $tag, 1);
        }

        $tag = preg_replace('~>$~', ' aria-current="page">', $tag, 1);
    }

    return $tag;
}, $header);

echo $header;
