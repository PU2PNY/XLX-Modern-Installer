<?php
/* XLX026_SEO_AI_BUSCADORES_V2 — JSON-LD complementar */
if (!isset($page, $meta, $canonical)) { return; }

$pageKey = $page === 'aprs-dprs' ? 'digital-lab' : $page;
$pageTypes = [
 'ao-vivo' => 'WebPage',
 'conectados' => 'WebPage',
 'digital-lab' => 'WebPage',
 'ranking' => 'WebPage',
 'certificado' => 'WebPage',
 'refletores' => 'CollectionPage',
 'suporte' => 'CollectionPage',
 'simulado' => 'LearningResource',
 'simulado-anatel' => 'LearningResource',
];
$type = $pageTypes[$pageKey] ?? 'WebPage';

$graph = [
 [
  '@type' => 'WebPage',
  '@id' => $canonical . '#webpage',
  'url' => $canonical,
  'name' => $meta['title'],
  'description' => $meta['description'],
  'inLanguage' => 'pt-BR',
  'isPartOf' => ['@id' => 'https://xlx026.net/#website'],
  'about' => [
    ['@type' => 'Thing', 'name' => 'XLX026 Brasil'],
    ['@type' => 'Thing', 'name' => 'Radioamadorismo'],
    ['@type' => 'Thing', 'name' => 'D-STAR'],
    ['@type' => 'Thing', 'name' => 'DMR'],
    ['@type' => 'Thing', 'name' => 'C4FM/YSF'],
  ],
 ],
 [
  '@type' => 'BreadcrumbList',
  '@id' => $canonical . '#breadcrumb',
  'itemListElement' => [
    ['@type'=>'ListItem','position'=>1,'name'=>'XLX026 Brasil','item'=>'https://xlx026.net/ao-vivo'],
    ['@type'=>'ListItem','position'=>2,'name'=>$meta['title'],'item'=>$canonical],
  ],
 ],
];
$graph[0]['@type'] = $type;

if ($pageKey === 'conectados') {
 $graph[] = [
  '@type' => 'ItemList',
  '@id' => $canonical . '#modulos',
  'name' => 'Módulos oficiais do XLX026 Brasil',
  'itemListOrder' => 'https://schema.org/ItemListOrderAscending',
  'itemListElement' => [
   ['@type'=>'ListItem','position'=>1,'item'=>['@type'=>'Thing','name'=>'Módulo A','description'=>'Imagens e serviços relacionados à transmissão de imagens.']],
   ['@type'=>'ListItem','position'=>2,'item'=>['@type'=>'Thing','name'=>'Módulo B','description'=>'Beacons, APRS/D-PRS e dados relacionados.']],
   ['@type'=>'ListItem','position'=>3,'item'=>['@type'=>'Thing','name'=>'Módulo C','description'=>'Fonia digital DMR e C4FM/YSF.']],
   ['@type'=>'ListItem','position'=>4,'item'=>['@type'=>'Thing','name'=>'Módulo D','description'=>'Fonia digital D-STAR.']],
   ['@type'=>'ListItem','position'=>5,'item'=>['@type'=>'Thing','name'=>'Módulo E','description'=>'Eco e testes de áudio.']],
  ],
 ];
}
?>
<script id="xlx026SeoAiStructuredV2" type="application/ld+json"><?=json_encode(['@context'=>'https://schema.org','@graph'=>$graph], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?></script>
