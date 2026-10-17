<?php
$requestedPage = $_GET['page'] ?? 'ao-vivo';
if ($requestedPage === 'noticias' || preg_match('#^/noticias(?:/|$|\?)#', (string)($_SERVER['REQUEST_URI'] ?? ''))) {
  http_response_code(404);
  header('Content-Type: text/plain; charset=UTF-8');
  echo 'Página não encontrada.';
  exit;
}
$page = $requestedPage;
// XLX026_MODULOS_CONECTADOS_SEPARADOS_V1
$allowed = ['ao-vivo','modulos','conectados','ranking','refletores','suporte','certificado','digital-lab','simulado-anatel'];
if (!in_array($page, $allowed, true)) $page = 'ao-vivo';
function nav_class(string $p, string $current): string { return $p === $current ? ' class="active"' : ''; }
function page_url(string $p): string {
  if ($p === 'digital-lab') return '/aprs-dprs';
  if ($p === 'simulado-anatel') return '/simulado-anatel/';
  return '/' . rawurlencode($p);
}
function asset_version(string $relative): string {
  $path = __DIR__ . '/' . ltrim($relative, '/');
  if (!is_file($path)) return '0';
  $mtime = (int)@filemtime($path);
  $size = (int)@filesize($path);
  return dechex($mtime) . '-' . dechex($size);
}
function render_nav(string $page): string {
  $items = [
    'ao-vivo' => 'Ao vivo',
    'modulos' => 'Módulos',
    'conectados' => 'Conectados',
    'suporte' => 'Suporte',
    'digital-lab' => 'APRS / D-PRS',
    'ranking' => 'Ranking',
    'certificado' => 'Certificado',
    'simulado-anatel' => 'Simulado ANATEL',
    'refletores' => 'Lista de refletores XLX',
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
 'certificado'=>['title'=>'Certificado de Participação — XLX026 Brasil','description'=>'Gere e valide certificados oficiais de participação registrada no refletor XLX026 Brasil.'],
 'suporte'=>['title'=>'Suporte e tutoriais — XLX026 Brasil','description'=>'Tutoriais e orientações para conexão ao XLX026 Brasil por D-STAR, DMR e C4FM/YSF.'],
 'simulado-anatel'=>['title'=>'Simulado ANATEL 2026 para Radioamador | XLX026 Brasil','description'=>'Simulação educacional independente em formato Certo ou Errado, com correção comentada, base normativa e fontes oficiais após as respostas.'],
];
/* XLX026_SEO_AI_BUSCADORES_V2_META */
$xlx026SeoV2 = [
 'ao-vivo'=>['title'=>'XLX026 Brasil ao vivo | D-STAR, DMR e C4FM/YSF','description'=>'Monitor ao vivo do XLX026 Brasil com transmissões, indicativos, hotspot ou repetidora, cidade, protocolo, módulo, horário e tempo de TX.'],
 'modulos'=>['title'=>'Módulos A–E | XLX026 Brasil','description'=>'Consulte os módulos A–E do XLX026 Brasil, suas funções, protocolos, identificações de acesso e quantidade de estações conectadas.'],
 'conectados'=>['title'=>'Estações conectadas | XLX026 Brasil','description'=>'Veja em tempo real as estações conectadas ao XLX026 Brasil por indicativo, localização, protocolo, módulo e tempo de conexão.'],
 'digital-lab'=>['title'=>'APRS e D-PRS no XLX026 | Beacons, GPS-A e módulo B','description'=>'Laboratório APRS/D-PRS do XLX026 Brasil com beacons, GPS-A, APRS-IS, mensagens e recursos de dados associados ao módulo B.'],
 'ranking'=>['title'=>'Ranking e estatísticas de atividade | XLX026 Brasil','description'=>'Estatísticas do XLX026 por transmissões, tempo no ar, atividade, horários, módulos e protocolos, com distinção entre conexão e TX.'],
 'certificado'=>['title'=>'Certificado de participação | XLX026 Brasil','description'=>'Gere e valide certificados vinculados a participação registrada em atividades do XLX026 Brasil. Não substitui documentação da ANATEL.'],
 'refletores'=>['title'=>'Lista de refletores XLX | Diretório atualizado no XLX026','description'=>'Consulte o diretório de refletores da rede XLX com identificação, país, status e descrição. A lista não implica administração pelo XLX026.'],
 'suporte'=>['title'=>'Suporte XLX026 | DMR, D-STAR, C4FM/YSF, Pi-Star e WPSD','description'=>'Central de suporte do XLX026 com tutoriais, vídeos, downloads e referências para DMR, D-STAR, C4FM/YSF, hotspots, Pi-Star e WPSD.'],
 'simulado'=>['title'=>'Simulado ANATEL 2026 para Radioamador | XLX026 Brasil','description'=>'Simulado educacional e não oficial para estudo do Serviço de Radioamador, com conteúdo baseado em normas e fontes oficiais vigentes.'],
 'simulado-anatel'=>['title'=>'Simulado ANATEL 2026 para Radioamador | XLX026 Brasil','description'=>'Simulado educacional e não oficial para estudo do Serviço de Radioamador, com conteúdo baseado em normas e fontes oficiais vigentes.'],
];
if (isset($xlx026SeoV2[$page])) { $seo[$page] = $xlx026SeoV2[$page]; }
/* /XLX026_SEO_AI_BUSCADORES_V2_META */
$meta = $seo[$page];
$canonical = $page === 'digital-lab'
  ? 'https://xlx026.net/aprs-dprs'
  : 'https://xlx026.net/' . ($page === 'ao-vivo' ? '' : '?page=' . rawurlencode($page));
/* XLX026_SEO_AI_BUSCADORES_V2_CANONICAL */
$xlx026CanonicalV2 = [
 'ao-vivo' => 'https://xlx026.net/ao-vivo',
 'modulos' => 'https://xlx026.net/modulos',
 'conectados' => 'https://xlx026.net/conectados',
 'digital-lab' => 'https://xlx026.net/aprs-dprs',
 'aprs-dprs' => 'https://xlx026.net/aprs-dprs',
 'ranking' => 'https://xlx026.net/ranking',
 'certificado' => 'https://xlx026.net/certificado',
 'refletores' => 'https://xlx026.net/refletores',
 'suporte' => 'https://xlx026.net/suporte',
 'simulado' => 'https://xlx026.net/simulado-anatel/',
 'simulado-anatel' => 'https://xlx026.net/simulado-anatel/',
];
if (isset($xlx026CanonicalV2[$page])) { $canonical = $xlx026CanonicalV2[$page]; }
/* /XLX026_SEO_AI_BUSCADORES_V2_CANONICAL */
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
<meta property="og:url" content="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>"><meta property="og:image" content="https://xlx026.net/assets/logo-xlx026.jpeg">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:image" content="https://xlx026.net/assets/logo-xlx026.jpeg">
<link rel="icon" href="favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png"><link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png"><link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png"><link rel="manifest" href="site.webmanifest">
<title><?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/app.css?v=<?=asset_version('assets/app.css')?>"><link rel="stylesheet" href="assets/header-hotfix.css?v=1"><?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/mtr.css?v=<?=asset_version('assets/mtr.css')?>"><?php endif; ?>
<script type="application/ld+json"><?=json_encode(['@context'=>'https://schema.org','@type'=>'WebSite','name'=>'XLX026 Brasil','url'=>'https://xlx026.net/','description'=>' para radioamadores com D-STAR, DMR e C4FM/YSF.','inLanguage'=>'pt-BR','image'=>'https://xlx026.net/assets/logo-xlx026.jpeg'], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?></script><?php if ($page === 'suporte'): ?><link rel="stylesheet" href="assets/support-native.css?v=YSF_QUICK_CONNECT_V1_20260907"><?php endif; ?><link rel="stylesheet" href="assets/install-app.css?v=33"><link rel="stylesheet" href="assets/offline-neon.css?v=20260806_103404"> <link rel="stylesheet" href="assets/ham-weather-widget.css?v=3">

<!-- XLX026_HAM_NEWS_V1 CSS -->


<!-- XLX026_MOBILE_MENU_V4_CSS -->
<link rel="stylesheet" href="assets/mobile-menu-v4.css?v=20260807_023247">
<!-- XLX026_AO_VIVO_CLEAN_V1_CSS -->
<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/ao-vivo-clean-v1.css?v=20260807_024051"><?php endif; ?>

<!-- XLX026_HISTORY_SOUND_MENU_V1 CSS -->
<link rel="stylesheet" href="assets/history-sound-menu-v1.css?v=20260807_025428">

<!-- XLX026_HISTORY_MOBILE_FIT_V2 -->
<link rel="stylesheet" href="assets/history-mobile-fit-v2.css?v=20260807_031008">

<!-- XLX026_TABLE_ROW_HOVER_V1 -->
<link rel="stylesheet" href="assets/table-row-hover-v1.css?v=20260807_031841">

<!-- XLX026_HEADER_UNIFICADO_V1 CSS -->
<link rel="stylesheet" href="assets/header-unificado-v1.css?v=20260807_032449">
<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/ao-vivo-core-bundle-v1.css?v=AO_VIVO_CSS_BUNDLE_V1_20260907"><?php endif; ?>








<!-- XLX026_HEADER_NEON_FINETUNE_V1 -->
<link rel="stylesheet" href="assets/header-neon-finetune-v1.css?v=20260809_020223">
<?php if ($page === 'certificado'): ?>
<link rel="stylesheet" href="assets/certificado.css?v=20260809_01">
<?php endif; ?>
<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/ao-vivo-final-bundle-v1.css?v=<?=asset_version('assets/ao-vivo-final-bundle-v1.css')?>"><?php endif; ?>
<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/ai-monitor-v1.css?v=<?=asset_version('assets/ai-monitor-v1.css')?>"><?php endif; ?>
<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/qrz-tx-photo-v1.css?v=<?=asset_version('assets/qrz-tx-photo-v1.css')?>"><?php endif; ?>



<link rel="stylesheet" href="assets/atividade-24h-conectados-v1.css?v=STATUS_LINK_V15B_20260906_220135">
<?php if ($page === 'digital-lab'): ?><link rel="stylesheet" href="assets/digital-lab.css?v=20260810_DLAB_V1"><?php endif; ?>
<?php if ($page === 'modulos'): ?><link rel="stylesheet" href="assets/module-capabilities-v1.css?v=MODULOS_TABLE_PRO_V6_20260908"><?php endif; ?>
<!-- XLX026_CERT_EVENT_ALERT_V1_CSS -->
<link rel="stylesheet" href="assets/cert-event-alert-v1.css?v=20260811_02">
<!-- XLX026-A11Y-CSS -->
<link rel="stylesheet" href="assets/xlx026-accessibility.css?v=A11Y_AUDIO_V5E_20260823_143453">
<!-- /XLX026-A11Y-CSS -->
<!-- XLX026_STANDBY_DENTRO_BOX_V3 -->
<link rel="stylesheet" href="assets/standby-mensagens-v3.css?v=20260814_091215">

<?php if ($page === 'simulado-anatel'): ?>
<!-- XLX026_SIMULADO_V4_CSS -->
<link rel="stylesheet" href="/assets/simulado-anatel.css?v=20260815_062228">
<!-- /XLX026_SIMULADO_V4_CSS -->
<?php endif; ?>

<?php if ($page === 'refletores'): ?>
<link rel="stylesheet" href="assets/refletores-completo-v2.css?v=REFLETORES_WIDTH_1240_V1_20260907">
<?php endif; ?>

<!-- XLX026_HEADER_BRASIL_NEON_FIXED_V2_CSS -->
<link rel="stylesheet" href="/assets/header-brasil-neon-fixed-v2.css?v=20260822_033902">
<!-- /XLX026_HEADER_BRASIL_NEON_FIXED_V2_CSS -->

<!-- XLX026_HEADER_BRASIL_REFINO_V3_CSS -->
<link rel="stylesheet" href="/assets/header-brasil-refino-v3.css?v=20260822_034550">
<!-- /XLX026_HEADER_BRASIL_REFINO_V3_CSS -->

<!-- XLX026_HEADER_HORIZONTAL_RESPONSIVO_V4_CSS -->
<link rel="stylesheet" href="/assets/header-horizontal-responsivo-v4.css?v=20260822_035650">
<!-- /XLX026_HEADER_HORIZONTAL_RESPONSIVO_V4_CSS -->

<!-- XLX026_MENU_BREAKPOINT_FIX_V1_CSS -->
<link rel="stylesheet" href="/assets/header-menu-breakpoint-fix-v1.css?v=20260908_1401">
<!-- /XLX026_MENU_BREAKPOINT_FIX_V1_CSS -->

<!-- XLX026_A11Y_COMPACT_V1_CSS -->
<link rel="stylesheet" href="/assets/xlx026-accessibility-compact-v1.css?v=20260823_144035">
<!-- /XLX026_A11Y_COMPACT_V1_CSS -->





<!-- XLX026_SEO_AI_BUSCADORES_V2_HEAD -->
<meta name="application-name" content="XLX026 Brasil">
<link rel="alternate" type="application/json" href="/ai-context.json" title="XLX026 AI context">
<link rel="alternate" type="text/plain" href="/llms.txt" title="XLX026 LLM context">
<link rel="stylesheet" href="/assets/seo-ai-context.css?v=SEO_AI_BUSCADORES_V2R_20260822_043348">
<link rel="stylesheet" href="/assets/grid-text-wrap-v1.css?v=LAYOUT_WIDTH_1240_V1_20260907">
<link rel="stylesheet" href="/assets/mobile-visual-v1.css?v=<?=asset_version('assets/mobile-visual-v1.css')?>">
<?php require __DIR__ . '/seo-ai-structured.php'; ?>
<!-- /XLX026_SEO_AI_BUSCADORES_V2_HEAD -->
</head>
<body data-page="<?=htmlspecialchars($page, ENT_QUOTES, 'UTF-8')?>">
<main>
<section class="hero hero-compact universal-header" aria-label="XLX026 Brasil">
 <div class="universal-header-row">
  <a class="universal-brand" href="<?=page_url('ao-vivo')?>" aria-label="XLX026 Brasil">
   <img class="hero-logo" src="assets/logo-xlx026.jpeg" alt="XLX026 Brasil — D-STAR, DMR e C4FM" width="112" height="112">
  </a>

  <div class="universal-copy">
   <h1><span class="xlx026-brasil-title" data-title="XLX026 Brasil"><span class="xlx026-title-code">XLX026</span> <span class="xlx026-title-country">Brasil</span></span></h1>

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

 <!-- XLX026_A11Y_HEADER_V5E -->
 <nav class="universal-nav" aria-label="Menu principal">
  <?=render_nav($page)?>
  <a href="#acessibilidade"
     class="xlx-a11y-menu-icon"
     aria-label="Abrir acessibilidade"
     title="Acessibilidade">♿</a>
 </nav>

 <button class="xlx-a11y-mobile-icon"
         type="button"
         aria-label="Abrir acessibilidade"
         title="Acessibilidade">♿</button>

 <button class="menu-toggle"
         type="button"
         aria-label="Abrir menu"
         aria-expanded="false">☰</button>
 <!-- /XLX026_A11Y_HEADER_V5E -->
</section>
<?php if ($page === 'ao-vivo'): ?>
 <section class="dashboard-layout">
   <aside class="live-widget"><div class="widget-heading"><div><p class="eyebrow">MONITOR AO VIVO</p><h2>Transmissões</h2></div><span id="widgetCount">Standby</span></div><div class="live-summary-bar" aria-label="Resumo do monitor ao vivo"><span class="live-summary-item live-summary-connected"><b id="headerConnected">0</b><small>conectados</small></span><span class="live-summary-item live-summary-active"><b id="headerActive">0</b><small>TX ativa</small></span></div><div id="moduleGrid" class="module-grid widget-grid"></div></aside>
 <div class="dashboard-main panel compact-panel">
   <div class="section-title panel-title"><div><p class="eyebrow">ÚLTIMAS ATIVIDADES</p><h2 id="historyPeriodTitle" class="history-title-connected-size">Atividade das últimas 24 horas</h2></div><span id="historyCoverageNote" class="table-note">Todos os indicativos</span></div>
   <div class="table-wrap"><table class="home-history"><thead><tr><th>Nº</th><th>País</th><th>Status</th><th>Indicativo</th><th>Nome</th><th>Gateway / Repetidora</th><th>Cidade</th><th>Protocolo</th><th>Módulo</th><th>Horário TX</th><th>Tempo de TX</th></tr></thead><tbody id="historyRows"></tbody></table></div>
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
<?php elseif ($page === 'digital-lab'): ?>
 <?php require __DIR__ . '/digital-lab-native.php'; ?>
<?php elseif ($page === 'modulos'): ?>
 <!-- XLX026_MODULOS_TABELA_FINAL_V7 -->
<section class="page-head">
  <span class="eyebrow">ESTRUTURA DO REFLETOR</span>
  <h1>Módulos A–E</h1>
  <p>Identificação, função, protocolos habilitados, acesso e quantidade de estações conectadas em cada módulo.</p>
</section>

<section class="panel module-access-panel">
  <div class="section-head">
    <div>
      <h2>Protocolos por módulo</h2>
      <p class="sub">Cada módulo pode ter uso definido pelo administrador. Os identificadores abaixo permanecem visíveis como referência completa de acesso.</p>
    </div>
  </div>
  <div class="table-wrap">
    <table class="module-access-table module-access-table-v7">
      <thead>
        <tr>
          <th rowspan="3">Módulo</th>
          <th rowspan="3">Função</th>
          <th rowspan="3">Protocolos habilitados</th>
          <th rowspan="3">Estações conectadas</th>
          <th colspan="6">D-STAR</th>
          <th rowspan="3">DMR<br><small>TG</small></th>
          <th rowspan="3">C4FM / YSF<br><small>DG-ID</small></th>
        </tr>
        <tr>
          <th colspan="2">DPlus (REF)</th>
          <th colspan="2">DExtra (XRF)</th>
          <th colspan="2">DCS (DCS/XLX)</th>
        </tr>
        <tr class="module-access-subhead">
          <th>URCALL</th><th>DTMF</th>
          <th>URCALL</th><th>DTMF</th>
          <th>URCALL</th><th>DTMF</th>
        </tr>
      </thead>
      <tbody>
        <tr><td><strong>A</strong></td><td>Imagens</td><td class="module-protocol-text">D-STAR</td><td id="moduleCountA">0</td><td>REF026AL</td><td>*26A</td><td>XRF026AL</td><td>B26A</td><td>DCS026AL</td><td>D26A</td><td>4001</td><td>10</td></tr>
        <tr><td><strong>B</strong></td><td>APRS / D-PRS</td><td class="module-protocol-text">D-STAR dados</td><td id="moduleCountB">0</td><td>REF026BL</td><td>*26B</td><td>XRF026BL</td><td>B26B</td><td>DCS026BL</td><td>D26B</td><td>4002</td><td>11</td></tr>
        <tr><td><strong>C</strong></td><td>Voz digital</td><td class="module-protocol-text">DMR / C4FM / YSF</td><td id="moduleCountC">0</td><td>REF026CL</td><td>*26C</td><td>XRF026CL</td><td>B26C</td><td>DCS026CL</td><td>D26C</td><td>4003</td><td>12</td></tr>
        <tr><td><strong>D</strong></td><td>Voz</td><td class="module-protocol-text">D-STAR</td><td id="moduleCountD">0</td><td>REF026DL</td><td>*26D</td><td>XRF026DL</td><td>B26D</td><td>DCS026DL</td><td>D26D</td><td>4004</td><td>13</td></tr>
        <tr><td><strong>E</strong></td><td>Echo / teste</td><td class="module-protocol-text">D-STAR</td><td id="moduleCountE">0</td><td>REF026EL</td><td>*26E</td><td>XRF026EL</td><td>B26E</td><td>DCS026EL</td><td>D26E</td><td>4005</td><td>14</td></tr>
      </tbody>
    </table>
  </div>
</section>
<!-- /XLX026_MODULOS_TABELA_FINAL_V7 -->
<?php elseif ($page === 'conectados'): ?>
 <!-- XLX026_CONECTADOS_UNIFICADO_V1 -->


 <section class="page-heading heading-with-tools connected-stations-heading">
  <div>
   <p class="eyebrow">REDE ATIVA</p>
   <h2 class="connected-section-title">Estações conectadas</h2>
   <p id="connectedLabel">Carregando conexões...</p>
  </div>

  <div class="connected-filter-tools" aria-label="Filtros das estações conectadas">
   <label class="search-box connected-filter-search">
    <span>Pesquisar</span>
    <input id="connectedSearch" type="search" placeholder="Indicativo, nome ou região" autocomplete="off">
   </label>

   <label class="search-box connected-filter-select">
    <span>Módulo</span>
    <select id="connectedModuleFilter">
     <option value="">Todos</option>
     <option value="A">A</option><option value="B">B</option>
     <option value="C">C</option><option value="D">D</option>
     <option value="E">E</option>
    </select>
   </label>

   <label class="search-box connected-filter-select">
    <span>Protocolo</span>
    <select id="connectedProtocolFilter">
     <option value="">Todos</option>
    </select>
   </label>
  </div>
 </section>

 <section class="panel connected-table-panel">
  <!-- XLX026_CONECTADOS_LEGIBILIDADE_V2 -->
  <div class="table-wrap">
   <table class="connected-table">
    <thead><tr>
     <th>#</th><th>País</th><th>Indicativo</th><th>Nome</th>
     <th>Localização</th><th>Protocolo</th><th>Módulo</th>
     <th>Conectado às</th><th>Tempo conectado</th><th>Última atividade</th>
    </tr></thead>
    <tbody id="connectedRows"></tbody>
   </table>
  </div>
 </section>
<?php elseif ($page === 'certificado'): ?>
<?php require __DIR__.'/certificado-view.php'; ?>
<?php elseif ($page === 'ranking'): ?>
<!-- XLX026_RANKING_V2 -->
<?php require __DIR__.'/ranking-v2-view.php'; ?>

<?php elseif ($page === 'refletores'): ?>
 <section class="page-heading"><p class="eyebrow">REDE MUNDIAL</p><h1>Lista de refletores XLX</h1></section>
 <section class="panel embedded-panel"><div class="embedded-toolbar"><div><b>Refletores registrados</b><span>Nome, país, status e descrição.</span></div></div><div class="table-wrap"><table class="reflectors-table"><thead><tr><th>#</th><th>Refletor</th><th>País</th><th>Status</th><th>Descrição</th></tr></thead><tbody id="reflectorRows"><tr><td colspan="5">Carregando lista de refletores...</td></tr></tbody></table></div></section>
<?php else: ?>
<?php include __DIR__ . '/support-native.php'; ?>
<?php endif; ?>




<!-- XLX026_SEO_AI_BUSCADORES_V2_INCLUDE -->
<?php require __DIR__ . '/seo-ai-context.php'; ?>
<!-- /XLX026_SEO_AI_BUSCADORES_V2_INCLUDE -->
</main>
<footer><div><a class="brand footer-brand" href="<?=page_url('ao-vivo')?>"><img class="brand-logo" src="assets/logo-xlx026.jpeg" alt="Logotipo XLX026 Brasil"><span><b>XLX026</b><small>BRASIL</small></span></a></div><div class="footer-links"><a href="<?=page_url('ao-vivo')?>">Ao vivo</a><a href="<?=page_url('digital-lab')?>">APRS / D-PRS</a><a href="<?=page_url('conectados')?>">Conectados</a><a href="<?=page_url('ranking')?>">Ranking</a><a href="<?=page_url('suporte')?>">Suporte</a></div><small class="footer-final-line"><a href="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard" target="_blank" rel="noopener noreferrer"><strong>Painel XLX Modern v1.1.0</strong></a><span class="footer-separator"> · </span><a href="https://github.com/PU2PNY/XLX-Modern-Installer" target="_blank" rel="noopener noreferrer"><strong>Instalador v2.6.0</strong></a><span class="footer-separator"> · </span><span>Desenvolvido por <a href="https://paginacertadigital.com.br/" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span></small></footer>
<div id="toastStack" class="toast-stack"></div><?php if ($page === 'suporte'): ?><script src="assets/support-native.js?v=22"></script><?php endif; ?><?php if ($page === 'ao-vivo'): ?><script>window.XLX026_LIVE_CORE_V2=true;</script><script src="assets/mtr.js?v=<?=asset_version('assets/mtr.js')?>"></script><?php endif; ?><script src="assets/app.js?v=<?=asset_version('assets/app.js')?>"></script><?php if ($page === 'ao-vivo'): ?><script src="assets/live-core-v2-client.js?v=<?=asset_version('assets/live-core-v2-client.js')?>"></script><?php endif; ?><?php if ($page === 'ao-vivo'): ?><script src="assets/helix-shadow-monitor-v1.js?v=<?=asset_version('assets/helix-shadow-monitor-v1.js')?>"></script><?php endif; ?>


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


<!-- XLX026_MOBILE_MENU_V4_JS -->
<script src="assets/mobile-menu-v4.js?v=20260807_022733"></script>

<!-- XLX026_HISTORY_SOUND_MENU_V1 JS -->
<?php if ($page === 'ao-vivo'): ?><script src="assets/history-sound-menu-v1.js?v=<?=asset_version('assets/history-sound-menu-v1.js')?>"></script><?php endif; ?>

<!-- XLX026_HEADER_UNIFICADO_V1 JS -->
<script src="assets/header-unificado-v1.js?v=20260807_032449"></script>

<?php if ($page === 'ao-vivo'): ?><script src="assets/ao-vivo-tx-embed-v5.js?v=20260809_011147" defer></script><?php endif; ?>
<?php if ($page === 'certificado'): ?>
<script src="assets/vendor/qrcode.min.js?v=1"></script>
<script src="assets/certificado.js?v=20260827_SELO_ESPECIAL_V6_PRO"></script>
<?php endif; ?>
<?php if ($page === 'digital-lab'): ?><script src="assets/digital-lab.js?v=DMR_GPS_LABELS_V1_20260907"></script><?php endif; ?>
<!-- XLX026_CERT_EVENT_ALERT_V1_JS -->
<script src="assets/cert-event-alert-v1.js?v=CERT_ALERT_FIX_ISCERT_20260907" defer></script>
<!-- XLX026-A11Y-JS -->
<script src="assets/xlx026-accessibility.js?v=A11Y_CLICK_V6_20260908_1605" defer></script>
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
<script src="/assets/simulado-anatel-engine.js?v=20260929_percent1"></script>
<script src="/assets/simulado-anatel.js?v=20260815_062228"></script>
<!-- /XLX026_SIMULADO_V4_JS -->
<?php endif; ?>

<!-- XLX026_HEADER_BRASIL_NEON_FIXED_V2_JS -->
<script src="/assets/header-brasil-neon-fixed-v2.js?v=20260822_033902"></script>
<!-- /XLX026_HEADER_BRASIL_NEON_FIXED_V2_JS -->

</body></html>
