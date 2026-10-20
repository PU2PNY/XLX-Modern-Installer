<?php
$page = $_GET['page'] ?? 'ao-vivo';
$allowed = ['ao-vivo','modulos','conectados','ranking','refletores','digital-lab','certificado'];
if (!in_array($page, $allowed, true)) $page = 'ao-vivo';
$authorizedPage = in_array($page, ['ao-vivo','modulos','conectados','ranking'], true);
$site = is_file(__DIR__ . '/config/site.php') ? require __DIR__ . '/config/site.php' : [];
$moduleCount = max(1, min(26, (int)($site['radio']['module_count'] ?? 5)));
$moduleRange = 'A–' . chr(64 + $moduleCount);
function nav_class(string $p, string $current): string { return $p === $current ? ' class="active"' : ''; }
function page_url(string $p): string {
  if ($p === 'digital-lab') return '/aprs-dprs';
  return '/' . rawurlencode($p);
}
function render_nav(string $page): string {
  $items = [
    'ao-vivo' => 'Ao vivo',
    'modulos' => 'Módulos',
    'conectados' => 'Conectados',
    'digital-lab' => 'APRS / D-PRS',
    'certificado' => 'Certificado',
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
 'refletores'=>['title'=>'Lista de refletores XLX — {{REFLECTOR_NAME}}','description'=>'Lista atualizada de refletores XLX registrados, com país, status e descrição.'],
 'digital-lab'=>['title'=>'APRS / D-PRS — {{REFLECTOR_NAME}}','description'=>'Digital Lab nativo APRS/D-PRS com mensagens, GPS, cadastro e recuperação de acesso.'],
 'certificado'=>['title'=>'Certificado — {{REFLECTOR_NAME}}','description'=>'Emissão e validação pública de certificados com QR Code verificável.']
];
$meta = $seo[$page];
$canonical = 'https://{{REFLECTOR_DOMAIN}}' . page_url($page);
?>
<!doctype html>
<html lang="pt-BR"><head>
<script id="xlxmodernLegacyMobileGateV12">
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
<meta property="og:type" content="website"><meta property="og:locale" content="pt_BR"><meta property="og:site_name" content="{{REFLECTOR_NAME}}">
<meta property="og:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta property="og:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta property="og:url" content="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>"><meta property="og:image" content="https://{{REFLECTOR_DOMAIN}}/assets/logo-{{REFLECTOR_NAME}}.svg">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:image" content="https://{{REFLECTOR_DOMAIN}}/assets/logo-{{REFLECTOR_NAME}}.svg">
<link rel="icon" href="favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png"><link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png"><link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png"><link rel="manifest" href="site.webmanifest">
<title><?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/app.css?v=20260828-xlxmodern-mirror-4">
<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/ao-vivo-core-bundle-v1.css?v=20260907"><?php endif; ?>

<?php if ($page === 'ao-vivo'): ?><link rel="stylesheet" href="assets/ao-vivo-final-bundle-v1.css?v=20260907"><link rel="stylesheet" href="assets/qrz-tx-photo-v1.css?v=20260907"><?php endif; ?>
<link rel="stylesheet" href="assets/atividade-24h-conectados-v1.css?v=3">
<?php if ($page === 'modulos'): ?><link rel="stylesheet" href="assets/module-capabilities-v1.css?v=20260907"><?php endif; ?>
<?php if ($page === 'digital-lab'): ?><link rel="stylesheet" href="assets/digital-lab.css?v=native"><link rel="stylesheet" href="assets/digital-lab-operator.css?v=native"><?php endif; ?>
<?php if ($page === 'certificado'): ?><link rel="stylesheet" href="assets/certificado.css?v=native"><?php endif; ?>
<link rel="stylesheet" href="assets/refletores-completo-v2.css?v=1">
<link rel="stylesheet" href="assets/standby-mensagens-v3.css?v=1"><link rel="stylesheet" href="assets/header-hotfix.css?v=1"><link rel="stylesheet" href="assets/mtr.css?v=5">
<script type="application/ld+json"><?=json_encode(['@context'=>'https://schema.org','@type'=>'WebSite','name'=>'{{REFLECTOR_NAME}}','url'=>'https://{{REFLECTOR_DOMAIN}}/','description'=>'Painel para radioamadores com D-STAR, DMR e C4FM/YSF.','inLanguage'=>'pt-BR','image'=>'https://{{REFLECTOR_DOMAIN}}/assets/logo-{{REFLECTOR_NAME}}.svg'], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?></script><link rel="stylesheet" href="assets/install-app.css?v=33"><link rel="stylesheet" href="assets/offline-neon.css?v=20260806_103404"> <link rel="stylesheet" href="assets/ham-weather-widget.css?v=3">

<!-- XLXMODERN_MOBILE_MENU_V4_CSS -->
<link rel="stylesheet" href="assets/mobile-menu-v4.css?v=20260807_023247">
<!-- XLXMODERN_AO_VIVO_CLEAN_V1_CSS -->
<link rel="stylesheet" href="assets/ao-vivo-clean-v1.css?v=20260807_024051">

<!-- XLXMODERN_HISTORY_SOUND_MENU_V1 CSS -->
<link rel="stylesheet" href="assets/history-sound-menu-v1.css?v=20260828_readable">

<!-- XLXMODERN_HISTORY_MOBILE_FIT_V2 -->
<link rel="stylesheet" href="assets/history-mobile-fit-v2.css?v=20260807_031008">

<!-- XLXMODERN_TABLE_ROW_HOVER_V1 -->
<link rel="stylesheet" href="assets/table-row-hover-v1.css?v=20260807_031841">

<!-- XLXMODERN_HEADER_UNIFICADO_V1 CSS -->
<link rel="stylesheet" href="assets/header-unificado-v1.css?v=20260807_032449">
<link rel="stylesheet" href="assets/header-brasil-neon-fixed-v2.css?v=1">
<link rel="stylesheet" href="assets/header-brasil-refino-v3.css?v=1">
<link rel="stylesheet" href="assets/header-horizontal-responsivo-v4.css?v=1">
<link rel="stylesheet" href="assets/header-menu-breakpoint-fix-v1.css?v=1">
<link rel="stylesheet" href="assets/xlxmodern-accessibility.css?v=1">
<link rel="stylesheet" href="assets/xlxmodern-accessibility-compact-v1.css?v=1">
<link rel="stylesheet" href="assets/mobile-visual-v1.css?v=20260908">

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
<body data-page="<?=htmlspecialchars($page, ENT_QUOTES, 'UTF-8')?>" data-reflector="{{REFLECTOR_NAME}}">
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
   <div class="table-wrap"><table class="home-history"><thead><tr><th>Nº</th><th>País</th><th>Status</th><th>Indicativo</th><th>Nome</th><th>Gateway / Repetidora</th><th>Cidade</th><th>Protocolo</th><th>Módulo</th><th>Horário TX</th><th>Tempo de TX</th></tr></thead><tbody id="historyRows"></tbody></table></div>
  </div>
 </section>
<!-- XLXMODERN HAM WEATHER WIDGET V1 -->
 <section class="hamwx-panel panel" id="hamWeatherWidget" aria-label="Clima e condições de propagação para radioamadores">
  <div class="hamwx-skeleton">Carregando clima e propagação...</div>
 </section>
<!-- /XLXMODERN HAM WEATHER WIDGET V1 -->
<?php elseif ($page === 'modulos'): ?>
 <section class="page-heading connected-modules-heading">
  <p class="eyebrow">ESTRUTURA DO REFLETOR</p>
  <h1>Módulos <?=htmlspecialchars($moduleRange, ENT_QUOTES, 'UTF-8')?></h1>
  <p>Identificação, função, protocolo, acesso e quantidade de estações conectadas em cada módulo.</p>
 </section>
 <section class="panel module-reference">
  <h2>Identificações de acesso</h2>
  <div class="table-wrap">
   <table class="module-access-table">
    <thead>
     <tr><th rowspan="2">Módulo</th><th rowspan="2">Protocolo / função</th><th rowspan="2">Estações conectadas</th><th colspan="2">DPlus (REF)</th><th colspan="2">DExtra (XRF)</th><th colspan="2">DCS (DCS/XLX)</th><th rowspan="2">DMR</th><th rowspan="2">YSF DG-ID</th></tr>
     <tr><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th></tr>
    </thead>
    <tbody id="moduleReferenceRows"></tbody>
   </table>
  </div>
 </section>
 <section id="moduleOverview" class="module-overview-grid module-page-grid"></section>
<?php elseif ($page === 'conectados'): ?>
 <section class="page-heading heading-with-tools connected-stations-heading">
  <div><p class="eyebrow">REDE ATIVA</p><h2 class="connected-section-title">Estações conectadas</h2><p id="connectedLabel">Carregando conexões...</p></div>
  <div class="connected-filter-tools" aria-label="Filtros das estações conectadas">
   <label class="search-box connected-filter-search"><span>Pesquisar</span><input id="connectedSearch" type="search" placeholder="Indicativo, nome ou região" autocomplete="off"></label>
   <label class="search-box connected-filter-select"><span>Módulo</span><select id="connectedModuleFilter"><option value="">Todos</option></select></label>
   <label class="search-box connected-filter-select"><span>Protocolo</span><select id="connectedProtocolFilter"><option value="">Todos</option></select></label>
  </div>
 </section>
 <section class="panel connected-table-panel">
  <div class="table-wrap"><table class="connected-table"><thead><tr><th>#</th><th>País</th><th>Indicativo</th><th>Nome</th><th>Localização</th><th>Protocolo</th><th>Módulo</th><th>Conectado às</th><th>Tempo conectado</th><th>Última atividade</th></tr></thead><tbody id="connectedRows"></tbody></table></div>
 </section>
<?php elseif ($page === 'digital-lab'): ?>
 <?php require __DIR__.'/digital-lab-native.php'; ?>
<?php elseif ($page === 'certificado'): ?>
 <?php require __DIR__.'/certificado-view.php'; ?>
<?php elseif ($page === 'ranking'): ?>
<!-- XLXMODERN_RANKING_V2 -->
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
 <small class="footer-final-line"><strong>XLX Modern v{{XLX_MODERN_VERSION}}</strong><span class="footer-separator">•</span><span>Desenvolvido por <a href="https://paginacertadigital.com.br/" target="_blank" rel="noopener noreferrer">paginacertadigital.com.br</a></span></small>
</footer>
<?php else: ?>
<footer><div><a class="brand footer-brand" href="<?=page_url('ao-vivo')?>"><img class="brand-logo" src="assets/logo-{{REFLECTOR_NAME}}.svg" alt="Logotipo {{REFLECTOR_NAME}}"><span><b>{{REFLECTOR_NAME}}</b></span></a><p> para a comunidade radioamadora.</p></div><div class="footer-links"><a href="<?=page_url('ao-vivo')?>">Ao vivo</a><a href="<?=page_url('conectados')?>">Conectados</a><a href="<?=page_url('ranking')?>">Ranking</a></div><small>{{REFLECTOR_NAME}} • D-STAR {{REFLECTOR_NAME}}-D • DMR: TG 6 (voz), A=4001, B=4002, C=4003… • C4FM/YSF {{YSF_ID}}</small></footer>
<?php endif; ?>
<div id="toastStack" class="toast-stack"></div><script src="assets/mtr.js?v=5"></script><script src="assets/app.js?v=20260907-production-parity"></script>
<?php if ($page === 'ao-vivo'): ?>
<script src="assets/ao-vivo-authorized-sync-v1.js?v=1"></script>
<script src="assets/ao-vivo-tx-embed-v5.js?v=1" defer></script>
<script src="assets/helix-shadow-monitor-v1.js?v=1" defer></script>
<?php endif; ?>


<!-- XLXMODERN INSTALL APP V33 -->
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
                No Safari, toque no botão Compartilhar e depois em Adicionar à Tela de Início.
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
<!-- /XLXMODERN INSTALL APP V33 -->
<script src="assets/install-app.js?v=33"></script><script src="assets/ham-weather-widget.js?v=5" defer></script>
<!-- XLXMODERN_MOBILE_MENU_V4_JS -->
<script src="assets/mobile-menu-v4.js?v=20260807_022733"></script>

<!-- XLXMODERN_HISTORY_SOUND_MENU_V1 JS -->
<script src="assets/history-sound-menu-v1.js?v=20260807_025428"></script>

<!-- XLXMODERN_HEADER_UNIFICADO_V1 JS -->
<script src="assets/header-unificado-v1.js?v=20260807_032449"></script>
<script src="assets/header-brasil-neon-fixed-v2.js?v=1"></script>
<script src="assets/xlxmodern-accessibility.js?v=1" defer></script>
<?php if ($page === 'digital-lab'): ?><script src="assets/digital-lab.js?v=native"></script><script src="assets/digital-lab-operator.js?v=native"></script><?php endif; ?>
<?php if ($page === 'certificado'): ?><script src="assets/vendor/qrcode.min.js"></script><script src="assets/certificado.js?v=native"></script><?php endif; ?>
<?php
// Optional, per-installation support link. Only XLX026 receives the project-specific default.
$whatsappSupportUrl = trim((string)($site['support']['whatsapp_group_url'] ?? ('{{REFLECTOR_NAME}}' === 'XLX026' ? 'https://chat.whatsapp.com/CwW2nKDI8sb2LtHIvyr2Ow?s=cl&p=a&iam=0' : '')));
$whatsappSupportHost = strtolower((string)parse_url($whatsappSupportUrl, PHP_URL_HOST));
if ($whatsappSupportHost !== 'chat.whatsapp.com' || strtolower((string)parse_url($whatsappSupportUrl, PHP_URL_SCHEME)) !== 'https') $whatsappSupportUrl = '';
?>
<?php if ($whatsappSupportUrl !== ''): ?>
<style>
#xlx-whatsapp-support{position:fixed;right:clamp(12px,2vw,26px);bottom:calc(18px + env(safe-area-inset-bottom,0px));z-index:1100;display:flex;align-items:flex-start;gap:4px;font-family:inherit}
#xlx-whatsapp-support .xlx-wa-link{display:flex;align-items:center;gap:10px;background:#128c47;color:#fff;text-decoration:none;border-radius:999px;padding:12px 18px 12px 13px;font-weight:700;font-size:15px;box-shadow:0 5px 18px #0005;line-height:1.25}
#xlx-whatsapp-support .xlx-wa-link:hover,#xlx-whatsapp-support .xlx-wa-link:focus-visible{background:#0d733a}
#xlx-whatsapp-support .xlx-wa-icon{width:25px;height:25px;fill:currentColor;flex:none}
#xlx-whatsapp-support .xlx-wa-close{display:grid;place-items:center;width:29px;height:29px;border:1px solid #737b86;background:#fff;color:#17212b;border-radius:50%;cursor:pointer;font-size:20px;line-height:1;padding:0;box-shadow:0 2px 9px #0003}
#xlx-whatsapp-support :focus-visible{outline:3px solid #ffd54f;outline-offset:3px}
@media(max-width:600px){#xlx-whatsapp-support{right:12px;bottom:calc(12px + env(safe-area-inset-bottom,0px))}#xlx-whatsapp-support .xlx-wa-link{padding:10px 14px 10px 11px;font-size:14px}}
</style>
<div id="xlx-whatsapp-support" role="group" aria-label="Suporte via WhatsApp">
 <a class="xlx-wa-link" href="<?=htmlspecialchars($whatsappSupportUrl, ENT_QUOTES, 'UTF-8')?>" target="_blank" rel="noopener noreferrer" aria-label="Suporte: entrar no grupo de WhatsApp">
  <svg class="xlx-wa-icon" viewBox="0 0 32 32" aria-hidden="true" focusable="false"><path d="M16 .8a15.12 15.12 0 0 0-13 22.86L.9 31l7.54-1.98A15.2 15.2 0 1 0 16 .8zm0 27.6a12.36 12.36 0 0 1-6.3-1.72l-.45-.27-4.47 1.17 1.2-4.36-.3-.46A12.42 12.42 0 1 1 16 28.4zm6.8-9.3c-.37-.18-2.2-1.08-2.54-1.2-.34-.12-.58-.18-.83.18-.24.37-.95 1.2-1.17 1.45-.21.24-.43.27-.8.09a10.1 10.1 0 0 1-3-1.86 11.2 11.2 0 0 1-2.07-2.58c-.22-.37-.02-.57.16-.75.17-.17.37-.43.55-.65.18-.21.24-.36.36-.61.12-.24.06-.46-.03-.65-.09-.18-.83-2-1.14-2.73-.3-.72-.61-.62-.83-.63h-.71c-.25 0-.65.09-.99.46-.34.37-1.3 1.27-1.3 3.09s1.33 3.58 1.52 3.83c.18.24 2.62 4 6.35 5.61.89.39 1.58.62 2.12.79.89.28 1.7.24 2.34.15.71-.11 2.2-.9 2.51-1.77.31-.88.31-1.63.22-1.78-.09-.15-.34-.24-.71-.43z"/></svg>
  <span>Suporte</span>
 </a>
 <button class="xlx-wa-close" type="button" aria-label="Fechar suporte WhatsApp" title="Fechar">×</button>
</div>
<script>
document.getElementById('xlx-whatsapp-support').querySelector('.xlx-wa-close').addEventListener('click',function(){document.getElementById('xlx-whatsapp-support').remove()});
</script>
<?php endif; ?>
</body></html>