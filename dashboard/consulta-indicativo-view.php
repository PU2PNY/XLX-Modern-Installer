<?php
require_once __DIR__.'/callsign-registry.php';
$lookup = xlx_lookup_data($_GET);
$fmt = static fn($n) => number_format((int)$n, 0, ',', '.');
$cell = static fn($v) => xlx_lookup_html($v === '' ? '—' : $v);
?>
<link rel="stylesheet" href="/assets/consulta-indicativo-local-v2.css?v=20261021-2">
<section class="callsign-lookup panel" aria-labelledby="callsignLookupTitle">
 <div class="callsign-lookup-heading">
  <div><p class="eyebrow">DIRETÓRIO DE RADIOAMADORES</p><h1 id="callsignLookupTitle">Consulta de indicativo</h1><p>Encontre indicativos, titulares e estações na base da Anatel.</p></div>
  <a class="lookup-official" href="https://informacoes.anatel.gov.br/paineis/outorga-e-licenciamento/estacoes-radioamador" target="_blank" rel="noopener noreferrer">Fonte oficial · Anatel ↗</a>
 </div>
 <?php if ($lookup['ready']): ?>
 <div class="lookup-summary" aria-label="Resumo da base">
  <span><b><?=$fmt($lookup['meta']['callsigns'] ?? 0)?></b> indicativos</span><span><b><?=$fmt($lookup['meta']['rows'] ?? 0)?></b> registros de estações</span><span class="lookup-snapshot">Cópia local · importada em <?=xlx_lookup_html(gmdate('d/m/Y', strtotime($lookup['meta']['imported_at_utc'] ?? 'now')))?></span>
 </div>
 <form class="lookup-filters" method="get" action="/consulta-indicativo.php" role="search" aria-label="Pesquisar indicativos">
  <label class="lookup-search"><span>Indicativo, titular ou município</span><input type="search" name="q" value="<?=xlx_lookup_html($lookup['q'])?>" maxlength="80" placeholder="Ex.: PU2PNY ou Santa Isabel" autocomplete="off"></label>
  <label><span>UF do titular</span><select name="uf"><option value="">Todas</option><?php foreach($lookup['ufs'] as $value): ?><option value="<?=$value?>"<?=$lookup['uf']===$value?' selected':''?>><?=$value?></option><?php endforeach; ?></select></label>
  <label><span>Classe COER</span><select name="coer"><option value="">Todas</option><?php foreach($lookup['classes'] as $value): ?><option value="<?=xlx_lookup_html($value)?>"<?=$lookup['coer']===$value?' selected':''?>><?=xlx_lookup_html($value)?></option><?php endforeach; ?></select></label>
  <label><span>Tipo de estação</span><select name="tipo"><option value="">Todas</option><?php foreach($lookup['types'] as $value): ?><option value="<?=xlx_lookup_html($value)?>"<?=$lookup['tipo']===$value?' selected':''?>><?=xlx_lookup_html($value)?></option><?php endforeach; ?></select></label>
  <button type="submit">Pesquisar</button><a class="lookup-reset" href="/consulta-indicativo.php">Limpar</a>
 </form>
 <div class="lookup-results-heading"><h2><?=$fmt($lookup['total'])?> registros encontrados</h2><span>25 por página</span></div>
 <div class="lookup-table-wrap" role="region" aria-label="Resultados da consulta de indicativos" tabindex="0">
 <table class="lookup-table"><thead><tr><th>Indicativo</th><th>Titular / entidade</th><th>Classe / estação</th><th>Município da estação</th><th>UF do titular</th><th>Validade no arquivo</th></tr></thead><tbody>
 <?php foreach ($lookup['rows'] as $row): ?>
 <tr><td><strong class="lookup-callsign"><?=$cell($row['callsign'])?></strong></td><td><?=$cell($row['holder'])?></td><td><?=$cell($row['class'])?><small><?=$cell($row['type'])?></small></td><td><?=$cell($row['city'])?><?php if($row['station_uf']!==''): ?><small><?=xlx_lookup_html($row['station_uf'])?></small><?php endif; ?></td><td><?=$cell($row['holder_uf'])?></td><td><span class="lookup-validity<?=$row['validity']==='Ativa'?' lookup-valid':($row['validity']==='Vencida'?' lookup-expired':'')?>"><?=$cell($row['validity'])?></span><small><?=$cell($row['expires'])?></small></td></tr>
 <?php endforeach; ?>
 <?php if (!$lookup['rows']): ?><tr><td colspan="6" class="lookup-empty">Nenhum registro encontrado. Tente outro indicativo ou ajuste os filtros.</td></tr><?php endif; ?>
 </tbody></table></div>
 <nav class="lookup-pagination" aria-label="Páginas dos resultados">
 <?php if ($lookup['page']>1): ?><a href="<?=xlx_lookup_html(xlx_lookup_page_url($lookup, $lookup['page']-1))?>" rel="prev">← Anterior</a><?php else: ?><span aria-disabled="true">← Anterior</span><?php endif; ?>
 <span>Página <?=$fmt($lookup['page'])?> / <?=$fmt($lookup['pages'])?></span>
 <?php if ($lookup['page']<$lookup['pages']): ?><a href="<?=xlx_lookup_html(xlx_lookup_page_url($lookup, $lookup['page']+1))?>" rel="next">Próxima →</a><?php else: ?><span aria-disabled="true">Próxima →</span><?php endif; ?>
 </nav>
 <p class="lookup-disclaimer">Fonte: Estacoes_Radioamador.csv, fornecido pela Anatel. Consulta a uma cópia do arquivo, sem atualização em tempo real. Um indicativo pode ter várias estações. “—” indica dado não informado ou não aplicável. A validade é reproduzida conforme o arquivo; confirme a situação atual na fonte oficial.</p>
 <?php else: ?><p class="lookup-empty">A base local ainda não está disponível. A consulta oficial continua acessível pelo link acima.</p><?php endif; ?>
</section>
