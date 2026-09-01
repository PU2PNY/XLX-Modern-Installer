<?php
$page = $_GET['page'] ?? 'ao-vivo';
// Módulos fazem parte da página Conectados; o endereço antigo continua válido.
if ($page === 'modulos') $page = 'conectados';
$allowed = ['ao-vivo','conectados','ranking','refletores'];
if (!in_array($page, $allowed, true)) $page = 'ao-vivo';
$authorizedPage = in_array($page, ['ao-vivo','conectados','ranking'], true);
$site = is_file(__DIR__ . '/config/site.php') ? require __DIR__ . '/config/site.php' : [];
$moduleCount = max(1, min(26, (int)($site['radio']['module_count'] ?? 5)));
$moduleRange = 'A–' . chr(64 + $moduleCount);
function nav_class(string $p, string $current): string { return $p === $current ? ' class="active"' : ''; }
function page_url(string $p): string { return '?page=' . rawurlencode($p); }
function render_nav(string $page): string {
  $items = [
    'ao-vivo' => 'Ao vivo',
    'conectados' => 'Conectados',
    'ranking' => 'Ranking',
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
 'ao-vivo'=>['title'=>'{{REFLECTOR_NAME}} — Painel ao vivo D-STAR, DMR e C4FM','description'=>'Acompanhe ao vivo transmissões, estações conectadas e módulos do refletor multiprotocolo {{REFLECTOR_NAME}}.'],
 'modulos'=>['title'=>'Módulos ' . $moduleRange . ' — {{REFLECTOR_NAME}}','description'=>'Consulte funções, protocolos e identificações de acesso dos módulos habilitados do refletor {{REFLECTOR_NAME}}.'],
 'conectados'=>['title'=>'Estações conectadas — {{REFLECTOR_NAME}}','description'=>'Veja em tempo real as estações conectadas ao {{REFLECTOR_NAME}}, com indicativo, protocolo, módulo e tempo de conexão.'],
 'ranking'=>['title'=>'Ranking de atividade — {{REFLECTOR_NAME}}','description'=>'Ranking recente do {{REFLECTOR_NAME}} por transmissões, tempo no ar, permanência, horários, protocolos e módulos.'],
 'refletores'=>['title'=>'Lista de refletores XLX — {{REFLECTOR_NAME}}','description'=>'Lista atualizada de refletores XLX registrados, com país, status e descrição.']
];
$meta = $seo[$page];
$canonical = 'https://{{REFLECTOR_DOMAIN}}/' . ($page === 'ao-vivo' ? '' : '?page=' . rawurlencode($page));
?>
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#06131d"><meta name="description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
<link rel="canonical" href="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>">
<meta property="og:type" content="website"><meta property="og:locale" content="pt_BR"><meta property="og:site_name" content="{{REFLECTOR_NAME}}">
<meta property="og:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta property="og:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta property="og:url" content="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>"><meta property="og:image" content="https://{{REFLECTOR_DOMAIN}}/assets/logo-{{REFLECTOR_NAME}}.svg">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:image" content="https://{{REFLECTOR_DOMAIN}}/assets/logo-{{REFLECTOR_NAME}}.svg">
<link rel="icon" href="favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png"><link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png"><link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png"><link rel="manifest" href="site.webmanifest">
<title><?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/app.css?v=20260828-xlx026-mirror-4">
<link rel="stylesheet" href="assets/ao-vivo-boxes-v2.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-boxes-v31-radar.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-cirurgico-v1.css?v=1">
<link rel="stylesheet" href="assets/atividade-24h-conectados-v1.css?v=3">
<link rel="stylesheet" href="assets/refletores-completo-v2.css?v=1">
<link rel="stylesheet" href="assets/standby-mensagens-v3.css?v=1"><link rel="stylesheet" href="assets/header-hotfix.css?v=1"><link rel="stylesheet" href="assets/mtr.css?v=5">
<script type="application/ld+json"><?=json_encode(['@context'=>'https://schema.org','@type'=>'WebSite','name'=>'{{REFLECTOR_NAME}}','url'=>'https://{{REFLECTOR_DOMAIN}}/','description'=>' para radioamadores com D-STAR, DMR e C4FM/YSF.','inLanguage'=>'pt-BR','image'=>'https://{{REFLECTOR_DOMAIN}}/assets/logo-{{REFLECTOR_NAME}}.svg'], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?></script><link rel="stylesheet" href="assets/install-app.css?v=33"><link rel="stylesheet" href="assets/offline-neon.css?v=20260806_103404"> <link rel="stylesheet" href="assets/ham-weather-widget.css?v=3">

<!-- XLX026_MOBILE_MENU_V4_CSS -->
<link rel="stylesheet" href="assets/mobile-menu-v4.css?v=20260807_023247">
<!-- XLX026_AO_VIVO_CLEAN_V1_CSS -->
<link rel="stylesheet" href="assets/ao-vivo-clean-v1.css?v=20260807_024051">

<!-- XLX026_HISTORY_SOUND_MENU_V1 CSS -->
<link rel="stylesheet" href="assets/history-sound-menu-v1.css?v=20260828_readable">

<!-- XLX026_HISTORY_MOBILE_FIT_V2 -->
<link rel="stylesheet" href="assets/history-mobile-fit-v2.css?v=20260807_031008">

<!-- XLX026_TABLE_ROW_HOVER_V1 -->
<link rel="stylesheet" href="assets/table-row-hover-v1.css?v=20260807_031841">

<!-- XLX026_HEADER_UNIFICADO_V1 CSS -->
<link rel="stylesheet" href="assets/header-unificado-v1.css?v=20260807_032449">
<link rel="stylesheet" href="assets/header-brasil-neon-fixed-v2.css?v=1">
<link rel="stylesheet" href="assets/header-brasil-refino-v3.css?v=1">
<link rel="stylesheet" href="assets/header-horizontal-responsivo-v4.css?v=1">
<link rel="stylesheet" href="assets/header-menu-breakpoint-fix-v1.css?v=1">
<link rel="stylesheet" href="assets/xlx026-accessibility.css?v=1">
<link rel="stylesheet" href="assets/xlx026-accessibility-compact-v1.css?v=1">

<?php if ($authorizedPage): ?>
<link rel="stylesheet" href="assets/authorized-pages-v1.css?v=1">
<link rel="stylesheet" href="assets/header-neon-finetune-v1.css?v=1">
<?php endif; ?>

<?php if ($page === 'ao-vivo'): ?>
<link rel="stylesheet" href="assets/ao-vivo-top-layout-v2.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-compact-v3.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-tx-embed-v5.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-tx-finetune-v6.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-visual-fix-v7.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-gif-scale-v8.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-gif-position-v9.css?v=1">
<link rel="stylesheet" href="assets/ao-vivo-gif-anchor-v12.css?v=1">
<?php endif; ?>
</head>
<body data-page="<?=htmlspecialchars($page, ENT_QUOTES, 'UTF-8')?>">
<main>
<section class="hero hero-compact universal-header" aria-label="{{REFLECTOR_NAME}}">
 <div class="universal-header-row">
  <a class="universal-brand" href="<?=page_url('ao-vivo')?>" aria-label="{{REFLECTOR_NAME}}">
   <img class="hero-logo" src="assets/logo-{{REFLECTOR_NAME}}.svg" alt="{{REFLECTOR_NAME}} — D-STAR, DMR e C4FM" width="112" height="112">
  </a>

  <div class="universal-copy">
   <h1><span>{{REFLECTOR_NAME}}</span></h1>

   <div class="access-strip access-strip-compact" aria-label="Acessos do servidor">
    <span><b>D-STAR</b> {{REFLECTOR_NAME}}-D</span>
    <span><b>DMR</b> TG 6 (voz) • módulo A=4001, B=4002, C=4003…</span>
    <span><b>C4FM/YSF</b> {{REFLECTOR_NAME}} • YSF{{YSF_ID}}</span>
   </div>
  </div>

  <div class="live-pill universal-live-pill" aria-live="polite">
   <i></i>
   <span id="syncState">Conectando</span>
  </div>
 </div>

 <nav class="universal-nav" aria-label="Menu principal">
  <?=render_nav($page)?>
  <a href="#acessibilidade" class="xlx-a11y-menu-icon" aria-label="Abrir acessibilidade" title="Acessibilidade">♿</a>
 </nav>
 <button class="xlx-a11y-mobile-icon" type="button" aria-label="Abrir acessibilidade" title="Acessibilidade">♿</button>
 <button class="menu-toggle" type="button" aria-label="Abrir menu" aria-expanded="false">☰</button>
</section>
<?php if ($page === 'ao-vivo'): ?>
 <section class="dashboard-layout">
  <aside class="live-widget"><div class="widget-heading"><div><p class="eyebrow">MONITOR AO VIVO</p><h2>Transmissões</h2></div><span id="widgetCount">Standby</span></div><div class="live-summary-bar" aria-label="Resumo do monitor ao vivo"><span class="live-summary-item live-summary-connected"><b id="headerConnected">0</b><small>conectados</small></span><span class="live-summary-item live-summary-active"><b id="headerActive">0</b><small>TX ativa</small></span></div><div id="moduleGrid" class="module-grid widget-grid"></div></aside>
  <div class="dashboard-main panel compact-panel">
   <div class="section-title panel-title"><div><p class="eyebrow">ÚLTIMAS ATIVIDADES</p><h2>Atividade das últimas 24 horas</h2></div><span class="table-note">Todos os indicativos</span></div>
   <div class="table-wrap"><table class="home-history"><thead><tr><th>Nº</th><th>País</th><th>Status</th><th>Indicativo</th><th>Nome</th><th>Hotspot / Repetidora</th><th>Cidade</th><th>Protocolo</th><th>Módulo</th><th>Horário TX</th><th>Tempo de TX</th></tr></thead><tbody id="historyRows"></tbody></table></div>
  </div>
 </section>
<!-- XLX026 HAM WEATHER WIDGET V1 -->
 <section class="hamwx-panel panel" id="hamWeatherWidget" aria-label="Clima e condições de propagação para radioamadores">
  <div class="hamwx-skeleton">Carregando clima e propagação...</div>
 </section>
<!-- /XLX026 HAM WEATHER WIDGET V1 -->
<?php elseif ($page === 'modulos'): ?>
 <section class="page-heading"><p class="eyebrow">ESTRUTURA DO REFLETOR</p><h1>Módulos <?=htmlspecialchars($moduleRange, ENT_QUOTES, 'UTF-8')?></h1><p>Identificação, protocolo, acesso e quantidade de estações conectadas em cada módulo habilitado.</p></section>
 <section id="moduleOverview" class="module-overview-grid module-page-grid"></section>
 <section class="panel module-reference"><h2>Identificações de acesso</h2><div class="table-wrap"><table class="module-access-table"><thead><tr><th rowspan="2">Módulo</th><th rowspan="2">Protocolo / função</th><th rowspan="2">Estações conectadas</th><th colspan="2">DPlus (REF)</th><th colspan="2">DExtra (XRF)</th><th colspan="2">DCS (DCS/XLX)</th><th rowspan="2">DMR</th><th rowspan="2">YSF DG-ID</th></tr><tr><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th></tr></thead><tbody id="moduleReferenceRows"></tbody></table></div></section>
<?php elseif ($page === 'conectados'): ?>
 <section class="page-heading connected-modules-heading">
  <p class="eyebrow">ESTRUTURA DO REFLETOR</p>
  <h1>Módulos <?=htmlspecialchars($moduleRange, ENT_QUOTES, 'UTF-8')?></h1>
  <p>Identificação, função, protocolo, acesso e quantidade de estações conectadas em cada módulo.</p>
 </section>
 <section id="moduleOverview" class="module-overview-grid module-page-grid"></section>
 <section class="panel module-reference"><h2>Identificações de acesso</h2><div class="table-wrap"><table class="module-access-table"><thead><tr><th rowspan="2">Módulo</th><th rowspan="2">Protocolo / função</th><th rowspan="2">Estações conectadas</th><th colspan="2">DPlus (REF)</th><th colspan="2">DExtra (XRF)</th><th colspan="2">DCS (DCS/XLX)</th><th rowspan="2">DMR</th><th rowspan="2">YSF DG-ID</th></tr><tr><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th></tr></thead><tbody id="moduleReferenceRows"></tbody></table></div></section>
 <section class="page-heading heading-with-tools connected-stations-heading"><div><p class="eyebrow">REDE ATIVA</p><h2 class="connected-section-title">Estações conectadas</h2><p id="connectedLabel">Carregando conexões...</p></div><div class="connected-filter-tools" aria-label="Filtros das estações conectadas"><label class="search-box connected-filter-search"><span>Pesquisar</span><input id="connectedSearch" type="search" placeholder="Indicativo, nome ou região" autocomplete="off"></label><label class="search-box connected-filter-select"><span>Módulo</span><select id="connectedModuleFilter"><option value="">Todos</option></select></label><label class="search-box connected-filter-select"><span>Protocolo</span><select id="connectedProtocolFilter"><option value="">Todos</option></select></label></div></section>
 <section id="connectedCards" class="connected-cards"></section>
 <section class="panel connected-table-panel"><div class="table-wrap"><table class="connected-table"><thead><tr><th>#</th><th>País</th><th>Indicativo</th><th>Nome</th><th>Localização</th><th>Protocolo</th><th>Módulo</th><th>Conectado às</th><th>Tempo conectado</th><th>Última atividade</th></tr></thead><tbody id="connectedRows"></tbody></table></div></section>
<?php elseif ($page === 'ranking'): ?>
<!-- XLX026_RANKING_V2 -->
<?php require __DIR__.'/ranking-v2-view.php'; ?>

<?php elseif ($page === 'refletores'): ?>
 <section class="page-heading"><p class="eyebrow">REDE MUNDIAL</p><h1>Lista de refletores XLX</h1></section>
 <section class="panel embedded-panel"><div class="embedded-toolbar"><div><b>Refletores registrados</b><span>Nome, país, status e descrição.</span></div></div><div class="table-wrap"><table class="reflectors-table"><thead><tr><th>#</th><th>Refletor</th><th>País</th><th>Status</th><th>Descrição</th></tr></thead><tbody id="reflectorRows"><tr><td colspan="5">Carregando lista de refletores...</td></tr></tbody></table></div></section>
<?php endif; ?>

</main>
<?php if ($authorizedPage): ?>
<footer>
 <div><a class="brand footer-brand" href="<?=page_url('ao-vivo')?>"><img class="brand-logo" src="assets/logo-{{REFLECTOR_NAME}}.svg" alt="Logotipo {{REFLECTOR_NAME}}"><span><b>{{REFLECTOR_NAME}}</b></span></a></div>
 <div class="footer-links"><a href="<?=page_url('ao-vivo')?>">Ao vivo</a><a href="<?=page_url('conectados')?>">Conectados</a><a href="<?=page_url('ranking')?>">Ranking</a></div>
 <small class="footer-final-line"><strong>Painel XLX Modern v1.1.0</strong><span class="footer-separator">•</span><span>Desenvolvido por <a href="https://paginacertadigital.com.br/" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span></small>
</footer>
<?php else: ?>
<footer><div><a class="brand footer-brand" href="<?=page_url('ao-vivo')?>"><img class="brand-logo" src="assets/logo-{{REFLECTOR_NAME}}.svg" alt="Logotipo {{REFLECTOR_NAME}}"><span><b>{{REFLECTOR_NAME}}</b></span></a><p> para a comunidade radioamadora.</p></div><div class="footer-links"><a href="<?=page_url('ao-vivo')?>">Ao vivo</a><a href="<?=page_url('conectados')?>">Conectados</a><a href="<?=page_url('ranking')?>">Ranking</a></div><small>{{REFLECTOR_NAME}} • D-STAR {{REFLECTOR_NAME}}-D • DMR: TG 6 (voz), A=4001, B=4002, C=4003… • C4FM/YSF {{YSF_ID}}</small></footer>
<?php endif; ?>
<div id="toastStack" class="toast-stack"></div><script src="assets/mtr.js?v=5"></script><script src="assets/app.js?v=70"></script>
<?php if ($page === 'ao-vivo'): ?>
<script src="assets/ao-vivo-authorized-sync-v1.js?v=1"></script>
<script src="assets/ao-vivo-tx-embed-v5.js?v=1" defer></script>
<?php endif; ?>


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
                    Instalar {{REFLECTOR_NAME}}
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
<script src="assets/install-app.js?v=33"></script><script src="assets/ham-weather-widget.js?v=5" defer></script>
<!-- XLX026_MOBILE_MENU_V4_JS -->
<script src="assets/mobile-menu-v4.js?v=20260807_022733"></script>

<!-- XLX026_HISTORY_SOUND_MENU_V1 JS -->
<script src="assets/history-sound-menu-v1.js?v=20260807_025428"></script>

<!-- XLX026_HEADER_UNIFICADO_V1 JS -->
<script src="assets/header-unificado-v1.js?v=20260807_032449"></script>
<script src="assets/header-brasil-neon-fixed-v2.js?v=1"></script>
<script src="assets/xlx026-accessibility.js?v=1" defer></script>
</body></html>