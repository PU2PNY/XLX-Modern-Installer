<div class="support-native">
<div class="page-shell" id="topo">
<div class="container">

<header class="hero support-hero-v2">
<div class="hero-grid">
<div class="support-hero-content">
<span class="eyebrow">Central oficial de apoio ao radioamador</span>
<h1>Suporte <span class="gradient-word">{{REFLECTOR_NAME}} Brasil</span></h1>
<p class="hero-subtitle">
Tutoriais, vídeos e downloads para radioamadores que utilizam DMR, D-STAR e C4FM/YSF.
Encontre Pi-Star, WPSD, DroidStar, VoxDMR e ferramentas para hotspot MMDVM de forma simples e organizada.
</p>
<div class="hero-actions">
<a class="btn btn-secondary" href="#videos">Ver tutoriais</a>
<a class="btn btn-warning" href="#downloads">Baixar arquivos</a>
</div>
<div aria-label="Protocolos e recursos disponíveis" class="hero-badges">
<span class="pill">D-STAR</span>
<span class="pill">C4FM / YSF</span>
<span class="pill">DMR</span>
<span class="pill">DroidStar</span>
<span class="pill">Pi-Star</span>
</div>
</div>
</div>
</header>
<!-- {{REFLECTOR_NAME}}_DSTAR_QUICK_CONNECT_V1 -->
<!-- /{{REFLECTOR_NAME}}_DMR_QUICK_CONNECT_V1 -->

<!-- {{REFLECTOR_NAME}}_HOW_TO_CONNECT_UNIFIED_V1 -->
<!-- /{{REFLECTOR_NAME}}_HOW_TO_CONNECT_UNIFIED_V1 -->
<section class="section" id="videos">
<div class="section-header">
<div>
<span class="section-kicker">Aulas e passo a passo</span>
<h2 class="section-title">Vídeos tutoriais</h2>
</div>
</div>
<div aria-label="Ferramentas de busca dos vídeos" class="video-toolbar">
<label class="search-box">
            🔎
            <input autocomplete="off" id="videoSearch" placeholder="Buscar vídeo por assunto..." type="search"/>
</label>
<div aria-label="Filtros de vídeos" class="filter-buttons" role="list">
<button class="filter-btn active" data-filter="all" type="button">Todos</button>
<button class="filter-btn" data-filter="anatel" type="button">ANATEL</button>
<button class="filter-btn" data-filter="classe" type="button">Classe</button>
<button class="filter-btn" data-filter="reflector" type="button">{{REFLECTOR_NAME}}</button>
<button class="filter-btn" data-filter="apoio" type="button">Apoio</button>
</div>
</div>
<div class="videos-grid" id="videosGrid"></div>
<div class="empty-state" id="emptyVideos">Nenhum vídeo encontrado com esse filtro.</div>
</section>
<section class="section support-downloads-v2" id="downloads">
<div class="section-header">
<div>
<span class="section-kicker">Softwares e ferramentas</span>
<h2 class="section-title">Downloads para radioamadores</h2>
<p class="section-description">
Aplicativos, softwares, imagens para hotspot MMDVM, documentação e ferramentas úteis para DMR, D-STAR, C4FM/YSF e modos digitais.
</p>
</div>
</div>

<div class="download-group">
<h3 class="download-group-title">DMR e aplicativos</h3>
<div class="downloads-grid support-software-grid">

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">VOX</span><h3>VoxDMR</h3></div>
<p>Cliente DMR para Android e Windows que permite operar talkgroups pela internet.</p>
<div class="software-note">
<strong>Áudio</strong>
<p>Comece com RX e TX baixos e aumente gradualmente. Nas versões atuais, ajuste o TX manualmente para evitar saturação.</p>
<p>O Lock-screen PTT pode funcionar com o aplicativo em segundo plano ou com a tela bloqueada, conforme permissões e configuração do Android.</p>
</div>
<div class="software-actions">
<a href="https://play.google.com/store/apps/details?id=com.jcalado.voxdmr" target="_blank" rel="noopener noreferrer">Android</a>
<a href="https://github.com/jcalado/voxdmr-site/releases/latest/download/VoxDMR-windows-x86_64.exe" target="_blank" rel="noopener noreferrer">Windows</a>
</div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">Z3</span><h3>Z3DMR</h3></div>
<p>Cliente DMR para Android com talkgroups, chamadas privadas e perfis de conexão.</p>
<div class="software-note"><p>Pode continuar operando com a tela desligada dependendo das permissões e configurações de energia do Android.</p></div>
<div class="software-actions">
<a href="https://play.google.com/store/apps/details?id=com.z3.dmr" target="_blank" rel="noopener noreferrer">Android</a>
</div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">DS</span><h3>DroidStar</h3></div>
<p>Cliente multimodo para DMR, D-STAR, YSF/Fusion, P25, NXDN, M17 e outros sistemas digitais.</p>
<div class="software-note"><p>Não é apresentado como solução para operação contínua em segundo plano ou com a tela desligada.</p></div>
<div class="software-actions">
<a href="https://play.google.com/store/apps/details?id=org.dudetronics.droidstar" target="_blank" rel="noopener noreferrer">Android</a>
</div>
</article>

</div>
</div>

<div class="download-group">
<h3 class="download-group-title">Pi-Star e hotspots</h3>
<div class="downloads-grid support-software-grid">

<article class="download-card software-card download-card-recommended">
<div class="software-card-head"><span class="software-icon">RPi</span><h3>Pi-Star para Raspberry Pi</h3></div>
<p>Pi-Star 4.1.8 — versão recomendada pelo {{REFLECTOR_NAME}} para uma instalação tradicional, conhecida e com bastante material de apoio disponível.</p>
<div class="software-actions">
<a href="https://pi-star.de/downloads/Pi-Star_RPi_V4.1.8_16-Feb-2024.zip" target="_blank" rel="noopener noreferrer">Baixar 4.1.8</a>
</div>
</article>

<article class="download-card software-card download-card-legacy">
<div class="software-card-head"><span class="software-icon">OPi</span><h3>Pi-Star Orange Pi 3.4.17</h3></div>
<p>Imagem oficial legada para Orange Pi Zero, útil em cenários de compatibilidade com instalações e hardware mais antigos.</p>
<div class="software-actions">
<a href="https://pi-star.de/downloads/Pi-Star_OrangePi_Zero_V3.4.17_11-Jan-2019.zip" target="_blank" rel="noopener noreferrer">Baixar 3.4.17</a>
</div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">OPi</span><h3>Pi-Star Orange Pi 4.2.0</h3></div>
<p>Imagem oficial disponível para Orange Pi Zero, destinada a placas compatíveis utilizadas como hotspot digital.</p>
<div class="software-actions">
<a href="https://pi-star.de/downloads/Pi-Star_OrangePiZero_V4.2.0_05-Feb-2024.zip" target="_blank" rel="noopener noreferrer">Baixar 4.2.0</a>
</div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">WPS</span><h3>WPSD</h3></div>
<p>Sistema moderno para hotspots digitais MMDVM com suporte a DMR, D-STAR, YSF e outros modos.</p>
<div class="software-actions">
<a href="https://wpsd.radio/#download-wpsd" target="_blank" rel="noopener noreferrer">Download</a>
<a href="https://manual.wpsd.radio/" target="_blank" rel="noopener noreferrer">Manual</a>
</div>
</article>

</div>
</div>

<div class="download-group">
<h3 class="download-group-title">Modos digitais e estação</h3>
<div class="downloads-grid support-software-grid">

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">FT8</span><h3>WSJT-X</h3></div>
<p>Software para FT8, FT4, Q65, JT65, MSK144, WSPR e outros modos de sinais fracos.</p>
<div class="software-actions"><a href="https://wsjtx.github.io/wsjtx/downloads.html" target="_blank" rel="noopener noreferrer">Download oficial</a></div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">JTA</span><h3>JTAlert</h3></div>
<p>Alertas visuais e sonoros e integrações para operação com WSJT-X e programas de log.</p>
<div class="software-actions"><a href="https://hamapps.com/" target="_blank" rel="noopener noreferrer">Download oficial</a></div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">JS8</span><h3>JS8Call</h3></div>
<p>Comunicação digital por mensagens em HF otimizada para sinais fracos.</p>
<div class="software-actions"><a href="https://js8call.com/downloads.html" target="_blank" rel="noopener noreferrer">Download oficial</a></div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">MSH</span><h3>MSHV</h3></div>
<p>Software multimodo para FT8, FT4, MSK144, JT65 e outros modos digitais.</p>
<div class="software-actions"><a href="https://sourceforge.net/projects/mshv/files/" target="_blank" rel="noopener noreferrer">Download oficial</a></div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">HRD</span><h3>Ham Radio Deluxe</h3></div>
<p>Suite para CAT, log, modos digitais, rotor e acompanhamento de satélites.</p>
<div class="software-actions"><a href="https://www.hamradiodeluxe.com/downloads/" target="_blank" rel="noopener noreferrer">Download oficial</a></div>
</article>

</div>
</div>

<div class="download-group">
<h3 class="download-group-title">Tutoriais {{REFLECTOR_NAME}}</h3>
<div class="downloads-grid support-software-grid">

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">PDF</span><h3>Orange Pi Zero + WPSD</h3></div>
<p>Tutorial em PDF para montagem e configuração de hotspot WPSD usando Orange Pi Zero LTS.</p>
<div class="software-actions"><a href="https://drive.google.com/file/d/1TRQHweU3n_GVHxYEMLWkmYQjI5SyyUM3/view" target="_blank" rel="noopener noreferrer">Abrir tutorial</a></div>
</article>

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">PDF</span><h3>Hotspot D-STAR</h3></div>
<p>Material de apoio para acesso às redes digitais utilizando hotspot D-STAR.</p>
<div class="software-actions"><a href="https://drive.google.com/file/d/1_YSXP20Hg6QJLSjOPJZ3gEbaSohqhnEn/view" target="_blank" rel="noopener noreferrer">Abrir tutorial</a></div>
</article>

</div>
</div>

<div class="download-group">
<h3 class="download-group-title">Satélites</h3>
<div class="downloads-grid support-software-grid">

<article class="download-card software-card">
<div class="software-card-head"><span class="software-icon">ISS</span><h3>ISS Detector</h3></div>
<p>Rastreamento da ISS e satélites, incluindo recursos destinados ao radioamadorismo.</p>
<div class="software-actions">
<a href="https://www.issdetector.com/" target="_blank" rel="noopener noreferrer">Site</a>
<a href="https://play.google.com/store/apps/details?id=com.runar.issdetector" target="_blank" rel="noopener noreferrer">Android</a>
</div>
</article>

</div>
</div>
</section>
<section class="section" id="canais">
<div class="section-header">
<div>
<span class="section-kicker">Comunidade</span>
<h2 class="section-title">Canais oficiais do projeto</h2>
<p class="section-description">
              Links de apoio para acompanhar o {{REFLECTOR_NAME}}, entrar no grupo, acessar o painel e acessar os materiais de apoio.
            </p>
</div>
</div>
<div class="channels-grid">
<article class="channel-card">
<h3>📘 Facebook</h3>
<p>Página oficial para notícias, publicações e atualizações do {{REFLECTOR_NAME}}.</p>
<a href="https://www.facebook.com/xlx026" rel="noopener" target="_blank">Abrir Facebook →</a>
</article>
<article class="channel-card">
<h3>💚 WhatsApp</h3>
<p>Grupo da comunidade para tirar dúvidas técnicas e trocar experiências.</p>
<a href="https://chat.whatsapp.com/CwW2nKDI8sb2LtHIvyr2Ow" rel="noopener" target="_blank">Entrar no grupo →</a>
</article>
<article class="channel-card">
<h3>🌐 Dashboard</h3>
<p>Painel web para acompanhar conexões e atividade do refletor.</p>
<a href="?page=ao-vivo">Abrir painel →</a>
</article>
<article class="channel-card">
<h3>✈️ Telegram</h3>
<p>Bot que mostra conexões e desconexões do {{REFLECTOR_NAME}} em tempo real.</p>
<a href="https://t.me/xlx026_connection_state" rel="noopener" target="_blank">Abrir bot no Telegram →</a>
</article>
</div>
</section>

</div>
</div>
<a aria-label="Voltar ao topo" class="back-top" href="#topo" title="Voltar ao topo">↑</a>
<div aria-hidden="true" aria-label="Player de vídeo tutorial" aria-modal="true" class="video-modal" id="videoModal" role="dialog">
<div class="video-modal-content">
<div class="modal-top">
<div class="modal-title" id="modalVideoTitle">Vídeo tutorial</div>
<button aria-label="Fechar vídeo" class="video-modal-close" id="closeVideoModal" type="button">×</button>
</div>
<div class="modal-frame-wrap">
<iframe allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen="" id="videoFrame" referrerpolicy="strict-origin-when-cross-origin" src="" title="Vídeo tutorial {{REFLECTOR_NAME}}"></iframe>
</div>
</div>
</div>


</div>



<!-- {{REFLECTOR_NAME}}_SEO_AI_BUSCADORES_V2_INCLUDE -->
<!-- {{REFLECTOR_NAME}}_SEO_AI_BUSCADORES_V2_VISIBLE -->
<section class="seo-ai-context-wrap" aria-label="Informações oficiais sobre esta página">
 <details class="seo-ai-context">
  <summary>Sobre esta página e como interpretar os dados</summary>
  <div class="seo-ai-context-body">
   <h2>Sobre a Central de Suporte</h2>
   <p>A página reúne tutoriais, referências, vídeos, downloads e orientações para uso de tecnologias de radioamadorismo relacionadas ao {{REFLECTOR_NAME}}.</p>
   <ul>
       <li>A presença de um software, aplicativo, firmware ou projeto na Central de Suporte não significa que ele tenha sido desenvolvido pelo {{REFLECTOR_NAME}} Brasil.</li>
       <li>Quando houver projeto ou documentação externa, a fonte original deve ser considerada a referência para autoria, licença e versões do software.</li>
      </ul>
   <p class="seo-ai-context-machine">Referência técnica estruturada: <a href="/ai-context.json">ai-context.json</a> · resumo para agentes de IA: <a href="/llms.txt">llms.txt</a>.</p>
  </div>
 </details>
</section>
<!-- /{{REFLECTOR_NAME}}_SEO_AI_BUSCADORES_V2_VISIBLE -->
<!-- /{{REFLECTOR_NAME}}_SEO_AI_BUSCADORES_V2_INCLUDE -->
