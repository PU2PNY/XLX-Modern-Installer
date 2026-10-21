<?php
declare(strict_types=1);

function xlx_lookup_text($value): string {
    return is_string($value) ? trim(mb_substr($value, 0, 80, 'UTF-8')) : '';
}
function xlx_lookup_html($value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
function xlx_lookup_data(array $input): array {
    $q = xlx_lookup_text($input['q'] ?? '');
    $uf = strtoupper(xlx_lookup_text($input['uf'] ?? ''));
    $class = xlx_lookup_text($input['coer'] ?? '');
    $type = xlx_lookup_text($input['tipo'] ?? '');
    $ufs = explode(' ', 'AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO');
    $classes = ['Classe A','Classe B','Classe C'];
    $types = ['Fixa','Móvel','Repetidora','Terrena'];
    if (!in_array($uf, $ufs, true)) $uf = '';
    if (!in_array($class, $classes, true)) $class = '';
    if (!in_array($type, $types, true)) $type = '';
    $page = isset($input['p']) && is_scalar($input['p']) ? max(1, min(10000, (int)$input['p'])) : 1;
    $result = ['q'=>$q,'uf'=>$uf,'coer'=>$class,'tipo'=>$type,'ufs'=>$ufs,'classes'=>$classes,'types'=>$types,'page'=>1,'pages'=>1,'total'=>0,'rows'=>[],'meta'=>[],'ready'=>false];
    $path = getenv('XLX_CALLSIGN_DB') ?: '/var/lib/xlx-modern-callsigns/registry.sqlite';
    if (!is_file($path) || !is_readable($path)) return $result;
    try {
        $db = new PDO('sqlite:'.$path, null, null, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT=>1]);
        $db->exec('PRAGMA query_only=ON; PRAGMA cache_size=-1024');
        $meta = $db->query('SELECT key,value FROM metadata')->fetchAll(PDO::FETCH_KEY_PAIR);
        if (($meta['schema_version'] ?? '') !== '1') return $result;
        $where = []; $params = [];
        if ($q !== '') {
            $normalized = strtoupper((string)iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $q));
            // Literal LIKE search: user percent/underscore never become wildcards.
            $params[':search'] = '%'.strtr($normalized, ['\\'=>'\\\\','%'=>'\\%','_'=>'\\_']).'%';
            $where[] = "search LIKE :search ESCAPE '\\'";
        }
        foreach (['holder_uf'=>$uf,'class'=>$class,'type'=>$type] as $column=>$value) {
            if ($value !== '') { $where[] = $column.' = :'.$column; $params[':'.$column] = $value; }
        }
        $clause = $where ? ' WHERE '.implode(' AND ', $where) : '';
        $stmt = $db->prepare('SELECT COUNT(*) FROM stations'.$clause);
        $stmt->execute($params); $total = (int)$stmt->fetchColumn();
        $pages = max(1, (int)ceil($total / 25)); $page = min($page, $pages);
        $stmt = $db->prepare("SELECT callsign,holder,class,type,city,station_uf,holder_uf,licensed,expires,validity FROM stations".$clause." ORDER BY (callsign=''),callsign,type,city LIMIT 25 OFFSET ".(($page-1)*25));
        $stmt->execute($params);
        $result = array_merge($result, ['page'=>$page,'pages'=>$pages,'total'=>$total,'rows'=>$stmt->fetchAll(PDO::FETCH_ASSOC),'meta'=>$meta,'ready'=>true]);
    } catch (Throwable $e) {
        // A lookup outage must not expose internal paths or affect the live radio.
        $result['ready'] = false;
    }
    return $result;
}
function xlx_lookup_page_url(array $result, int $page): string {
    return '/consulta-indicativo.php?'.http_build_query(['q'=>$result['q'],'uf'=>$result['uf'],'coer'=>$result['coer'],'tipo'=>$result['tipo'],'p'=>$page], '', '&', PHP_QUERY_RFC3986);
}
