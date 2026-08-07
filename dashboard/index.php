<?php
declare(strict_types=1);

$config = require __DIR__ . '/config.php';
$page = $_GET['page'] ?? 'ao-vivo';
$allowed = ['ao-vivo','conectados','modulos','ranking','refletores'];
if (!in_array($page, $allowed, true)) $page = 'ao-vivo';

function h(mixed $value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}
function page_url(string $p): string { return '?page=' . rawurlencode($p); }
function render_nav(string $page): string {
    $items = [
        'ao-vivo' => 'Ao vivo',
        'conectados' => 'Conectados',
        'modulos' => 'Módulos A–E',
        'ranking' => 'Ranking',
        'refletores' => 'Lista de refletores XLX',
    ];
    $html = '';
    foreach ($items as $slug => $label) {
        $cls = $slug === $page ? ' class="active"' : '';
        $html .= '<a' . $cls . ' href="' . h(page_url($slug)) . '">' . h($label) . '</a>';
    }
    return $html;
}

$serverName = trim((string)($config['server_name'] ?? 'XLX')) ?: 'XLX';
$domain = trim((string)($config['domain'] ?? ''));
$country = trim((string)($config['country'] ?? ''));
$locale = trim((string)($config['locale'] ?? 'pt-BR')) ?: 'pt-BR';
$ysfId = trim((string)($config['ysf_id'] ?? ''));
$dmrTg = trim((string)($config['dmr_tg'] ?? ''));
$dmrRadioTg = trim((string)($config['dmr_radio_tg'] ?? ''));

$seo = [
    'ao-vivo'=>['title'=>$serverName.' — Painel ao vivo D-STAR, DMR e C4FM','description'=>'Acompanhe ao vivo transmissões, estações conectadas e módulos do refletor multiprotocolo '.$serverName.'.'],
    'modulos'=>['title'=>'Módulos A–E — '.$serverName,'description'=>'Consulte funções, protocolos e identificações de acesso dos módulos do refletor '.$serverName.'.'],
    'conectados'=>['title'=>'Estações conectadas — '.$serverName,'description'=>'Veja em tempo real as estações conectadas ao '.$serverName.', com indicativo, protocolo, módulo e tempo de conexão.'],
    'ranking'=>['title'=>'Ranking de atividade — '.$serverName,'description'=>'Ranking do '.$serverName.' por transmissões, tempo no ar, permanência, horários e módulos.'],
    'refletores'=>['title'=>'Lista de refletores XLX — '.$serverName,'description'=>'Lista atualizada de refletores XLX registrados, com país, status e descrição.'],
];
$meta = $seo[$page];
$baseUrl = $domain !== '' && $domain !== 'example.invalid' ? 'https://' . $domain . '/' : '';
$canonical = $baseUrl !== '' ? $baseUrl . ($page === 'ao-vivo' ? '' : '?page=' . rawurlencode($page)) : '';
$ogLocale = str_replace('-', '_', $locale);
$clientConfig = ['serverName'=>$serverName,'locale'=>$locale];
?>
<!doctype html>
<html lang="<?=h($locale)?>"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#06131d"><meta name="description" content="<?=h($meta['description'])?>">
<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
<?php if ($canonical !== ''): ?><link rel="canonical" href="<?=h($canonical)?>"><?php endif; ?>
<meta property="og:type" content="website"><meta property="og:locale" content="<?=h($ogLocale)?>"><meta property="og:site_name" content="<?=h($serverName)?>">
<meta property="og:title" content="<?=h($meta['title'])?>"><meta property="og:description" content="<?=h($meta['description'])?>">
<?php if ($canonical !== ''): ?><meta property="og:url" content="<?=h($canonical)?>"><?php endif; ?>
<meta name="twitter:card" content="summary"><meta name="twitter:title" content="<?=h($meta['title'])?>"><meta name="twitter:description" content="<?=h($meta['description'])?>">
<link rel="icon" type="image/svg+xml" href="assets/logo-reflector.svg"><link rel="manifest" href="site.webmanifest">
<title><?=h($meta['title'])?></title>
<link rel="stylesheet" href="assets/app.css?v=20260807"><link rel="stylesheet" href="assets/mtr.css?v=4"><link rel="stylesheet" href="assets/install-app.css?v=33"><link rel="stylesheet" href="assets/ham-weather-widget.css?v=3">
<script type="application/ld+json"><?=json_encode(['@context'=>'https://schema.org','@type'=>'WebSite','name'=>$serverName,'url'=>$baseUrl,'description'=>'Painel para radioamadores com D-STAR, DMR e C4FM/YSF.','inLanguage'=>$locale], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?></script>
<script>window.XLX_CONFIG=<?=json_encode($clientConfig, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?>;</script>
</head>
<body data-page="<?=htmlspecialchars($page, ENT_QUOTES, 'UTF-8')?>">
<main>
<section class="hero hero-compact universal-header" aria-label="<?=h($serverName)?>">
 <div class="universal-header-row">
  <a class="universal-brand" href="<?=page_url('ao-vivo')?>" aria-label="<?=h($serverName)?>">
   <img class="hero-logo" src="assets/logo-reflector.svg" alt="<?=h($serverName)?> — D-STAR, DMR e C4FM" width="112" height="112">
  </a>

  <div class="universal-copy">
   <h1><span><?=h($serverName)?></span></h1>

   <div class="access-strip access-strip-compact" aria-label="Acessos do servidor">
    <span><b>D-STAR</b> <?=h($serverName)?></span>
    <?php if ($dmrTg !== '' || $dmrRadioTg !== ''): ?><span><b>DMR</b><?php if ($dmrRadioTg !== ''): ?> TG <?=h($dmrRadioTg)?><?php endif; ?><?php if ($dmrTg !== '' && $dmrTg !== $dmrRadioTg): ?> • TG <?=h($dmrTg)?><?php endif; ?></span><?php endif; ?>
    <?php if ($ysfId !== ''): ?><span><b>C4FM/YSF</b> YSF <?=h($ysfId)?></span><?php endif; ?>
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
  <div class="dashboard-main panel compact-panel">
   <div class="section-title panel-title"><div><p class="eyebrow">ÚLTIMAS ATIVIDADES</p><h2>Últimas transmissões</h2></div><span class="table-note">Até 30 registros</span></div>
   <div class="table-wrap"><table class="home-history"><thead><tr><th>País</th><th>Horário</th><th>Indicativo</th><th>Operador</th><th>Protocolo</th><th>Módulo</th><th>Duração</th><th>Status</th></tr></thead><tbody id="historyRows"></tbody></table></div>
  </div>
  <aside class="live-widget"><div class="widget-heading"><div><p class="eyebrow">MONITOR AO VIVO</p><h2>Transmissões</h2></div><span id="widgetCount">Standby</span></div><div id="moduleGrid" class="module-grid widget-grid"></div><div id="opsWidget" class="ops-widget"><span class="status-dot"></span><div><b>Servidor operacional</b><small id="serverLine">Lendo estado...</small></div><div class="ops-numbers"><span><b id="headerConnected">0</b> conectados</span><span><b id="headerActive">0</b> TX ativa</span></div></div></aside>
 </section>
<!-- XLX HAM WEATHER WIDGET V1 -->
 <section class="hamwx-panel panel" id="hamWeatherWidget" aria-label="Clima e condições de propagação para radioamadores">
  <div class="hamwx-skeleton">Carregando clima e propagação...</div>
 </section>
<!-- /XLX HAM WEATHER WIDGET V1 -->
<?php elseif ($page === 'modulos'): ?>
 <section class="page-heading"><p class="eyebrow">ESTRUTURA DO REFLETOR</p><h1>Módulos A–E</h1><p>Identificação, função, protocolo, acesso e quantidade de estações conectadas em cada módulo.</p></section>
 <section id="moduleOverview" class="module-overview-grid module-page-grid"></section>
 <section class="panel module-reference"><h2>Identificações de acesso</h2><div class="table-wrap"><table class="module-access-table"><thead><tr><th rowspan="2">Módulo</th><th rowspan="2">Protocolo / função</th><th rowspan="2">Estações conectadas</th><th colspan="2">DPlus (REF)</th><th colspan="2">DExtra (XRF)</th><th colspan="2">DCS (DCS/XLX)</th><th rowspan="2">DMR</th><th rowspan="2">YSF DG-ID</th></tr><tr><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th></tr></thead><tbody id="moduleReferenceRows"></tbody></table></div></section>
<?php elseif ($page === 'conectados'): ?>
 <section class="page-heading heading-with-tools"><div><p class="eyebrow">REDE ATIVA</p><h1>Estações conectadas</h1><p id="connectedLabel">Carregando conexões...</p></div><label class="search-box"><span>Pesquisar</span><input id="connectedSearch" type="search" placeholder="Indicativo, nome ou região" autocomplete="off"></label></section>
 <section id="connectedCards" class="connected-cards"></section>
 <section class="panel"><div class="table-wrap"><table class="connected-table"><thead><tr><th>#</th><th>País</th><th>Indicativo</th><th>Nome</th><th>Localização</th><th>Protocolo</th><th>Módulo</th><th>Conectado às</th><th>Tempo conectado</th><th>Última atividade</th></tr></thead><tbody id="connectedRows"></tbody></table></div></section>
<?php elseif ($page === 'ranking'): ?>
<!-- XLXGLOBAL_RANKING_V2 -->
<?php require __DIR__.'/ranking-v2-view.php'; ?>

<?php elseif ($page === 'refletores'): ?>
 <section class="page-heading"><p class="eyebrow">REDE MUNDIAL</p><h1>Lista de refletores XLX</h1></section>
 <section class="panel embedded-panel"><div class="embedded-toolbar"><div><b>Refletores registrados</b><span>Nome, país, status e descrição.</span></div></div><div class="table-wrap"><table class="reflectors-table"><thead><tr><th>#</th><th>Refletor</th><th>País</th><th>Status</th><th>Descrição</th></tr></thead><tbody id="reflectorRows"><tr><td colspan="5">Carregando lista de refletores...</td></tr></tbody></table></div></section>
<?php endif; ?>

</main>
<footer><div><a class="brand footer-brand" href="<?=page_url('ao-vivo')?>"><img class="brand-logo" src="assets/logo-reflector.svg" alt="Logotipo <?=h($serverName)?>"><span><b><?=h($serverName)?></b><small><?=h($country)?></small></span></a><p>Painel para a comunidade radioamadora.</p></div><div class="footer-links"><a href="<?=page_url('ao-vivo')?>">Ao vivo</a><a href="<?=page_url('conectados')?>">Conectados</a><a href="<?=page_url('modulos')?>">Módulos</a><a href="<?=page_url('ranking')?>">Ranking</a><a href="<?=page_url('refletores')?>">Refletores</a></div><small><?=h($serverName)?><?php if ($dmrTg !== ''): ?> • DMR TG <?=h($dmrTg)?><?php endif; ?><?php if ($ysfId !== ''): ?> • C4FM/YSF <?=h($ysfId)?><?php endif; ?></small></footer>
<div id="toastStack" class="toast-stack"></div><script src="assets/mtr.js?v=4"></script><script src="assets/app-main-1.js?v=55"></script><script src="assets/app-main-2.js?v=55"></script><script src="assets/app-main-3.js?v=55"></script>

<!-- XLX MODERN DASHBOARD INSTALL APP V33 -->
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
                src="/assets/logo-reflector.svg"
                alt=""
                width="66"
                height="66"
            >
            <div>
                <span class="xlx-install-eyebrow">
                    Acesso rápido
                </span>
                <h2 id="xlxInstallTitle">
                    Instalar <?=h($serverName)?>
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
<!-- /XLX MODERN DASHBOARD INSTALL APP V33 -->
<script src="assets/install-app.js?v=33"></script><script src="assets/ham-weather-widget.js?v=3" defer></script>

</body></html>
