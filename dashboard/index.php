<?php
$page = $_GET['page'] ?? 'ao-vivo';
$allowed = ['ao-vivo','modulos','conectados','ranking','refletores','suporte'];
if (!in_array($page, $allowed, true)) $page = 'ao-vivo';
function nav_class(string $p, string $current): string { return $p === $current ? ' class="active"' : ''; }
function page_url(string $p): string { return '?page=' . rawurlencode($p); }
function render_nav(string $page): string {
  $items = [
    'ao-vivo' => 'Ao vivo',
    'modulos' => 'Módulos A–E',
    'conectados' => 'Conectados',
    'ranking' => 'Ranking',
    'refletores' => 'Lista de refletores XLX',
    'suporte' => 'Suporte',
  ];
  $html = '';
  foreach ($items as $slug => $label) {
    $cls = $slug === $page ? ' class="active"' : '';
    $html .= '<a' . $cls . ' href="' . htmlspecialchars(page_url($slug), ENT_QUOTES, 'UTF-8') . '">' . htmlspecialchars($label, ENT_QUOTES, 'UTF-8') . '</a>';
  }
  return $html;
}
$seo = [
 'ao-vivo'=>['title'=>'{{REFLECTOR_NAME}} Brasil — Painel ao vivo D-STAR, DMR e C4FM','description'=>'Acompanhe ao vivo transmissões, estações conectadas e módulos do refletor multiprotocolo {{REFLECTOR_NAME}} Brasil.'],
 'modulos'=>['title'=>'Módulos A–E — {{REFLECTOR_NAME}} Brasil','description'=>'Consulte funções, protocolos e identificações de acesso dos módulos A a E do refletor {{REFLECTOR_NAME}} Brasil.'],
 'conectados'=>['title'=>'Estações conectadas — {{REFLECTOR_NAME}} Brasil','description'=>'Veja em tempo real as estações conectadas ao {{REFLECTOR_NAME}} Brasil, com indicativo, protocolo, módulo e tempo de conexão.'],
 'ranking'=>['title'=>'Ranking de atividade — {{REFLECTOR_NAME}} Brasil','description'=>'Ranking recente do {{REFLECTOR_NAME}} Brasil por transmissões, tempo no ar, permanência, horários, protocolos e módulos.'],
 'refletores'=>['title'=>'Lista de refletores XLX — {{REFLECTOR_NAME}} Brasil','description'=>'Lista atualizada de refletores XLX registrados, com país, status e descrição.'],
 'suporte'=>['title'=>'Suporte e tutoriais — {{REFLECTOR_NAME}} Brasil','description'=>'Tutoriais e orientações para conexão ao {{REFLECTOR_NAME}} Brasil por D-STAR, DMR e C4FM/YSF.']
];
$meta = $seo[$page];
$canonical = 'https://{{REFLECTOR_NAME}}.net/' . ($page === 'ao-vivo' ? '' : '?page=' . rawurlencode($page));
?>
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#06131d"><meta name="description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
<link rel="canonical" href="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>">
<meta property="og:type" content="website"><meta property="og:locale" content="pt_BR"><meta property="og:site_name" content="{{REFLECTOR_NAME}} Brasil">
<meta property="og:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta property="og:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>">
<meta property="og:url" content="<?=htmlspecialchars($canonical, ENT_QUOTES, 'UTF-8')?>"><meta property="og:image" content="https://{{REFLECTOR_NAME}}.net/assets/logo-{{REFLECTOR_NAME}}.jpeg">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="<?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:description" content="<?=htmlspecialchars($meta['description'], ENT_QUOTES, 'UTF-8')?>"><meta name="twitter:image" content="https://{{REFLECTOR_NAME}}.net/assets/logo-{{REFLECTOR_NAME}}.jpeg">
<link rel="icon" href="favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png"><link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png"><link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png"><link rel="manifest" href="site.webmanifest">
<title><?=htmlspecialchars($meta['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/app.css?v=41">
<body data-page="<?=htmlspecialchars($page, ENT_QUOTES, 'UTF-8')?>">
<main>
<section class="hero hero-compact universal-header" aria-label="Servidor {{REFLECTOR_NAME}} Brasil">
 <div class="universal-header-row">
  <a class="universal-brand" href="<?=page_url('ao-vivo')?>" aria-label="{{REFLECTOR_NAME}} Brasil">
   <img class="hero-logo" src="assets/logo-{{REFLECTOR_NAME}}.jpeg" alt="{{REFLECTOR_NAME}} Brasil — D-STAR, DMR e C4FM" width="112" height="112">
  </a>
  <div class="universal-copy">
   <p class="eyebrow">REFLETOR DIGITAL MULTIPROTOCOLO</p>
   <h1>Servidor <span>{{REFLECTOR_NAME}} Brasil</span></h1>
   <div class="access-strip"><span><b>D-STAR</b> {{REFLECTOR_NAME}}-D</span><span><b>DMR</b> {{REFLECTOR_NAME}}-C • TG 6 no rádio • TG 4003 nos apps</span><span><b>C4FM/YSF</b> BR-{{REFLECTOR_NAME}} • YSF72426</span></div>
  </div>
  <button class="menu-toggle" type="button" aria-label="Abrir menu" aria-expanded="false">☰</button>
  <nav class="universal-nav" aria-label="Menu principal"><?=render_nav($page)?></nav>
  <div class="live-pill universal-live-pill"><i></i><span id="syncState">Conectando</span></div>
 </div>
</section>
<?php if ($page === 'ao-vivo'): ?>
 <section class="dashboard-layout">
  <div class="dashboard-main panel compact-panel">
   <div class="section-title panel-title"><div><p class="eyebrow">ÚLTIMAS ATIVIDADES</p><h2>Últimas transmissões</h2></div><span class="table-note">Até 30 registros</span></div>
   <div class="table-wrap"><table class="home-history"><thead><tr><th>País</th><th>Horário</th><th>Indicativo</th><th>Operador</th><th>Protocolo</th><th>Módulo</th><th>Duração</th><th>Status</th></tr></thead><tbody id="historyRows"></tbody></table></div>
  </div>
  <aside class="live-widget"><div class="widget-heading"><div><p class="eyebrow">MONITOR AO VIVO</p><h2>Transmissões</h2></div><span id="widgetCount">Standby</span></div><div id="moduleGrid" class="module-grid widget-grid"></div><div id="opsWidget" class="ops-widget"><span class="status-dot"></span><div><b>Servidor operacional</b><small id="serverLine">Lendo estado...</small></div><div class="ops-numbers"><span><b id="headerConnected">0</b> conectados</span><span><b id="headerActive">0</b> TX ativa</span></div></div></aside>
 </section>
<?php elseif ($page === 'modulos'): ?>
 <section class="page-heading"><p class="eyebrow">ESTRUTURA DO REFLETOR</p><h1>Módulos A–E</h1><p>Identificação, função, protocolo, acesso e quantidade de estações conectadas em cada módulo.</p></section>
 <section id="moduleOverview" class="module-overview-grid module-page-grid"></section>
 <section class="panel module-reference"><h2>Identificações de acesso</h2><div class="table-wrap"><table class="module-access-table"><thead><tr><th rowspan="2">Módulo</th><th rowspan="2">Protocolo / função</th><th rowspan="2">Estações conectadas</th><th colspan="2">DPlus (REF)</th><th colspan="2">DExtra (XRF)</th><th colspan="2">DCS (DCS/XLX)</th><th rowspan="2">DMR</th><th rowspan="2">YSF DG-ID</th></tr><tr><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th><th>URCALL</th><th>DTMF</th></tr></thead><tbody id="moduleReferenceRows"></tbody></table></div></section>
<?php elseif ($page === 'conectados'): ?>
 <section class="page-heading heading-with-tools"><div><p class="eyebrow">REDE ATIVA</p><h1>Estações conectadas</h1><p id="connectedLabel">Carregando conexões...</p></div><label class="search-box"><span>Pesquisar</span><input id="connectedSearch" type="search" placeholder="Indicativo, nome ou região" autocomplete="off"></label></section>
 <section id="connectedCards" class="connected-cards"></section>
 <section class="panel"><div class="table-wrap"><table class="connected-table"><thead><tr><th>#</th><th>País</th><th>Indicativo</th><th>Nome</th><th>Localização</th><th>Protocolo</th><th>Módulo</th><th>Conectado às</th><th>Tempo conectado</th><th>Última atividade</th></tr></thead><tbody id="connectedRows"></tbody></table></div></section>
<?php elseif ($page === 'ranking'): ?>
 <section class="page-heading"><p class="eyebrow">ATIVIDADE E PARTICIPAÇÃO</p><h1>Ranking {{REFLECTOR_NAME}}</h1><p>Indicadores calculados com o histórico disponível no painel e com as conexões atualmente ativas.</p></section>
 <section id="rankingHighlights" class="ranking-highlights"></section>
 <section class="ranking-grid">
  <article class="panel ranking-card"><div class="section-title"><div><p class="eyebrow">TRANSMISSÕES</p><h2>Quem mais transmitiu</h2></div></div><p class="ranking-help">Conta quantas transmissões encerradas cada indicativo realizou no histórico recente disponível.</p><div id="rankTx" class="rank-list"></div></article>
  <article class="panel ranking-card"><div class="section-title"><div><p class="eyebrow">TEMPO NO AR</p><h2>Maior tempo transmitindo</h2></div></div><p class="ranking-help">Soma a duração de todas as transmissões registradas para cada indicativo.</p><div id="rankAirtime" class="rank-list"></div></article>
  <article class="panel ranking-card"><div class="section-title"><div><p class="eyebrow">CONEXÕES ATUAIS</p><h2>Maior permanência conectada</h2></div></div><p class="ranking-help">Mostra as estações que permanecem conectadas há mais tempo neste momento.</p><div id="rankConnected" class="rank-list"></div></article>
  <article class="panel ranking-card"><div class="section-title"><div><p class="eyebrow">HORÁRIOS</p><h2>Momentos de maior uso</h2></div></div><p class="ranking-help">Agrupa as transmissões pela hora em que começaram para indicar os períodos mais movimentados.</p><div id="rankHours" class="rank-list"></div></article>
  <article class="panel ranking-card"><div class="section-title"><div><p class="eyebrow">PROTOCOLOS</p><h2>Protocolos mais usados</h2></div></div><p class="ranking-help">Compara quantas transmissões foram identificadas em D-STAR, DMR e C4FM/YSF.</p><div id="rankProtocols" class="rank-list"></div></article>
  <article class="panel ranking-card"><div class="section-title"><div><p class="eyebrow">MÓDULOS</p><h2>Módulos mais ativos</h2></div></div><p class="ranking-help">Conta em quais módulos do {{REFLECTOR_NAME}} ocorreram mais transmissões no histórico recente.</p><div id="rankModules" class="rank-list"></div></article>
 </section>
 <aside class="ranking-note"><strong>Como interpretar:</strong> os resultados usam o histórico ainda disponível nos logs do servidor e as conexões ativas. Não representam necessariamente todo o período de funcionamento do {{REFLECTOR_NAME}}.</aside>
<?php elseif ($page === 'refletores'): ?>
 <section class="page-heading"><p class="eyebrow">REDE MUNDIAL</p><h1>Lista de refletores XLX</h1></section>
 <section class="panel embedded-panel"><div class="embedded-toolbar"><div><b>Refletores registrados</b><span>Nome, país, status e descrição.</span></div></div><div class="table-wrap"><table class="reflectors-table"><thead><tr><th>#</th><th>Refletor</th><th>País</th><th>Status</th><th>Descrição</th></tr></thead><tbody id="reflectorRows"><tr><td colspan="5">Carregando lista de refletores...</td></tr></tbody></table></div></section>
<?php else: ?>
 <?php include __DIR__ . '/support-native.php'; ?>
<?php endif; ?>
</main>
<div id="toastStack" class="toast-stack"></div><?php if ($page === 'suporte'): ?><script src="assets/support-native.js?v=21"></script><?php endif; ?><script src="assets/app.js?v=42"></script>


<!-- {{REFLECTOR_NAME}} INSTALL APP V33 -->
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
                    Instalar {{REFLECTOR_NAME}} Brasil
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
<!-- /{{REFLECTOR_NAME}} INSTALL APP V33 -->
<script src="assets/install-app.js?v=33"></script></body></html>
