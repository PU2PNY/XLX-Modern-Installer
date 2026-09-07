<?php
declare(strict_types=1);

/*
 * XLX APRS/D-PRS — conteúdo da página.
 * A identidade do refletor e o indicativo APRS vêm do config.json local.
 */
$dlabConfigPath = '/etc/xlx-aprs-dprs/config.json';
$dlabConfig = [];

if (is_readable($dlabConfigPath)) {
    $raw = file_get_contents($dlabConfigPath);
    $parsed = is_string($raw) ? json_decode($raw, true) : null;
    if (is_array($parsed)) {
        $dlabConfig = $parsed;
    }
}

$dlabReflector = strtoupper(trim((string)($dlabConfig['site']['reflector'] ?? 'XLX')));
$dlabModule = strtoupper(substr(trim((string)($dlabConfig['site']['module'] ?? 'B')), 0, 1));
$dlabAprsService = strtoupper(trim((string)($dlabConfig['aprs']['login'] ?? '')));
$dlabAprsLabel = $dlabAprsService !== '' ? $dlabAprsService : 'indicativo APRS configurado';

$dlabEsc = static fn(string $value): string =>
    htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
?>
<section class="dlab-page"
         id="digitalLab"
         aria-labelledby="dlabTitle"
         data-api="api/digital-lab.php"
         data-operator-api="api/digital-lab-operator.php">
  <header class="dlab-hero panel">
    <div class="dlab-hero-copy">
      <p class="eyebrow"><?= $dlabEsc($dlabReflector) ?> • MÓDULO <?= $dlabEsc($dlabModule) ?></p>
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
      <div><small><?= $dlabEsc($dlabReflector . '-' . $dlabModule) ?></small><strong id="dlabModuleStatus">Verificando…</strong><span id="dlabModuleDetail">DExtra somente recepção</span></div>
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
      <p>Informe seu indicativo, conecte ao <strong><?= $dlabEsc($dlabReflector . '-' . $dlabModule) ?></strong> e transmita com GPS/D-PRS ativado. A página confirma quando o beacon for recebido.</p>
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
        <li><span>1</span><div><strong>Conecte ao módulo B</strong><p>No hotspot ou rádio, selecione o <?= $dlabEsc($dlabReflector) ?> e o módulo <b><?= $dlabEsc($dlabModule) ?></b>.</p></div></li>
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
        o serviço APRS configurado é <strong><?= $dlabEsc($dlabAprsLabel) ?></strong>.
        Quando estiver logado como ADMIN, clicar em um comando abaixo
        coloca o texto diretamente no campo <strong>Mensagem</strong>.
        Para testar os comandos do próprio serviço usando um rádio ou aplicativo APRS,
        envie a mensagem para <strong><?= $dlabEsc($dlabAprsLabel) ?></strong>.
      </p>

      <div class="dlab-ssid-note">
        <strong>Por que usar um SSID APRS dedicado?</strong>
        <span>
          O instalador permite configurar um indicativo com SSID dedicado, por exemplo <b>PY2ABC-10</b>.
          O painel se conecta ao APRS-IS como <b><?= $dlabEsc($dlabAprsLabel) ?></b>,
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
        <span>Mostra o estado do refletor e do módulo B.</span>
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
              futuramente para recursos de aniversário no painel.
            </p>

            <p>
              Antes do cadastro, faça um beacon D-PRS pelo módulo B
              ou envie uma mensagem APRS para
              <strong><?= $dlabEsc($dlabAprsLabel) ?></strong>.
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
          Os comandos APRS públicos continuam disponíveis acima.
          O envio APRS pelo painel administrativo permanece
          restrito ao administrador nesta etapa.
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
  <section class="dlab-knowledge panel" aria-labelledby="dlabLearnTitle">
    <div class="dlab-card-heading"><div><p class="eyebrow">APRENDA SEM COMPLICAÇÃO</p><h2 id="dlabLearnTitle">Entenda o que está acontecendo</h2></div></div>
    <div class="dlab-knowledge-grid">
      <details open><summary>O que é D-PRS?</summary><p>É a conversão das informações de GPS enviadas pelo D-STAR para um formato que pode ser entendido pelo ecossistema APRS. No APRS / D-PRS, o módulo B é usado para observar esse dado durante a transmissão.</p></details>
      <details><summary>O que é GPS-A?</summary><p>É o formato APRS usado diretamente por vários rádios D-STAR compatíveis. Quando disponível no equipamento, costuma ser o caminho mais simples para testar posição no laboratório.</p></details>
      <details><summary>O que é APRS-IS?</summary><p>É a infraestrutura APRS pela Internet. O serviço APRS / D-PRS mantém essa conexão separada do XLXD, permitindo receber comandos e responder sem colocar o serviço de voz no caminho crítico.</p></details>
      <details><summary>Preciso deixar a página aberta?</summary><p>Não para o gateway funcionar. A página é apenas o painel de acompanhamento. Quando aberta, ela consulta um pequeno arquivo local e atualiza os resultados sem processamento pesado.</p></details>
    </div>
  </section>

  <section class="dlab-architecture panel">
    <div class="dlab-card-heading"><div><p class="eyebrow">COMO FUNCIONA</p><h2>Conexão real com o módulo B, sem interferir na voz</h2></div></div>
    <div class="dlab-flow" role="img" aria-label="Fluxo Rádio para o módulo B, Data Gateway, APRS-IS e painel">
      <div><strong>RÁDIO / HOTSPOT</strong><span>D-STAR</span></div><i>→</i>
      <div class="is-accent"><strong><?= $dlabEsc($dlabReflector . '-' . $dlabModule) ?></strong><span>DV + Slow Data</span></div><i>→</i>
      <div><strong>DATA GATEWAY</strong><span>D-PRS / GPS / Texto</span></div><i>→</i>
      <div><strong>APRS / D-PRS</strong><span>Painel + APRS-IS</span></div>
    </div>
    <p class="dlab-fineprint">A versão inicial é deliberadamente passiva no módulo B: recebe e interpreta dados, mas não injeta quadros DV no reflector. O envio APRS ocorre somente pelo APRS-IS quando a conta de serviço estiver configurada e verificada.</p>
  </section>

  <div id="dlabToast" class="dlab-toast" role="status" aria-live="polite" hidden></div>
</section>
