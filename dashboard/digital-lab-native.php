<?php
/**
 * {{REFLECTOR_NAME}} Digital Lab v1.1 — conteúdo nativo para inclusão no index.php.
 * Sem consultas externas no PHP. Todos os dados vêm da API local read-only.
 */
?>
<section class="dlab-page" id="digitalLab" aria-labelledby="dlabTitle">
  <header class="dlab-hero panel">
    <div class="dlab-hero-copy">
      <p class="eyebrow">{{REFLECTOR_NAME}} • MÓDULO B</p>
      <h1 id="dlabTitle">APRS / D-PRS</h1>
      <p class="dlab-lead">Envie e receba mensagens APRS pelo APRS-IS, acompanhe ACKs, comandos e estações no mapa e visualize beacons D-PRS/GPS-A recebidos pelo módulo B.</p>
      <div class="dlab-tags" aria-label="Tecnologias do laboratório">
        <span>D-STAR DATA</span><span>D-PRS</span><span>APRS-IS</span><span>GPS-A</span>
      </div>
    </div>
    <div class="dlab-module-mark" aria-label="Módulo B">
      <span class="dlab-module-letter">B</span>
      <strong>DATA</strong>
      <small>APRS / D-PRS</small>
    </div>
  </header>

  <section class="dlab-status-grid" aria-label="Estado dos serviços">
    <article class="dlab-status-card panel" data-service="gateway">
      <span class="dlab-status-dot" aria-hidden="true"></span>
      <div><small>DATA GATEWAY</small><strong id="dlabGatewayStatus">Verificando…</strong><span id="dlabGatewayDetail">Camada isolada do XLXD</span></div>
    </article>
    <article class="dlab-status-card panel" data-service="module_b">
      <span class="dlab-status-dot" aria-hidden="true"></span>
      <div><small>{{REFLECTOR_NAME}}-B</small><strong id="dlabModuleStatus">Verificando…</strong><span id="dlabModuleDetail">DExtra somente recepção</span></div>
    </article>
    <article class="dlab-status-card panel" data-service="aprs_is">
      <span class="dlab-status-dot" aria-hidden="true"></span>
      <div><small>APRS-IS</small><strong id="dlabAprsStatus">Verificando…</strong><span id="dlabAprsDetail">Rede APRS</span></div>
    </article>
  </section>

  <section class="dlab-primary-grid">
    <article class="dlab-test-card panel">
      <div class="dlab-card-heading">
        <div><p class="eyebrow">TESTE GUIADO</p><h2>Meu beacon chegou?</h2></div>
        <span class="dlab-live-pill">MÓDULO B</span>
      </div>
      <p>Informe seu indicativo, conecte ao <strong>{{REFLECTOR_NAME}}-B</strong> e transmita com GPS/D-PRS ativado. A página confirma quando o beacon for recebido.</p>
      <form id="dlabBeaconForm" class="dlab-call-form" novalidate>
        <label for="dlabCallsign">Indicativo</label>
        <div class="dlab-input-row">
          <input id="dlabCallsign" name="callsign" type="text" inputmode="text" autocomplete="off" maxlength="11" placeholder="Ex.: PU2ABC" aria-describedby="dlabCallHelp">
          <button class="dlab-btn dlab-btn-primary" type="submit">Iniciar teste</button>
        </div>
        <small id="dlabCallHelp">Nenhum cadastro é necessário para testar.</small>
      </form>
      <div class="dlab-test-state" id="dlabTestState" aria-live="polite">
        <div class="dlab-radar" aria-hidden="true"><i></i><i></i><b></b></div>
        <div><strong>Pronto para testar</strong><span>O monitor será ativado depois que você informar o indicativo.</span></div>
      </div>
      <button id="dlabCancelTest" class="dlab-btn dlab-btn-ghost" type="button" hidden>Cancelar teste</button>
    </article>

    <article class="dlab-learn-card panel">
      <div class="dlab-card-heading"><div><p class="eyebrow">COMECE AQUI</p><h2>Primeiro D-PRS em 3 passos</h2></div></div>
      <ol class="dlab-steps">
        <li><span>1</span><div><strong>Conecte ao módulo B</strong><p>No hotspot ou rádio, selecione o {{REFLECTOR_NAME}} e o módulo <b>B</b>.</p></div></li>
        <li><span>2</span><div><strong>Ative GPS / D-PRS</strong><p>Em D-STAR, prefira o modo GPS-A/D-PRS quando seu equipamento oferecer essa opção.</p></div></li>
        <li><span>3</span><div><strong>Faça uma transmissão</strong><p>Pressione o PTT por alguns segundos e acompanhe a confirmação nesta página.</p></div></li>
      </ol>
      <div class="dlab-note"><strong>Seguro para o refletor:</strong> o laboratório escuta o módulo B como cliente independente e não altera o core do XLXD.</div>
    </article>
  </section>

  <section class="dlab-data-grid">
    <article class="dlab-stations-card panel">
      <div class="dlab-card-heading">
        <div><p class="eyebrow">D-PRS / APRS</p><h2>Estações recentes</h2></div>
        <span id="dlabStationCount" class="dlab-counter">0</span>
      </div>
      <div class="dlab-station-list" id="dlabStations" aria-live="polite">
        <div class="dlab-empty">Aguardando dados do gateway…</div>
      </div>
    </article>

    <article class="dlab-map-card panel">
      <div class="dlab-card-heading"><div><p class="eyebrow">LOCALIZAÇÃO</p><h2>Mapa da estação</h2></div></div>
      <div class="dlab-map-placeholder" id="dlabMapPlaceholder">
        <div class="dlab-map-cross" aria-hidden="true"></div>
        <strong>Selecione uma estação</strong>
        <span>O mapa só é carregado quando você solicitar, economizando recursos.</span>
      </div>
      <iframe id="dlabMapFrame" class="dlab-map-frame" title="Mapa da estação APRS/D-PRS" loading="lazy" referrerpolicy="no-referrer" hidden></iframe>
      <div class="dlab-map-meta" id="dlabMapMeta" hidden>
        <div><strong id="dlabMapCall">—</strong><span id="dlabMapCoords">—</span></div>
        <a id="dlabAprsFiLink" href="#" target="_blank" rel="noopener noreferrer">Abrir no aprs.fi ↗</a>
      </div>
    </article>
  </section>

  <link rel="stylesheet" href="/assets/digital-lab-operator.css?v=1.2.3">

  <section class="dlab-message-card panel">
    <div class="dlab-card-heading">
      <div>
        <p class="eyebrow">MENSAGENS APRS</p>
        <h2>Mensagens e comandos</h2>
      </div>
      <span id="dlabAprsServicePill" class="dlab-service-pill">AGUARDANDO ATIVAÇÃO</span>
    </div>

    <p class="dlab-message-intro">
        <strong>Como usar:</strong>
        o serviço APRS do {{REFLECTOR_NAME}} é <strong>{{APRS_SERVICE_CALLSIGN}}</strong>.
        Quando estiver logado com uma conta ativa, clicar em um comando abaixo
        coloca o texto diretamente no campo <strong>Mensagem</strong>.
        Para testar os comandos do próprio serviço usando um rádio ou aplicativo APRS,
        envie a mensagem para <strong>{{APRS_SERVICE_CALLSIGN}}</strong>.
      </p>

      <div class="dlab-ssid-note">
        <strong>Por que {{APRS_SERVICE_CALLSIGN}}?</strong>
        <span>
          <b>{{SYSOP_CALLSIGN}}</b> é o indicativo e <b>-10</b> é o SSID dedicado
          ao serviço APRS do {{REFLECTOR_NAME}}.
          O painel se conecta ao APRS-IS como <b>{{APRS_SERVICE_CALLSIGN}}</b>,
          recebe mensagens destinadas a esse endereço e envia suas respostas
          usando esse mesmo identificador.
          <b>Use -10, não -110.</b>
        </span>
      </div>

    <div class="dlab-command-grid">
      <button type="button" class="dlab-command-action" data-command="PING">
        <code>PING</code>
        <span>Testa se o serviço APRS está respondendo.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="STATUS">
        <code>STATUS</code>
        <span>Mostra o estado do {{REFLECTOR_NAME}} e do módulo B.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="LAST PU2ABC">
        <code>LAST PU2ABC</code>
        <span>Consulta a última atividade de outro indicativo.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="MYLAST">
        <code>MYLAST</code>
        <span>Consulta a sua própria última atividade.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="ONLINE">
        <code>ONLINE</code>
        <span>Mostra quantas estações foram vistas nos últimos 15 minutos.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="MODULE">
        <code>MODULE</code>
        <span>Mostra se o módulo B está conectado.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="INFO">
        <code>INFO</code>
        <span>Mostra informações do serviço APRS / D-PRS.</span>
      </button>

      <button type="button" class="dlab-command-action" data-command="HELP">
        <code>HELP</code>
        <span>Lista todos os comandos disponíveis.</span>
      </button>
    </div>

    <div class="dlab-operator-shell">

      <div id="dlabOperatorLocked">

        <div class="dlab-operator-title">
          <div>
            <strong>Acesso APRS / D-PRS</strong>
            <span>Entre com seu indicativo e sua senha.</span>
          </div>
          <span class="dlab-lock-badge">PROTEGIDO</span>
        </div>

        <form id="dlabOperatorLoginForm"
              class="dlab-account-form"
              novalidate>

          <label for="dlabLoginCall">Indicativo</label>
          <input id="dlabLoginCall"
                 type="text"
                 maxlength="8"
                 autocomplete="username"
                 placeholder="Ex.: PU2ABC"
                 required>

          <label for="dlabOperatorPassword">Senha</label>
          <input id="dlabOperatorPassword"
                 type="password"
                 autocomplete="current-password"
                 placeholder="Senha de acesso"
                 required>

          <label class="dlab-check-row">
            <input id="dlabRememberMe"
                   type="checkbox">
            <span>Lembrar meu acesso neste dispositivo por 30 dias.</span>
          </label>

          <button class="dlab-btn dlab-btn-primary"
                  type="submit">
            Entrar
          </button>
        </form>

        <details class="dlab-register-box">
          <summary>Criar meu acesso</summary>

          <div class="dlab-register-body">
            <p>
              Para criar sua conta, informe seu indicativo e
              <strong>dia e mês reais do aniversário</strong>.
              Não pedimos o ano.
            </p>

            <p>
              O dia e o mês serão usados para
              <strong>auxiliar na recuperação da sua senha</strong>
              caso você a perca e também poderão ser usados
              futuramente para recursos de aniversário no {{REFLECTOR_NAME}}.
            </p>

            <p>
              Antes do cadastro, faça um beacon D-PRS pelo módulo B
              ou envie uma mensagem APRS para
              <strong>{{APRS_SERVICE_CALLSIGN}}</strong>.
              A atividade precisa ter ocorrido nos últimos 15 minutos.
            </p>

            <form id="dlabRegisterForm"
                  class="dlab-account-form"
                  novalidate>

              <label for="dlabRegisterCall">Indicativo</label>
              <input id="dlabRegisterCall"
                     type="text"
                     maxlength="8"
                     placeholder="Ex.: PU2ABC"
                     autocomplete="off"
                     required>

              <div class="dlab-birthday-grid">
                <div>
                  <label for="dlabBirthDay">Dia</label>
                  <input id="dlabBirthDay"
                         type="number"
                         min="1"
                         max="31"
                         placeholder="18"
                         required>
                </div>

                <div>
                  <label for="dlabBirthMonth">Mês</label>
                  <select id="dlabBirthMonth" required>
                    <option value="">Selecione</option>
                    <option value="1">Janeiro</option>
                    <option value="2">Fevereiro</option>
                    <option value="3">Março</option>
                    <option value="4">Abril</option>
                    <option value="5">Maio</option>
                    <option value="6">Junho</option>
                    <option value="7">Julho</option>
                    <option value="8">Agosto</option>
                    <option value="9">Setembro</option>
                    <option value="10">Outubro</option>
                    <option value="11">Novembro</option>
                    <option value="12">Dezembro</option>
                  </select>
                </div>
              </div>

              <label class="dlab-check-row">
                <input id="dlabBirthdayConsent"
                       type="checkbox"
                       required>
                <span>
                  Confirmo que o dia e o mês informados são reais
                  e autorizo o uso para recuperação de acesso e
                  recursos de aniversário.
                </span>
              </label>

              <button class="dlab-btn dlab-btn-primary"
                      type="submit">
                Gerar minha senha
              </button>
            </form>

            <div id="dlabRegisterResult"
                 class="dlab-credential-box"
                 hidden></div>
          </div>
        </details>

        <p class="dlab-recovery-note">
          <strong>Esqueceu a senha?</strong>
          Informe ao administrador ou colaborador autorizado
          seu indicativo e o dia/mês real do aniversário.
          Será gerada uma nova senha; a antiga não é recuperada.
        </p>

      </div>

      <div id="dlabOperatorUnlocked" hidden>

        <div class="dlab-operator-title">
          <div>
            <strong id="dlabAccountTitle">
              Conta autenticada
            </strong>

            <span id="dlabOperatorState">
              Verificando acesso…
            </span>
          </div>

          <span id="dlabRoleBadge"
                class="dlab-role-badge">
            USUÁRIO
          </span>
        </div>

        <div id="dlabAdminToolbar"
             class="dlab-admin-toolbar">

          <button id="dlabUsersBtn"
                  class="dlab-btn dlab-btn-ghost"
                  type="button"
                  hidden>
            👥 Usuários
          </button>

          <button id="dlabResetBtn"
                  class="dlab-btn dlab-btn-ghost"
                  type="button"
                  hidden>
            🔑 Recuperar senha
          </button>

          <button id="dlabCollaboratorsBtn"
                  class="dlab-btn dlab-btn-ghost"
                  type="button"
                  hidden>
            🛡 Colaboradores
          </button>

          <button id="dlabAuditBtn"
                  class="dlab-btn dlab-btn-ghost"
                  type="button"
                  hidden>
            📋 Auditoria
          </button>

          <button id="dlabMyPasswordBtn"
                  class="dlab-btn dlab-btn-ghost"
                  type="button">
            🔐 Trocar minha senha
          </button>

          <span id="dlabUnreadBadge"
                class="dlab-unread-badge"
                hidden>0 nova</span>

          <button id="dlabSoundToggle"
                  class="dlab-btn dlab-btn-ghost dlab-sound-btn"
                  type="button"
                  hidden
                  aria-pressed="true">
            🔊 Som ligado
          </button>

          <button id="dlabOperatorLogout"
                  class="dlab-btn dlab-btn-logout"
                  type="button">↪ Sair</button>
        </div>

        <div id="dlabBirthWarning"
             class="dlab-birth-warning"
             hidden>
          Complete seu dia e mês reais de aniversário
          para habilitar a recuperação da sua conta.
          <button id="dlabSetBirthBtn"
                  type="button">
            Completar agora
          </button>
        </div>

        <div id="dlabUserNotice"
             class="dlab-user-notice"
             hidden>
          Sua conta está ativa.
          O envio de mensagens APRS pelo painel está habilitado.
          As funções administrativas continuam restritas
          às contas autorizadas.
        </div>

        <form id="dlabMessageForm"
              class="dlab-message-form"
              novalidate>

          <label for="dlabMessageDest">
            Destinatário APRS
          </label>

          <input id="dlabMessageDest"
                 type="text"
                 maxlength="9"
                 autocomplete="off"
                 placeholder="Ex.: PU2ABC-7"
                 required>

          <label for="dlabMessageText">
            Mensagem
          </label>

          <textarea id="dlabMessageText"
                    maxlength="60"
                    rows="3"
                    placeholder="Texto APRS curto, sem acentos."
                    required></textarea>

          <div class="dlab-message-footer">
            <span>
              <b id="dlabMessageCount">0</b>/60
            </span>

            <button id="dlabMessageSend"
                    class="dlab-btn dlab-btn-primary"
                    type="submit">
              Enviar mensagem APRS
            </button>
          </div>
        </form>

        <div id="dlabPrivateHistory"
             class="dlab-private-history">

          <div class="dlab-feed-title">
            <strong>Mensagens do operador</strong>
            <span>
              Conteúdo visível somente ao administrador.
            </span>
          </div>

          <div id="dlabOperatorMessages"
               class="dlab-private-message-list">
            <div class="dlab-empty">
              Nenhuma mensagem.
            </div>
          </div>
        </div>
      </div>

    </div>

    <dialog id="dlabAccountDialog"
            class="dlab-account-dialog">

      <div class="dlab-dialog-head">
        <strong id="dlabDialogTitle">
          Administração
        </strong>

        <button id="dlabDialogClose"
                type="button"
                aria-label="Fechar">
          ×
        </button>
      </div>

      <div id="dlabDialogBody"
           class="dlab-dialog-body"></div>
    </dialog>

    <div class="dlab-command-feed">
      <div class="dlab-feed-title">
        <strong>Atividade pública de comandos</strong>
        <span>
          Mensagens pessoais continuam fora do painel público.
        </span>
      </div>

      <div id="dlabCommands" class="dlab-command-list">
        <div class="dlab-empty">Nenhum comando registrado.</div>
      </div>
    </div>
  </section>

  <script src="/assets/digital-lab-operator.js?v=1.2.3" defer></script>

  <section class="dlab-knowledge panel" aria-labelledby="dlabLearnTitle">
    <div class="dlab-card-heading"><div><p class="eyebrow">APRENDA SEM COMPLICAÇÃO</p><h2 id="dlabLearnTitle">Entenda o que está acontecendo</h2></div></div>
    <div class="dlab-knowledge-grid">
      <details open><summary>O que é D-PRS?</summary><p>É a conversão das informações de GPS enviadas pelo D-STAR para um formato que pode ser entendido pelo ecossistema APRS. No APRS / D-PRS, o módulo B é usado para observar esse dado durante a transmissão.</p></details>
      <details><summary>O que é GPS-A?</summary><p>É o formato APRS usado diretamente por vários rádios D-STAR compatíveis. Quando disponível no equipamento, costuma ser o caminho mais simples para testar posição no laboratório.</p></details>
      <details><summary>O que é APRS-IS?</summary><p>É a infraestrutura APRS pela Internet. O serviço APRS / D-PRS mantém essa conexão separada do XLXD, permitindo receber comandos e responder sem colocar o serviço de voz no caminho crítico.</p></details>
      <details><summary>Preciso deixar a página aberta?</summary><p>Não para o gateway funcionar. A página é apenas o painel de acompanhamento. Quando aberta, ela consulta um pequeno arquivo local e atualiza os resultados sem processamento pesado.</p></details>
    </div>
  </section>


  <!-- XLX_APRS_FAQ_V2 -->
  <!-- XLX_APRS_FAQ_V4_ACCORDION -->
  <section class="dlab-faq panel" id="aprsFaq" aria-labelledby="aprsFaqTitle">
    <div class="dlab-card-heading">
      <div>
        <p class="eyebrow">GUIA RÁPIDO • PERGUNTAS FREQUENTES</p>
        <h2 id="aprsFaqTitle">APRS e D-PRS sem complicação</h2>
      </div>
    </div>

    <p class="dlab-faq-intro">
      Este guia explica o básico em linguagem simples. APRS não é apenas
      “mostrar um ponto no mapa”: ele também permite compartilhar informações
      curtas e úteis em tempo real, trocar mensagens por indicativo e integrar
      estações de rádio à rede APRS-IS.
    </p>

    <div class="dlab-faq-grid">
      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton1"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel1">
            <span>O que é APRS?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel1"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton1"
          hidden>
          <p>APRS significa <strong>Automatic Packet Reporting System</strong>. É um sistema de comunicação digital do radioamadorismo criado por Bob Bruninga, WB4APR. Ele usa pacotes curtos para divulgar posição, movimento, estado da estação, mensagens e outras informações úteis em tempo real.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton2"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel2">
            <span>APRS é somente rastreamento de veículos?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel2"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton2"
          hidden>
          <p>Não. A posição por GPS ficou muito conhecida, mas o objetivo do APRS é comunicação e informação operacional em tempo real. Ele pode ser usado para posição, mensagens entre indicativos, informações locais, eventos, telemetria e apoio a operações de radioamadores.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton3"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel3">
            <span>O que é um beacon?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel3"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton3"
          hidden>
          <p>Beacon é um pacote curto transmitido pela estação. Ele pode informar sua posição, símbolo, curso, velocidade ou um pequeno texto de estado. Em uma estação móvel, um GPS pode fornecer automaticamente a posição. Uma estação fixa também pode usar coordenadas previamente configuradas.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton4"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel4">
            <span>Preciso ter GPS para usar APRS?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel4"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton4"
          hidden>
          <p>Não para todas as funções. GPS é especialmente útil para estações móveis porque fornece a posição atual automaticamente. Também é possível usar APRS para mensagens e, em estações fixas, trabalhar com uma posição configurada.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton5"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel5">
            <span>O que é D-PRS?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel5"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton5"
          hidden>
          <p>D-PRS é usado com D-STAR para aproveitar informações de posição GPS no modo digital e integrá-las ao ecossistema APRS. Em vários rádios Icom compatíveis, o modo <strong>GPS-A</strong> facilita a operação D-PRS. No XLX, o módulo B recebe esses dados para o serviço APRS/D-PRS.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton6"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel6">
            <span>O que é um digipeater?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel6"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton6"
          hidden>
          <p>É um repetidor de pacotes digitais. Ele recebe um pacote APRS pelo rádio e pode retransmiti-lo para ampliar a cobertura por RF. Diferentemente de uma repetidora de voz duplex, uma rede APRS VHF normalmente trabalha em uma frequência simplex.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton7"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel7">
            <span>O que é um IGate?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel7"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton7"
          hidden>
          <p>IGate é uma estação que faz a ponte entre o APRS pelo rádio e a rede APRS pela Internet. Assim, pacotes recebidos por RF podem chegar ao APRS-IS. Dependendo da configuração e das regras da rede, mensagens selecionadas também podem voltar da Internet para o rádio.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton8"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel8">
            <span>O que é APRS-IS?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel8"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton8"
          hidden>
          <p>APRS-IS é a infraestrutura APRS interligada pela Internet. Ela permite que dados recebidos por IGates sejam vistos em outros lugares e ajuda no encaminhamento de mensagens entre usuários APRS.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton9"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel9">
            <span>Qual é a frequência APRS em VHF no Brasil?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel9"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton9"
          hidden>
          <p>A LABRE informa <strong>145,570 MHz</strong> como a frequência padrão de APRS na faixa de 2 metros no Brasil. Isso se refere ao APRS por RF. D-PRS enviado por D-STAR através de hotspot/refletor é outro caminho e não significa que o rádio deva estar em 145,570 MHz ao usar o módulo B.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton10"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel10">
            <span>O que é SSID no indicativo APRS?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel10"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton10"
          hidden>
          <p>É o número depois do indicativo, por exemplo <strong>PY2ABC-9</strong>. No AX.25 existem 16 valores possíveis, de 0 a 15. O “-0” normalmente não aparece na tela, então <strong>PY2ABC</strong> equivale ao SSID 0. As associações abaixo são <strong>recomendações</strong>, não regras rígidas.</p>

        <div class="dlab-ssid-table-wrap">
          <table class="dlab-ssid-table">
            <thead><tr><th>SSID</th><th>Uso recomendado</th></tr></thead>
            <tbody>
              <tr><td>sem SSID / -0</td><td>Estação principal, normalmente fixa e capaz de mensagens</td></tr>
              <tr><td>-1 a -4</td><td>Estações adicionais: digi, móvel, meteorológica etc.</td></tr>
              <tr><td>-5</td><td>Outras redes, incluindo D-STAR e dispositivos/aplicativos</td></tr>
              <tr><td>-6</td><td>Atividade especial, satélite, camping, testes etc.</td></tr>
              <tr><td>-7</td><td>HT / walkie-talkie / estação portátil pessoal</td></tr>
              <tr><td>-8</td><td>Barco, motorhome/RV ou segundo móvel principal</td></tr>
              <tr><td>-9</td><td>Móvel principal, normalmente capaz de mensagens</td></tr>
              <tr><td>-10</td><td>Internet, IGate, EchoLink, Winlink e serviços semelhantes</td></tr>
              <tr><td>-11</td><td>Balão, aeronave ou veículo espacial</td></tr>
              <tr><td>-12</td><td>APRS por DTMF/RFID, dispositivos e trackers de uma via</td></tr>
              <tr><td>-13</td><td>Estação meteorológica</td></tr>
              <tr><td>-14</td><td>Caminhão / motorista profissional ou em tempo integral</td></tr>
              <tr><td>-15</td><td>Estação adicional genérica</td></tr>
            </tbody>
          </table>
        </div>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton11"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel11">
            <span>Qual SSID devo usar no meu rádio?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel11"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton11"
          hidden>
          <p>Use o que melhor descreve <strong>como aquela estação está sendo usada</strong>. Um HT portátil normalmente combina com -7; um móvel principal com -9; uma estação ligada à Internet/IGate com -10. Para D-STAR/D-PRS, -5 aparece nas recomendações para “outras redes”, mas um HT D-STAR pessoal ainda pode ser melhor identificado como -7 e um móvel como -9. O SSID não muda a sua licença nem a classe da estação.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton12"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel12">
            <span>Por que o serviço deste painel usa -10?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel12"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton12"
          hidden>
          <p>Porque este endereço é o <strong>serviço APRS ligado ao APRS-IS</strong>, e a recomendação histórica reserva -10 para Internet, IGates e serviços semelhantes. Isso não quer dizer que todos os usuários devam usar -10.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton13"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel13">
            <span>Posso usar -110?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel13"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton13"
          hidden>
          <p>Não como SSID normal de uma estação AX.25/APRS. O campo de SSID possui apenas os valores de 0 a 15. Portanto, se o endereço do serviço for algo como <strong>{{APRS_SERVICE_CALLSIGN}}</strong>, use exatamente <strong>-10</strong>.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton14"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel14">
            <span>Como envio uma mensagem APRS por este painel?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel14"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton14"
          hidden>
          <p>Primeiro crie sua conta e entre com seu indicativo e senha. Uma conta <strong>ativa</strong> pode preencher o destinatário APRS e uma mensagem curta e pressionar “Enviar mensagem APRS”. As funções administrativas continuam separadas e exclusivas das contas autorizadas.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton15"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel15">
            <span>Por que as mensagens devem ser curtas?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel15"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton15"
          hidden>
          <p>APRS foi projetado para dados breves e de valor imediato. Em RF, todos compartilham um canal de baixa velocidade, portanto transmissões desnecessárias aumentam colisões e congestionamento. Use mensagens objetivas e evite repetir beacons ou textos sem necessidade.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton16"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel16">
            <span>O que significa ACK em uma mensagem?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel16"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton16"
          hidden>
          <p>ACK é a confirmação técnica usada pelo protocolo de mensagens APRS. Ela indica que a mensagem foi confirmada pelo sistema de destino; não deve ser interpretada automaticamente como “a pessoa leu”.</p>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton17"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel17">
            <span>Quais regras de boa convivência devo respeitar?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel17"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton17"
          hidden>
          <ul>
          <li>Use seu indicativo corretamente e não se passe por outra estação.</li>
          <li>Para transmitir por RF no Brasil, opere dentro das regras do Serviço de Radioamador e com a habilitação/licenciamento aplicáveis.</li>
          <li>O Serviço de Radioamador é pessoal e não deve ter finalidade comercial.</li>
          <li>Mantenha beacons e mensagens curtos, úteis e sem transmissões excessivas.</li>
          <li>Use caminho/digipeaters de acordo com a rede da sua região; não copie configurações de outro país ou local sem verificar.</li>
          <li>Lembre que uma posição enviada ao APRS-IS pode ficar visível em serviços públicos de mapas. Não transmita informação pessoal que você não queira divulgar.</li>
          <li>Em emergência, dê prioridade ao tráfego necessário e siga as orientações das redes locais de radioamadores.</li>
        </ul>
        </div>
      </div>

      <div class="dlab-faq-item">
        <h3 class="dlab-faq-heading">
          <button
            id="dlabFaqButton18"
            class="dlab-faq-toggle"
            type="button"
            aria-expanded="false"
            aria-controls="dlabFaqPanel18">
            <span>APRS funciona sem Internet?</span>
            <span class="dlab-faq-icon" aria-hidden="true">+</span>
          </button>
        </h3>
        <div
          id="dlabFaqPanel18"
          class="dlab-faq-panel"
          aria-labelledby="dlabFaqButton18"
          hidden>
          <p>Sim. APRS nasceu como comunicação por rádio e pode funcionar entre estações e digipeaters por RF. A Internet amplia a cobertura através dos IGates e do APRS-IS, mas não é o conceito básico do sistema.</p>
        </div>
      </div>
    </div>

    <div class="dlab-faq-sources">
      <strong>Fontes técnicas consultadas:</strong>
      <a href="https://www.aprs.org/aprs11/SSIDs.txt" target="_blank" rel="noopener noreferrer">APRS.org — recomendações de SSID</a>
      <a href="https://www.aprs.org/aprs11.html" target="_blank" rel="noopener noreferrer">APRS Specification Addendum 1.1</a>
      <a href="https://www.arrl.org/aprs-mode" target="_blank" rel="noopener noreferrer">ARRL — APRS Mode</a>
      <a href="https://www.labre.org.br/labre-ce-inaugura-digipeater-aprs-em-fortaleza/" target="_blank" rel="noopener noreferrer">LABRE — APRS no Brasil</a>
      <a href="https://www.icomamerica.com/explore/d-star/" target="_blank" rel="noopener noreferrer">Icom — D-STAR e GPS</a>
      <a href="https://www.gov.br/anatel/pt-br/regulado/outorga/radioamador-e-radio-cidadao/radioamador" target="_blank" rel="noopener noreferrer">Anatel — Serviço Radioamador</a>
    </div>
  </section>

  <section class="dlab-architecture panel">
    <div class="dlab-card-heading"><div><p class="eyebrow">COMO FUNCIONA</p><h2>Conexão real com o módulo B, sem interferir na voz</h2></div></div>
    <div class="dlab-flow" role="img" aria-label="Fluxo Rádio para {{REFLECTOR_NAME}} B, Data Gateway, APRS-IS e painel">
      <div><strong>RÁDIO / HOTSPOT</strong><span>D-STAR</span></div><i>→</i>
      <div class="is-accent"><strong>{{REFLECTOR_NAME}}-B</strong><span>DV + Slow Data</span></div><i>→</i>
      <div><strong>DATA GATEWAY</strong><span>D-PRS / GPS / Texto</span></div><i>→</i>
      <div><strong>APRS / D-PRS</strong><span>Painel + APRS-IS</span></div>
    </div>
    <p class="dlab-fineprint">A versão inicial é deliberadamente passiva no módulo B: recebe e interpreta dados, mas não injeta quadros DV no reflector. O envio APRS ocorre somente pelo APRS-IS quando a conta de serviço estiver configurada e verificada.</p>
  </section>

  <div id="dlabToast" class="dlab-toast" role="status" aria-live="polite" hidden></div>
</section>
