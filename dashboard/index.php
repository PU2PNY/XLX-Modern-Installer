<?php
$page = $_GET['page'] ?? 'ao-vivo';
$allowed = ['ao-vivo','modulos','conectados','ranking','refletores','noticias','suporte','certificado','digital-lab','simulado-anatel'];
if (!in_array($page, $allowed, true)) $page = 'ao-vivo';
function nav_class(string $p, string $current): string { return $p === $current ? ' class="active"' : ''; }
function page_url(string $p): string {
  if ($p === 'digital-lab') return '/aprs-dprs';
  if ($p === 'simulado-anatel') return '/simulado-anatel/';
  return '/' . rawurlencode($p);
}
function render_nav(string $page): string {
  $items = [
    'ao-vivo' => 'Ao vivo',
    'conectados' => 'Conectados',
    'suporte' => 'Suporte',
    'modulos' => 'Módulos A–E',
    'digital-lab' => 'APRS / D-PRS',
    'ranking' => 'Ranking',
    'certificado' => 'Certificado',
    'simulado-anatel' => 'Simulado ANATEL',
    'refletores' => 'Lista de refletores XLX',
    'noticias' => 'Notícias',
  ];
  $html = '';
  foreach ($items as $slug => $label) {
    $cls = $slug === $page ? ' class="active"' : '';
    $html .= '<a' . $cls . ' href="' . htmlspecialchars(page_url($slug), ENT_QUOTES, 'UTF-8') . '">' . htmlspecialchars($label, ENT_QUOTES, 'UTF-8') . '</a>';
  }
  return $html;
}
$seo = [
 'digital-lab'=>['title'=>'APRS / D-PRS XLX026 | Mensagens APRS, GPS-A e Módulo B','description'=>'Envie e receba mensagens APRS pelo APRS-IS, acompanhe ACKs, estações e comandos e visualize beacons D-PRS/GPS-A recebidos pelo módulo B do XLX026.'],
 'ao-vivo'=>['title'=>'XLX026 Brasil — Painel ao vivo D-STAR, DMR e C4FM','description'=>'Acompanhe ao vivo transmissões, estações conectadas e módulos do refletor multiprotocolo XLX026 Brasil.'],
 'modulos'=>['title'=>'Módulos A–E — XLX026 Brasil','description'=>'Consulte funções, protocolos e identificações de acesso dos módulos A a E do refletor XLX026 Brasil.'],
 'conectados'=>['title'=>'Estações conectadas — XLX026 Brasil','description'=>'Veja em tempo real as estações conectadas ao XLX026 Brasil, com indicativo, protocolo, módulo e tempo de conexão.'],
 'ranking'=>['title'=>'Ranking de atividade — XLX026 Brasil','description'=>'Ranking recente do XLX026 Brasil por transmissões, tempo no ar, permanência, horários, protocolos e módulos.'],
 'refletores'=>['title'=>'Lista de refletores XLX — XLX026 Brasil','description'=>'Lista atualizada de refletores XLX registrados, com país, status e descrição.'],
 'noticias'=>[
   'title'=>'Notícias de Radioamadorismo — ANATEL e LABRE | XLX026 Brasil',
   'description'=>'Notícias e publicações recentes da ANATEL e LABRE para a comunidade radioamadora no painel XLX026 Brasil.'
 ],
 'certificado'=>['title'=>'Certificado de Participação — XLX026 Brasil','description'=>'Gere e valide certificados oficiais de participação registrada no refletor XLX026 Brasil.'],
 'suporte'=>['title'=>'Suporte e tutoriais — XLX026 Brasil','description'=>'Tutoriais e orientações para conexão ao XLX026 Brasil por D-STAR, DMR e C4FM/YSF.'],
 'simulado-anatel'=>['title'=>'Simulado ANATEL 2026 para Radioamador | XLX026 Brasil','description'=>'Simulação educacional independente em formato Certo ou Errado, com correção comentada, base normativa e fontes oficiais após as respostas.'],
];
$meta = $seo[$page];
$canonical = $page === 'digital-lab'
  ? 'https://{{DOMAIN}}/aprs-dprs'
  : 'https://{{DOMAIN}}/' . ($page === 'ao-vivo' ? '' : '?page=' . rawurlencode($page));
?>
<!doctype html>
<html lang="pt-BR"><head>
<?php if ($page === 'simulado-anatel'): ?><!-- XLX026_SIMULADO_V4_BASE --><base href="/"><!-- /XLX026_SIMULADO_V4_BASE --><?php endif; ?>


<script id="xlx026LegacyMobileGateV12">
(function(){
    var ua = navigator.userAgent || "";
    var isAppleMobile = /iPad|iPhone|iPod/.test(ua);
    var isIOS9 = /OS 9_[0-9_]+/.test(ua);
    var hasSafari = /Safari\//.test(ua);
    var isVersion9 = /Version\/9/.test(ua);

    var isAndroid = /Android/.test(ua);
    var chromeMatch = ua.match(/Chrome\/([0-9]+)/);
    var firefoxMatch = ua.match(/Firefox\/([0-9]+)/);
    var androidMatch = ua.match(/Android[ \/]([0-9]+)/);
    var chromeMajor = chromeMatch
        ? parseInt(chromeMatch[1],10)
        : 0;
    var firefoxMajor = firefoxMatch
        ? parseInt(firefoxMatch[1],10)
        : 0;
    var androidMajor = androidMatch
        ? parseInt(androidMatch[1],10)
        : 0;

    var oldIOS9Safari =
        isAppleMobile &&
        isIOS9 &&
        hasSafari &&
        isVersion9;

    /*
     * O painel moderno usa sintaxe como ?. e ??.
     * No Android, encaminhamos somente engines anteriores
     * ao suporte dessa sintaxe. Navegadores atuais permanecem
     * exatamente no painel moderno.
     */
    var oldAndroidChrome =
        isAndroid &&
        chromeMajor > 0 &&
        chromeMajor < 80;

    var oldAndroidFirefox =
        isAndroid &&
        firefoxMajor > 0 &&
        firefoxMajor < 74;

    var oldAndroidStock =
        isAndroid &&
        chromeMajor === 0 &&
        firefoxMajor === 0 &&
        (
            androidMajor > 0 &&
            androidMajor <= 4
        );

    if (
        oldIOS9Safari ||
        oldAndroidChrome ||
        oldAndroidFirefox ||
        oldAndroidStock
    ) {
        window.location.replace(
            "/safari9-test.html?automatico=1"
        );
    }
}());
</script>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#06131d"><meta name="description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
<link rel="canonical" href="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>">
<meta property="og:type" content="website"><meta property="og:locale" content="pt_BR"><meta property="og:site_name" content="XLX026 Brasil">
<meta property="og:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta property="og:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta property="og:url" content="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>"><meta property="og:image" content="https://{{DOMAIN}}/assets/logo-xlx026.jpeg">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:image" content="https://{{DOMAIN}}/assets/logo-xlx026.jpeg">
<link rel="icon" href="favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png"><link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png"><link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png"><link rel="manifest" href="site.webmanifest">
<title><?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/app.css?v=modulosresponsive_20260809_003204"><link rel="stylesheet" href="assets/header-hotfix.css?v=1"><link rel="stylesheet" href="assets/mtr.css?v=4">
<script type="application/ld+json"><?=json_encode(['@context'=>'https://schema.org','@type'=>'WebSite','name'=>'XLX026 Brasil','url'=>'https://{{DOMAIN}}/','description'=>' para radioamadores com D-STAR, DMR e C4FM/YSF.','inLanguage'=>'pt-BR','image'=>'https://{{DOMAIN}}/assets/logo-xlx026.jpeg'], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?></script><?php if ($page === 'suporte'): ?><link rel="stylesheet" href="assets/support-native.css?v=22"><?php endif; ?><link rel="stylesheet" href="assets/install-app.css?v=33"><link rel="stylesheet" href="assets/offline-neon.css?v=20260806_103404"> <link rel="stylesheet" href="assets/ham-weather-widget.css?v=3">

<!-- XLX026_HAM_NEWS_V1 CSS -->
<link rel="stylesheet" href="/assets/ham-news-widget.css?v=1">


<!-- XLX026_MOBILE_MENU_V4_CSS -->
<link rel="stylesheet" href="assets/mobile-menu-v4.css?v=20260807_023247">
<!-- XLX026_AO_VIVO_CLEAN_V1_CSS -->
<link rel="stylesheet" href="assets/ao-vivo-clean-v1.css?v=20260807_024051">

<!-- XLX026_HISTORY_SOUND_MENU_V1 CSS -->
<link rel="stylesheet" href="assets/history-sound-menu-v1.css?v=20260807_025428">

<!-- XLX026_HISTORY_MOBILE_FIT_V2 -->
<link rel="stylesheet" href="assets/history-mobile-fit-v2.css?v=20260807_031008">

<!-- XLX026_TABLE_ROW_HOVER_V1 -->
<link rel="stylesheet" href="assets/table-row-hover-v1.css?v=20260807_031841">

<!-- XLX026_HEADER_UNIFICADO_V1 CSS -->
<link rel="stylesheet" href="assets/header-unificado-v1.css?v=20260807_032449">
<link rel="stylesheet" href="assets/ao-vivo-top-layout-v2.css?v=20260809_004523">
<link rel="stylesheet" href="assets/ao-vivo-compact-v3.css?v=20260809_005445">

<link rel="stylesheet" href="assets/ao-vivo-tx-embed-v5.css?v=20260809_011147">
<link rel="stylesheet" href="assets/ao-vivo-tx-finetune-v6.css?v=20260809_012217">
<link rel="stylesheet" href="assets/ao-vivo-visual-fix-v7.css?v=20260809_012436">
<link rel="stylesheet" href="assets/ao-vivo-gif-scale-v8.css?v=20260809_012804">
<link rel="stylesheet" href="assets/ao-vivo-gif-position-v9.css?v=20260809_013030">
<link rel="stylesheet" href="assets/ao-vivo-gif-anchor-v12.css?v=20260809_014742">
<!-- XLX026_HEADER_NEON_FINETUNE_V1 -->
<link rel="stylesheet" href="assets/header-neon-finetune-v1.css?v=20260809_020223">
<?php if ($page === 'certificado'): ?>
<link rel="stylesheet" href="assets/certificado.css?v=20260809_01">
<?php endif; ?>
<link rel="stylesheet" href="assets/ao-vivo-cirurgico-v1.css?v=20260810_CIRURGICO_V1">
<link rel="stylesheet" href="assets/ao-vivo-boxes-v2.css?v=20260810_BOXES_V2">
<link rel="stylesheet" href="assets/ao-vivo-boxes-v31-radar.css?v=RADAR_V31_20260810_011540">
<link rel="stylesheet" href="assets/atividade-24h-conectados-v1.css?v=ATIVIDADE24H_V1_20260810_012549">
<?php if ($page === 'digital-lab'): ?><link rel="stylesheet" href="assets/digital-lab.css?v=20260810_DLAB_V1"><?php endif; ?>
<!-- XLX026_CERT_EVENT_ALERT_V1_CSS -->
<link rel="stylesheet" href="assets/cert-event-alert-v1.css?v=20260811_02">
<!-- XLX026-A11Y-CSS -->
<link rel="stylesheet" href="assets/xlx026-accessibility.css?v=a11y3">
<!-- /XLX026-A11Y-CSS -->
<!-- XLX026_STANDBY_DENTRO_BOX_V3 -->
<link rel="stylesheet" href="assets/standby-mensagens-v3.css?v=20260814_091215">

<?php if ($page === 'simulado-anatel'): ?>
<!-- XLX026_SIMULADO_V4_CSS -->
<link rel="stylesheet" href="/assets/simulado-anatel.css?v=20260815_062228">
<!-- /XLX026_SIMULADO_V4_CSS -->
<?php endif; ?>
</head>
<body data-page="<?=htmlspecialchars($page, ENT_QUOTES, 'UTF-8')?>">
<main>
<section class="hero hero-compact universal-header" aria-label="XLX026 Brasil">
 <div class="universal-header-row">
  <a class="universal-brand" href="<?=page_url('ao-vivo')?>" aria-label="XLX026 Brasil">
   <img class="hero-logo" src="assets/logo-xlx026.jpeg" alt="XLX026 Brasil — D-STAR, DMR e C4FM" width="112" height="112">
  </a>

  <div class="universal-copy">
   <h1><span>XLX026 Brasil</span></h1>

   <div class="access-strip access-strip-compact" aria-label="Acessos do servidor">
    <span><b>D-STAR</b> XLX026-D</span>
    <span><b>DMR</b> XLX026-C • TG 6 no rádio • TG 4003 nos apps</span>
    <span><b>C4FM/YSF</b> BR-XLX026 • YSF72426</span>
   </div>
  </div>

  <div class="live-pill universal-live-pill" aria-live="polite">
   <i></i>
   <span id="syncState">Conectando</span>
  </div>
 </div>

 <nav class="universal-nav" aria-label="Menu principal">
  <?=render_nav($page)?>
 </nav>

 <button class="menu-toggle" type="button" aria-label="Abrir menu" aria-expanded="false">☰</button>
</section>
<?php if ($page === 'ao-vivo'): ?>
 <section class="dashboard-layout">
   <aside class="live-widget"><div class="widget-heading"><div><p class="eyebrow">MONITOR AO VIVO</p><h2>Transmissões</h2></div><span id="widgetCount">Standby</span></div><div class="live-summary-bar" aria-label="Resumo do monitor ao vivo"><span class="live-summary-item live-summary-connected"><b id="headerConnected">0</b><small>conectados</small></span><span class="live-summary-item live-summary-active"><b id="headerActive">0</b><small>TX ativa</small></span></div><div id="moduleGrid" class="module-grid widget-grid"></div></aside>
 <div class="dashboard-main panel compact-panel">
   <div class="section-title panel-title"><div><p class="eyebrow">ÚLTIMAS ATIVIDADES</p><h2 class="history-title-connected-size">Atividade das últimas 24 horas</h2></div><span class="table-note">Até 40 indicativos</span></div>
   <div class="table-wrap"><table class="home-history"><thead><tr><th>País</th><th>Horário</th><th>Indicativo</th><th>Operador</th><th>Protocolo</th><th>Módulo</th><th>Duração</th><th>Status</th></tr></thead><tbody id="historyRows"></tbody></table></div>
  </div>
 </section>
<!-- XLX026 HAM WEATHER WIDGET V1 -->
 <section class="hamwx-panel panel" id="hamWeatherWidget" aria-label="Clima e condições de propagação para radioamadores">
  <div class="hamwx-skeleton">Carregando clima e propagação...</div>
 </section>
<!-- /XLX026 HAM WEATHER WIDGET V1 -->
<?php elseif ($page === 'simulado-anatel'): ?>
<!-- XLX026_SIMULADO_V4_VIEW -->
<?php require __DIR__.'/simulado-anatel-view.php'; ?>
<!-- /XLX026_SIMULADO_V4_VIEW -->
<?php elseif ($page === 'modulos'): ?>
 <section class="page-heading"><p class="eyebrow">ESTRUTURA DO REFLETOR</p><h1>Módulos A–E</h1><p>Identificação, função, protocolo, acesso e quantidade de estações conectadas em cada módulo.</p></section>
 <section id="moduleOverview" class="module-overview-grid module-page-grid"></section>
 <section class="panel module-reference"><h2>Identificações de acesso</h2><div class="table-wrap"><table class="module-access-table"><thead><tr><th rowspan="2">Módulo</th><th rowspan="2">Protocolo / função</th><th rowspan="2">Estações conectadas</th><th colspan="2">DPlus (REF)</th><th colspan="2">DExtra (XRF)</th><th colspan="2">DCS (DCS/XLX)</th><th rowspan="2">DMR</th><th rowspan="2">YSF DG-ID</th></tr><tr><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th></tr></thead><tbody id="moduleReferenceRows"></tbody></table></div></section>
<?php elseif ($page === 'digital-lab'): ?>
 <?php require __DIR__ . '/digital-lab-native.php'; ?>
<?php elseif ($page === 'conectados'): ?>
 <section class="page-heading heading-with-tools"><div><p class="eyebrow">REDE ATIVA</p><h1>Estações conectadas</h1><p id="connectedLabel">Carregando conexões...</p></div><label class="search-box"><span>Pesquisar</span><input id="connectedSearch" type="search" placeholder="Indicativo, nome ou região" autocomplete="off"></label></section>
 <section id="connectedCards" class="connected-cards"></section>
 <section class="panel"><div class="table-wrap"><table class="connected-table"><thead><tr><th>#</th><th>País</th><th>Indicativo</th><th>Nome</th><th>Localização</th><th>Protocolo</th><th>Módulo</th><th>Conectado às</th><th>Tempo conectado</th><th>Última atividade</th></tr></thead><tbody id="connectedRows"></tbody></table></div></section>
<?php elseif ($page === 'certificado'): ?>
<?php require __DIR__.'/certificado-view.php'; ?>
<?php elseif ($page === 'ranking'): ?>
<!-- XLX026_RANKING_V2 -->
<?php require __DIR__.'/ranking-v2-view.php'; ?>

<?php elseif ($page === 'refletores'): ?>
 <section class="page-heading"><p class="eyebrow">REDE MUNDIAL</p><h1>Lista de refletores XLX</h1></section>
 <section class="panel embedded-panel"><div class="embedded-toolbar"><div><b>Refletores registrados</b><span>Nome, país, status e descrição.</span></div></div><div class="table-wrap"><table class="reflectors-table"><thead><tr><th>#</th><th>Refletor</th><th>País</th><th>Status</th><th>Descrição</th></tr></thead><tbody id="reflectorRows"><tr><td colspan="5">Carregando lista de refletores...</td></tr></tbody></table></div></section>
<?php elseif ($page === 'noticias'): ?>

<section class="page-heading">
    <p class="eyebrow">
        INFORMAÇÃO PARA RADIOAMADORES
    </p>

    <h1>
        Notícias do radioamadorismo
    </h1>

    <p>
        Últimas publicações da ANATEL e LABRE
        reunidas no painel XLX026 Brasil.
    </p>
</section>

<!-- ======================================================
     XLX026_HAM_NEWS_V1
     Notícias oficiais ANATEL + LABRE
     ====================================================== -->
<section
    id="hamNewsWidget"
    aria-labelledby="hamNewsTitle"
>
    <div class="ham-news-head">

        <div>
            <p class="ham-news-eyebrow">
                RADIOAMADORISMO
            </p>

            <h2 id="hamNewsTitle">
                Notícias oficiais
            </h2>

            <p class="ham-news-subtitle">
                Últimas publicações da ANATEL e LABRE
            </p>
        </div>

        <div class="ham-news-actions">
            <span id="hamNewsUpdated">
                Atualizando...
            </span>

            <button
                id="hamNewsRefresh"
                type="button"
            >
                Atualizar
            </button>
        </div>

    </div>

    <div
        class="ham-news-grid"
        aria-live="polite"
    >

        <article class="ham-news-source anatel">

            <div class="ham-news-source-head">
                <div class="ham-news-source-title">
                    <i></i>
                    ANATEL
                </div>

                <span>Fonte oficial</span>
            </div>

            <div
                id="hamNewsAnatel"
                class="ham-news-list"
            ></div>

        </article>


        <article class="ham-news-source labre">

            <div class="ham-news-source-head">
                <div class="ham-news-source-title">
                    <i></i>
                    LABRE
                </div>

                <span>Radioamadorismo</span>
            </div>

            <div
                id="hamNewsLabre"
                class="ham-news-list"
            ></div>

        </article>

    </div>
</section>
<!-- FIM XLX026_HAM_NEWS_V1 -->

<?php else: ?>
<?php include __DIR__ . '/support-native.php'; ?>
<?php endif; ?>



</main>
<footer><div><a class="brand footer-brand" href="<?=page_url('ao-vivo')?>"><img class="brand-logo" src="assets/logo-xlx026.jpeg" alt="Logotipo XLX026 Brasil"><span><b>XLX026</b><small>BRASIL</small></span></a></div><div class="footer-links"><a href="<?=page_url('ao-vivo')?>">Ao vivo</a><a href="<?=page_url('modulos')?>">Módulos</a><a href="<?=page_url('digital-lab')?>">APRS / D-PRS</a><a href="<?=page_url('conectados')?>">Conectados</a><a href="<?=page_url('ranking')?>">Ranking</a><a href="<?=page_url('noticias')?>">Notícias</a><a href="<?=page_url('suporte')?>">Suporte</a></div><small class="footer-final-line"><strong>Painel XLX-Modern — v1.0</strong><span class="footer-separator">•</span><span>Desenvolvido por <a href="https://paginacertadigital.com.br/" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span></small></footer>
<div id="toastStack" class="toast-stack"></div><?php if ($page === 'suporte'): ?><script src="assets/support-native.js?v=22"></script><?php endif; ?><script src="assets/mtr.js?v=20260810_CIRURGICO_V1"></script><script src="assets/app.js?v=CONNECTED_VOICE_NO_TX_V103_20260813_005148"></script>


<!-- XLX026 INSTALL APP V33 -->
<div
    id="xlxInstallOverlay"
    class="xlx-install-overlay"
    role="dialog"
    aria-modal="true"
    aria-labelledby="xlxInstallTitle"
    aria-hidden="true"
>
    <div class="xlx-install-dialog">
        <div class="xlx-install-head">
            <img
                class="xlx-install-icon"
                src="/android-chrome-192x192.png"
                alt=""
                width="66"
                height="66"
            >
            <div>
                <span class="xlx-install-eyebrow">
                    Acesso rápido
                </span>
                <h2 id="xlxInstallTitle">
                    Instalar XLX026 Brasil
                </h2>
            </div>
        </div>

        <div class="xlx-install-body">
            <p id="xlxInstallDescription">
                Crie um atalho do painel no seu aparelho e abra o servidor como um aplicativo.
            </p>

            <div class="xlx-install-benefits">
                <span><i></i>Acesso direto pela tela inicial</span>
                <span><i></i>Painel em uma janela própria</span>
                <span><i></i>Mesmo monitor ao vivo do site</span>
            </div>

            <div id="xlxIosSteps" class="xlx-ios-steps">
                No Safari, toque no botão <b>Compartilhar</b>
                e depois em <b>Adicionar à Tela de Início</b>.
            </div>
        </div>

        <div class="xlx-install-actions">
            <button
                id="xlxInstallDecline"
                class="xlx-install-button secondary"
                type="button"
            >
                Agora não
            </button>

            <button
                id="xlxInstallAccept"
                class="xlx-install-button primary"
                type="button"
            >
                Instalar
            </button>
        </div>
    </div>
</div>
<!-- /XLX026 INSTALL APP V33 -->
<script src="assets/install-app.js?v=33"></script><script src="assets/ham-weather-widget.js?v=perf11_20260809_001410" defer></script>
<!-- XLX026_HAM_NEWS_V1 JS -->
<script src="/assets/ham-news-widget.js?v=1" defer></script>


<!-- XLX026_MOBILE_MENU_V4_JS -->
<script src="assets/mobile-menu-v4.js?v=20260807_022733"></script>

<!-- XLX026_HISTORY_SOUND_MENU_V1 JS -->
<script src="assets/history-sound-menu-v1.js?v=20260807_025428"></script>

<!-- XLX026_HEADER_UNIFICADO_V1 JS -->
<script src="assets/header-unificado-v1.js?v=20260807_032449"></script>

<script src="assets/ao-vivo-tx-embed-v5.js?v=20260809_011147" defer></script>
<?php if ($page === 'certificado'): ?>
<script src="assets/vendor/qrcode.min.js?v=1"></script>
<script src="assets/certificado.js?v=20260811_PREMIUM_A4_02"></script>
<?php endif; ?>
<?php if ($page === 'digital-lab'): ?><script src="assets/digital-lab.js?v=20260810_DLAB_V1"></script><?php endif; ?>
<!-- XLX026_CERT_EVENT_ALERT_V1_JS -->
<script src="assets/cert-event-alert-v1.js?v=20260811_04" defer></script>
<!-- XLX026-A11Y-JS -->
<script src="assets/xlx026-accessibility.js?v=a11y3" defer></script>
<!-- /XLX026-A11Y-JS -->

<!-- XLX026_REMOVER_SOMENTE_BIP_MENU_START -->
<style id="xlx026-remove-bip-menu-style">
/* Oculta somente o controle Bip no menu superior. */
html body[data-page] .universal-nav .xlx026-universal-bip,
html body[data-page] .universal-nav .xlx026-menu-sound-control {
    display: none !important;
}
</style>
<!-- XLX026_REMOVER_SOMENTE_BIP_MENU_END -->

<?php if ($page === 'simulado-anatel'): ?>
<!-- XLX026_SIMULADO_V4_JS -->
<script src="/assets/simulado-anatel-questions.js?v=20260815_062228"></script>
<script src="/assets/simulado-anatel-engine.js?v=20260815_062228"></script>
<script src="/assets/simulado-anatel.js?v=20260815_062228"></script>
<!-- /XLX026_SIMULADO_V4_JS -->
<?php endif; ?>
</body></html>
