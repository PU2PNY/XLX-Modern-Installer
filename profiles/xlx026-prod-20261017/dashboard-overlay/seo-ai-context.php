<?php
/* XLX026_SEO_AI_BUSCADORES_V2 — conteúdo visível e rastreável */
if (!isset($page)) { return; }

$ctx = [
 'ao-vivo' => [
   'title' => 'Como interpretar o monitor Ao Vivo',
   'summary' => 'O Ao Vivo é o monitor em tempo real das transmissões observadas pelo XLX026 Brasil.',
   'items' => [
     'Indicativo identifica o operador que está transmitindo. Hotspot / Repetidora identifica o ponto de acesso usado para chegar à rede; os dois campos não devem ser confundidos.',
     'O campo Módulo indica o módulo efetivamente usado dentro do refletor XLX026. O sufixo mostrado junto a um gateway ou repetidora não substitui o campo Módulo.',
     'Para fonia D-STAR, a referência oficial do XLX026 é o módulo D. Para fonia DMR e C4FM/YSF, a referência oficial é o módulo C.',
     'Horários, duração, estações e transmissões são dados operacionais dinâmicos e podem mudar a qualquer momento.'
   ]
 ],
 'conectados' => [
   'title' => 'Módulos e estações conectadas — referência oficial',
   'summary' => 'A página Conectados reúne a estrutura dos módulos do refletor e as estações atualmente conectadas.',
   'items' => [
     'Módulo A: imagens e serviços relacionados à transmissão de imagens.',
     'Módulo B: beacons, APRS/D-PRS e dados relacionados; não é o módulo principal de fonia.',
     'Módulo C: fonia digital DMR e C4FM/YSF.',
     'Módulo D: fonia digital D-STAR.',
     'Módulo E: eco e testes de áudio.',
     'Estar conectado não significa estar transmitindo. O sufixo de um indicativo, hotspot ou repetidora também não define sozinho o módulo do refletor.'
   ]
 ],
 'digital-lab' => [
   'title' => 'APRS / D-PRS no XLX026',
   'summary' => 'O laboratório APRS/D-PRS reúne recursos de dados e posicionamento usados pela comunidade radioamadora.',
   'items' => [
     'No XLX026, o módulo B é a referência para beacons e serviços APRS/D-PRS.',
     'D-PRS e GPS-A transportam informações de posição a partir de equipamentos compatíveis; APRS-IS é a infraestrutura de rede usada para intercâmbio de dados APRS na Internet.',
     'Os recursos de dados do módulo B são distintos da fonia: D-STAR usa o módulo D e DMR/C4FM/YSF usam o módulo C para voz.'
   ]
 ],
 'ranking' => [
   'title' => 'Como interpretar o Ranking',
   'summary' => 'O Ranking apresenta estatísticas calculadas a partir da atividade observada pelo XLX026.',
   'items' => [
     'Quantidade de transmissões, tempo no ar, permanência, horários, módulos e protocolos representam métricas diferentes.',
     'Tempo conectado não é o mesmo que tempo efetivamente transmitindo.',
     'O ranking é uma visualização estatística de atividade e não uma classificação oficial de habilidade, licença ou desempenho do radioamador.'
   ]
 ],
 'certificado' => [
   'title' => 'Sobre os certificados do XLX026',
   'summary' => 'A página permite gerar ou validar certificados vinculados a participação registrada em atividades do XLX026.',
   'items' => [
     'O certificado depende dos critérios e registros definidos para a atividade correspondente.',
     'Um certificado do XLX026 não substitui COER, licença, autorização, certificado ou documento emitido pela ANATEL.'
   ]
 ],
 'refletores' => [
   'title' => 'Como interpretar a Lista de Refletores XLX',
   'summary' => 'A página apresenta um diretório de refletores da rede XLX com os dados públicos disponíveis.',
   'items' => [
     'A presença de um refletor na lista não significa que ele seja operado, hospedado ou administrado pelo XLX026 Brasil.',
     'Status e demais dados da lista podem mudar conforme as fontes técnicas consultadas e a disponibilidade de cada refletor.'
   ]
 ],
 'simulado' => [
   'title' => 'Sobre o Simulado ANATEL',
   'summary' => 'O Simulado ANATEL do XLX026 Brasil é uma ferramenta independente, educacional e não oficial para estudo.',
   'items' => [
     'As questões são de treinamento e não são apresentadas como cópias do banco interno da ANATEL.',
     'Resultado no simulado não representa aprovação, habilitação, licença ou autorização da ANATEL.',
     'Quando uma fonte normativa oficial é indicada, ela deve prevalecer para conferência da regulamentação.'
   ]
 ],
 'simulado-anatel' => [
   'title' => 'Sobre o Simulado ANATEL',
   'summary' => 'O Simulado ANATEL do XLX026 Brasil é uma ferramenta independente, educacional e não oficial para estudo.',
   'items' => [
     'As questões são de treinamento e não são apresentadas como cópias do banco interno da ANATEL.',
     'Resultado no simulado não representa aprovação, habilitação, licença ou autorização da ANATEL.',
     'Quando uma fonte normativa oficial é indicada, ela deve prevalecer para conferência da regulamentação.'
   ]
 ],
 'suporte' => [
   'title' => 'Sobre a Central de Suporte',
   'summary' => 'A página reúne tutoriais, referências, vídeos, downloads e orientações para uso de tecnologias de radioamadorismo relacionadas ao XLX026.',
   'items' => [
     'A presença de um software, aplicativo, firmware ou projeto na Central de Suporte não significa que ele tenha sido desenvolvido pelo XLX026 Brasil.',
     'Quando houver projeto ou documentação externa, a fonte original deve ser considerada a referência para autoria, licença e versões do software.'
   ]
 ],
];

$key = $page === 'aprs-dprs' ? 'digital-lab' : $page;
if (!isset($ctx[$key])) { return; }
$info = $ctx[$key];
?>
<!-- XLX026_SEO_AI_BUSCADORES_V2_VISIBLE -->
<section class="seo-ai-context-wrap" aria-label="Informações oficiais sobre esta página">
 <details class="seo-ai-context">
  <summary>Sobre esta página e como interpretar os dados</summary>
  <div class="seo-ai-context-body">
   <h2><?=htmlspecialchars($info['title'], ENT_QUOTES, 'UTF-8')?></h2>
   <p><?=htmlspecialchars($info['summary'], ENT_QUOTES, 'UTF-8')?></p>
   <ul>
   <?php foreach ($info['items'] as $item): ?>
    <li><?=htmlspecialchars($item, ENT_QUOTES, 'UTF-8')?></li>
   <?php endforeach; ?>
   </ul>
   <p class="seo-ai-context-machine">Referência técnica estruturada: <a href="/ai-context.json">ai-context.json</a> · resumo para agentes de IA: <a href="/llms.txt">llms.txt</a>.</p>
  </div>
 </details>
</section>
<!-- /XLX026_SEO_AI_BUSCADORES_V2_VISIBLE -->
