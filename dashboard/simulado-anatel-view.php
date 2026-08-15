<?php /* XLX026 — Simulado nativo; shell vem integralmente do painel. */ ?>
<section class="simulado-native" aria-label="Simulado ANATEL para Radioamador">
<section class="simulado-hero" aria-labelledby="simuladoTitle">
    <div class="hero-topline">
      <p class="eyebrow">PREPARAÇÃO PARA RADIOAMADOR</p>
      <div class="utility-tools" aria-label="Ferramentas da página">
        <button id="fontBtn" type="button" aria-pressed="false">A+</button>
        <button id="contrastBtn" type="button" aria-pressed="false">Contraste</button>
        <button id="shareBtn" type="button">Compartilhar</button>
      </div>
    </div>
    <h1 id="simuladoTitle">Simulado para a Prova ANATEL — Radioamador 2026</h1>
    <p class="hero-lead">Treine para as Classes <strong>C, B e A</strong> no formato <strong>Certo ou Errado</strong>, com quantidade, mínimo e tempo por matéria configurados de acordo com o Ato nº 3.448/2026.</p>
    <div class="not-official" role="note" aria-label="Aviso de simulação educacional">
      <span>SIMULAÇÃO EDUCACIONAL · NÃO OFICIAL</span>
      <p><strong>Transparência:</strong> este simulador é um material independente do XLX026 Brasil para estudo. As questões são de treinamento, elaboradas a partir do conteúdo e de normas oficiais vigentes. <strong>Elas não são apresentadas como perguntas reais, copiadas ou integrantes do banco interno utilizado pela ANATEL nas avaliações.</strong></p>
    </div>
  </section>

  <section id="homeView" class="view" aria-labelledby="prepareTitle">
    <div class="section-heading">
      <div><p class="eyebrow">COMECE AQUI</p><h2 id="prepareTitle">Escolha sua preparação</h2></div>
      <span class="source-badge">Base normativa revisada em 14/08/2026</span>
    </div>
    <div class="cards">
      <button class="class-card" data-class="C" type="button"><span>Classe C</span><b>Primeiro COER</b><small>45 questões · 3 matérias · 20 min por matéria</small></button>
      <button class="class-card" data-class="B" type="button"><span>Classe B</span><b>Classe B / progressão C → B</b><small>60 questões · 3 matérias · 30 min por matéria</small></button>
      <button class="class-card" data-class="A" type="button"><span>Classe A</span><b>Progressão B → A</b><small>90 questões · 3 matérias · 40 min por matéria</small></button>
    </div>
    <div id="eligibility" class="eligibility" aria-live="polite"></div>
    <div class="mode-row">
      <button id="officialMode" class="primary" type="button" disabled>Simulado completo</button>
      <button id="trainingMode" type="button" disabled>Treinar por matéria</button>
      <button id="reviewMode" type="button">Revisar meus erros</button>
    </div>
    <section class="rules" aria-labelledby="formatTitle">
      <div class="section-heading compact"><div><p class="eyebrow">FORMATO DA SIMULAÇÃO</p><h3 id="formatTitle">Quantidade, mínimo e tempo</h3></div></div>
      <div class="rule-grid">
        <div><b>Classe C</b><span>15 por matéria · mínimo 8 · 20 min</span></div>
        <div><b>Classe B</b><span>20 por matéria · mínimo 11 · 30 min</span></div>
        <div><b>Classe A</b><span>30 por matéria · mínimo 16 · 40 min</span></div>
      </div>
    </section>
  </section>

  <section id="subjectView" class="view hidden" aria-labelledby="subjectTitle">
    <button class="back" data-back="home" type="button">← Voltar</button>
    <p class="eyebrow">TREINO DIRECIONADO</p>
    <h2 id="subjectTitle">Treino por matéria</h2>
    <div class="cards subjects">
      <button data-subject="leg" type="button"><span>Legislação</span><small>Normas, COER, classes e requisitos</small></button>
      <button data-subject="op" type="button"><span>Técnica e Ética</span><small>Operação, propagação, procedimentos e boas práticas</small></button>
      <button data-subject="elec" type="button"><span>Eletrônica e Eletricidade</span><small>Conteúdo técnico compatível com a classe escolhida</small></button>
    </div>
  </section>

  <section id="quizView" class="view hidden" aria-labelledby="quizTitle">
    <div class="quiz-head"><div><p id="quizMode" class="eyebrow"></p><h2 id="quizTitle"></h2></div><div id="timer" class="timer" aria-live="polite"></div></div>
    <div class="question-origin">QUESTÃO DE TREINAMENTO · NÃO É QUESTÃO OFICIAL DA PROVA</div>
    <div class="progress" aria-hidden="true"><i id="progressBar"></i></div><div id="progressText" class="progress-text"></div>
    <article class="question-card">
      <p id="questionText" class="question"></p>
      <div class="answers"><button id="trueBtn" type="button">CERTO</button><button id="falseBtn" type="button">ERRADO</button></div>
      <div id="feedback" class="feedback hidden"></div>
    </article>
    <div class="quiz-actions"><button id="quitBtn" type="button">Encerrar</button><button id="nextBtn" class="primary hidden" type="button">Próxima</button></div>
  </section>

  <section id="resultView" class="view hidden" aria-labelledby="resultTitle">
    <button class="back" data-back="home" type="button">← Início</button><h2 id="resultTitle">Resultado do treinamento</h2><div id="resultSummary"></div><div id="resultDetails"></div>
  </section>

  <section class="sources" aria-labelledby="sourcesTitle">
    <div class="section-heading compact"><div><p class="eyebrow">RASTREABILIDADE</p><h2 id="sourcesTitle">Fontes oficiais usadas para validar o conteúdo</h2></div></div>
    <p>As referências aparecem também na correção das questões. O XLX026 usa fontes normativas para sustentar as respostas, mas isso <strong>não transforma as questões de treinamento em questões oficiais da prova</strong>.</p>
    <ul>
      <li><a href="https://informacoes.anatel.gov.br/legislacao/atos-de-requisitos-operacionais-de-outorga-e-licenciamento/2148-ato-3448-26" target="_blank" rel="noopener noreferrer">Ato ANATEL nº 3.448/2026</a></li>
      <li><a href="https://informacoes.anatel.gov.br/legislacao/resolucoes/2025/2022-resolucao-777" target="_blank" rel="noopener noreferrer">Resolução nº 777/2025 — RGST</a></li>
      <li><a href="https://informacoes.anatel.gov.br/legislacao/component/content/article/165-atos-de-requisitos-tecnicos-de-gestao-do-espectro/2024/1919-ato-926" target="_blank" rel="noopener noreferrer">Ato nº 926/2024 — faixas e requisitos técnicos</a></li>
      <li><a href="https://informacoes.anatel.gov.br/legislacao/resolucoes/2026/2157-resolucao-789" target="_blank" rel="noopener noreferrer">Resolução nº 789/2026 — PDFF</a></li>
      <li><a href="https://www.gov.br/anatel/pt-br/regulado/outorga/radioamador-e-radio-cidadao/habilitacao-do-radioamador" target="_blank" rel="noopener noreferrer">ANATEL — Habilitação do Radioamador</a></li>
    </ul>
  </section>

  <section class="study-guide" aria-labelledby="guideTitle">
    <div class="section-heading"><div><p class="eyebrow">GUIA RÁPIDO</p><h2 id="guideTitle">Como usar o simulador para estudar para a ANATEL</h2></div></div>
    <p>O Serviço de Radioamador possui classes diferentes e a avaliação de capacidade operacional e técnica exige preparação em mais de uma área. Este simulador organiza o estudo em Legislação de Telecomunicações, Técnica e Ética Operacional e Eletrônica e Eletricidade. A ideia é permitir que o candidato pratique conceitos previstos na regulamentação, identifique os assuntos em que erra com mais frequência e consulte a fonte normativa indicada na correção.</p>
    <div class="guide-grid">
      <article><h3>Classe C</h3><p>É a porta de entrada para muitos candidatos ao COER. No modo completo, a simulação apresenta três matérias separadas. O resultado é mostrado por disciplina para reforçar que o treinamento não deve considerar apenas a soma total de acertos.</p></article>
      <article><h3>Classe B</h3><p>O treinamento de Classe B amplia a cobrança técnica e mantém as três áreas de conhecimento. A página também informa as condições gerais de progressão para que o candidato saiba que aprovação em questões de treino não substitui os requisitos administrativos e regulamentares.</p></article>
      <article><h3>Classe A</h3><p>A Classe A exige preparação mais aprofundada. O banco de treinamento seleciona questões compatíveis com esse nível e reproduz a quantidade e o tempo configurados para a simulação, preservando a separação por matéria.</p></article>
    </div>
    <h3>O que significa “simulação educacional”?</h3>
    <p>Significa que o XLX026 procura reproduzir a experiência de estudo e o formato regulamentar, mas não afirma possuir acesso ao banco interno da ANATEL. Uma questão pode ensinar exatamente um conceito previsto em norma sem ter aparecido literalmente em uma prova. Essa distinção é importante para que o candidato saiba o que está estudando e para que o site não apresente material independente como se fosse conteúdo oficial.</p>
    <h3>Como aproveitar melhor o treino</h3>
    <p>Comece pelo simulado completo para medir seu nível geral. Depois use o treino por matéria para atacar os pontos fracos. Sempre que errar, leia a explicação e abra a fonte indicada. A função “Revisar meus erros” salva localmente no navegador as questões respondidas incorretamente e permite refazê-las. Esse histórico fica no próprio dispositivo e não representa registro ou resultado oficial da ANATEL.</p>
    <div class="faq" aria-label="Perguntas frequentes sobre o simulado">
      <details><summary>As perguntas deste simulador são as mesmas da prova real?</summary><p>Não. O XLX026 não declara que as perguntas sejam cópias do banco oficial ou que tenham sido sorteadas em avaliações reais. Elas são questões de treinamento cuja resposta deve estar sustentada por fonte normativa identificada.</p></details>
      <details><summary>O resultado obtido aqui vale como aprovação?</summary><p>Não. A pontuação serve apenas para estudo. Aprovação, inscrição, reaproveitamento de matérias e demais efeitos administrativos dependem exclusivamente dos procedimentos oficiais da ANATEL.</p></details>
      <details><summary>O simulador é da ANATEL?</summary><p>Não. É um projeto educacional independente do XLX026 Brasil. As referências externas levam às páginas oficiais para permitir que o candidato confirme a regulamentação utilizada.</p></details>
      <details><summary>Por que as fontes aparecem nas correções?</summary><p>Para que a pessoa não precise decorar respostas sem contexto. Quando possível, a correção indica a norma ou documento que fundamenta o conceito estudado, facilitando revisão e atualização futura do banco.</p></details>
    </div>
  </section>
</section>
