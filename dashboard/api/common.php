<?php
declare(strict_types=1);
function cfg(): array { static $c; return $c ??= require dirname(__DIR__) . '/config.php'; }
function json_out(array $data,int $status=200): never { http_response_code($status); header('Content-Type: application/json; charset=utf-8'); header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0'); echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); exit; }
function norm_call(string $v): string { $v=strtoupper(trim($v)); $v=preg_replace('/[^A-Z0-9\/\- ]/','',$v)??''; return trim(explode(' ',preg_replace('/\s+/',' ',$v)??$v)[0]); }
function split_call_suffix(string $v): array { $v=trim(preg_replace('/\s+/',' ',$v)??$v); $p=explode(' ',$v); return [norm_call($p[0]??''),strtoupper(trim($p[1]??''))]; }
function qrz_url(string $c): string { return 'https://www.qrz.com/db/'.rawurlencode(norm_call($c)); }
function protocol_label(string $p): string { $k=strtoupper(preg_replace('/[^A-Z0-9+]/','',trim($p))??''); $m=['DMR'=>'DMR','DMRM'=>'DMR','DMRMMDVM'=>'DMR','DMRPLUS'=>'DMR','YSF'=>'C4FM/YSF','C4FMYSF'=>'C4FM/YSF','DCS'=>'D-STAR/DCS','DE'=>'D-STAR/DExtra','DEXTRA'=>'D-STAR/DExtra','DPLUS'=>'D-STAR/DPlus','XLX'=>'XLX Interlink','G3'=>'Icom G3','IMRS'=>'IMRS']; return $m[$k]??($k?:'Não identificado'); }
function flag_for_country_code(string $code): string {
    $code=strtoupper(trim($code));
    if(!preg_match('/^[A-Z]{2}$/',$code)) return '🌐';
    return html_entity_decode(
        '&#'.(127397+ord($code[0])).';&#'.(127397+ord($code[1])).';',
        ENT_NOQUOTES,
        'UTF-8'
    );
}
function country_from_xlxd_csv(string $call): ?array {
    static $prefixes=null;

    if($prefixes===null){
        $prefixes=[];
        $file=dirname(__DIR__,2).'/xlxd/pgs/country.csv';

        if(is_readable($file)){
            $handle=@fopen($file,'rb');

            if($handle){
                while(($row=fgets($handle,4096))!==false){
                    $tmp=explode(';',$row);
                    $name=trim((string)($tmp[0]??''));
                    $code=strtoupper(trim((string)($tmp[1]??'')));
                    $rawPrefixes=trim((string)($tmp[2]??''));

                    if(
                        $name===''
                        || !preg_match('/^[A-Z]{2}$/',$code)
                        || $rawPrefixes===''
                    ){
                        continue;
                    }

                    foreach(explode('-',$rawPrefixes) as $prefix){
                        $prefix=strtoupper(trim($prefix));
                        if($prefix!==''){
                            $prefixes[$prefix]=[
                                'code'=>$code,
                                'name'=>$name
                            ];
                        }
                    }
                }

                fclose($handle);
            }
        }
    }

    $c=norm_call($call);

    for($letters=min(4,strlen($c));$letters>=2;$letters--){
        $prefix=substr($c,0,$letters);

        if(isset($prefixes[$prefix])){
            $code=$prefixes[$prefix]['code'];

            return [
                'code'=>$code,
                'name'=>$prefixes[$prefix]['name'],
                'flag'=>flag_for_country_code($code)
            ];
        }
    }

    return null;
}
function country_for_call(string $call): array {
    $c=norm_call($call);
    $br=['PP','PQ','PR','PS','PT','PU','PV','PW','PX','PY','ZV','ZW','ZX','ZY','ZZ'];
    $p=substr($c,0,2);

    if(in_array($p,$br,true)) return ['code'=>'BR','name'=>'Brasil','flag'=>'🇧🇷'];
    if(str_starts_with($c,'K')||str_starts_with($c,'N')||str_starts_with($c,'W')||preg_match('/^A[A-L]/',$c)) return ['code'=>'US','name'=>'Estados Unidos','flag'=>'🇺🇸'];
    if(str_starts_with($c,'VE')||str_starts_with($c,'VA')) return ['code'=>'CA','name'=>'Canadá','flag'=>'🇨🇦'];
    if(str_starts_with($c,'LU')) return ['code'=>'AR','name'=>'Argentina','flag'=>'🇦🇷'];
    if(str_starts_with($c,'CX')) return ['code'=>'UY','name'=>'Uruguai','flag'=>'🇺🇾'];
    if(str_starts_with($c,'CE')) return ['code'=>'CL','name'=>'Chile','flag'=>'🇨🇱'];
    if(str_starts_with($c,'CT')) return ['code'=>'PT','name'=>'Portugal','flag'=>'🇵🇹'];
    if(str_starts_with($c,'EA')) return ['code'=>'ES','name'=>'Espanha','flag'=>'🇪🇸'];
    if(preg_match('/^(G|M|2E)/',$c)) return ['code'=>'GB','name'=>'Reino Unido','flag'=>'🇬🇧'];
    if(str_starts_with($c,'F')) return ['code'=>'FR','name'=>'França','flag'=>'🇫🇷'];
    if(str_starts_with($c,'DL')) return ['code'=>'DE','name'=>'Alemanha','flag'=>'🇩🇪'];
    if(str_starts_with($c,'I')) return ['code'=>'IT','name'=>'Itália','flag'=>'🇮🇹'];
    if(str_starts_with($c,'JA')) return ['code'=>'JP','name'=>'Japão','flag'=>'🇯🇵'];

    $fallback=country_from_xlxd_csv($c);
    if($fallback!==null) return $fallback;

    return ['code'=>'','name'=>'País não identificado','flag'=>'🌐'];
}
function user_lookup(string $call): array { static $db=null,$cache=[]; $call=norm_call($call); if(isset($cache[$call]))return $cache[$call]; $r=['name'=>'Não informado','location'=>'Não informada']; $p=cfg()['users_db']; if(class_exists('SQLite3')&&is_readable($p)){try{$db??=new SQLite3($p,SQLITE3_OPEN_READONLY);$s=$db->prepare('SELECT name, city_state FROM users WHERE callsign=:c LIMIT 1');$s->bindValue(':c',$call,SQLITE3_TEXT);$x=$s->execute();if($row=$x->fetchArray(SQLITE3_ASSOC)){$r['name']=trim((string)($row['name']??''))?:'Não informado';$r['location']=trim((string)($row['city_state']??''))?:'Não informada';}}catch(Throwable $e){}}return $cache[$call]=$r; }
function tail_file(string $p,int $bytes=4194304): string { if(!is_readable($p))return ''; $f=@fopen($p,'rb'); if(!$f)return ''; fseek($f,0,SEEK_END);$n=ftell($f);$s=max(0,$n-$bytes);fseek($f,$s);$d=stream_get_contents($f)?:'';fclose($f);if($s>0&&($q=strpos($d,"\n"))!==false)$d=substr($d,$q+1);return $d; }
function parse_any_time(string $line): int { if(preg_match('/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})([+\-]\d{4})?/',$line,$m)){ $t=strtotime($m[1].($m[2]??''));if($t!==false)return $t;} if(preg_match('/^(\d{1,2})\s+(\w+),\s+(\d{2}:\d{2}:\d{2})/',$line,$m)){ $d=DateTime::createFromFormat('j M Y H:i:s',$m[1].' '.$m[2].' '.date('Y').' '.$m[3]);if($d){$t=$d->getTimestamp();if($t>time()+86400){$d->modify('-1 year');$t=$d->getTimestamp();}return $t;}}return time(); }
function node_blocks(string $raw): array { preg_match_all('/<NODE>(.*?)<\/NODE>/si',$raw,$m); return $m[1]??[]; }
function tag_value(string $block,string $tag): string { return preg_match('/<'.preg_quote($tag,'/').'>\s*(.*?)\s*<\/'.preg_quote($tag,'/').'>/si',$block,$m)?html_entity_decode(trim(strip_tags($m[1])),ENT_QUOTES|ENT_XML1,'UTF-8'):''; }
function parse_xml_connections(): array { $p=cfg()['xml_path'];if(!is_readable($p))return []; $raw=@file_get_contents($p);if($raw===false)return []; $out=[];foreach(node_blocks($raw) as $b){$callRaw=tag_value($b,'Callsign');[$call,$suffix]=split_call_suffix($callRaw);if(!$call)continue;$protocol=protocol_label(tag_value($b,'Protocol'));$rawModule=trim(tag_value($b,'LinkedModule'));$module=$rawModule!==''?strtoupper(substr($rawModule,0,1)):'?';if($module==='?'&&$protocol==='DMR')$module='C';$ct=strtotime(tag_value($b,'ConnectTime'))?:0;$lt=strtotime(tag_value($b,'LastHeardTime'))?:0;$u=user_lookup($call);$country=country_for_call($call);$out[]=['callsign'=>$call,'suffix'=>$suffix,'name'=>$u['name'],'location'=>$u['location'],'country'=>$country,'module'=>$module,'protocol'=>$protocol,'connected_at'=>$ct,'last_activity'=>$lt,'qrz'=>qrz_url($call),'via'=>tag_value($b,'Via'),'peer'=>tag_value($b,'Peer'),'ip'=>tag_value($b,'IP')];}usort($out,fn($a,$b)=>$b['connected_at']<=>$a['connected_at']);return $out; }
function candidate_protocol(
    array $connections,
    string $call,
    string $suffix,
    string $module,
    array $recent,
    int $streamTime
): string {
    /*
     * V32.1
     *
     * Quando um indicativo possui conexões simultâneas DMR e
     * C4FM/YSF no módulo C, usa a conexão cuja última atividade
     * estiver mais próxima do início da transmissão.
     */

    $candidates = [];

    foreach ($connections as $connection) {
        if (($connection['callsign'] ?? '') !== $call) {
            continue;
        }

        if (($connection['module'] ?? '') !== $module) {
            continue;
        }

        $connectionSuffix = strtoupper(
            trim((string)($connection['suffix'] ?? ''))
        );

        if (
            $suffix !== ''
            && $connectionSuffix !== ''
            && $connectionSuffix !== $suffix
        ) {
            continue;
        }

        $protocol = trim(
            (string)($connection['protocol'] ?? '')
        );

        if (
            $protocol === ''
            || $protocol === 'Não identificado'
            || $protocol === 'C4FM ou DMR'
        ) {
            continue;
        }

        $lastActivity = (int)(
            $connection['last_activity'] ?? 0
        );

        $distance = $lastActivity > 0
            ? abs($streamTime - $lastActivity)
            : PHP_INT_MAX;

        $candidates[] = [
            'protocol' => $protocol,
            'distance' => $distance,
            'activity' => $lastActivity,
        ];
    }

    if ($candidates !== []) {
        usort(
            $candidates,
            static function (array $a, array $b): int {
                if ($a['distance'] === $b['distance']) {
                    return $b['activity'] <=> $a['activity'];
                }

                return $a['distance'] <=> $b['distance'];
            }
        );

        /*
         * Aceita diferença de até quinze minutos entre o horário
         * registrado no XML e a abertura do stream no log.
         */
        if ($candidates[0]['distance'] <= 900) {
            return $candidates[0]['protocol'];
        }

        $unique = [];

        foreach ($candidates as $candidate) {
            $unique[$candidate['protocol']] = true;
        }

        if (count($unique) === 1) {
            return array_key_first($unique);
        }
    }

    /*
     * Fallback para transmissões antigas ou quando o XML não
     * contém uma atividade suficientemente próxima.
     */
    foreach ([
        $call . '|' . $suffix . '|' . $module,
        $call . '||' . $module,
        $call . '|' . $suffix . '|*',
        $call . '||*',
    ] as $key) {
        if (!empty($recent[$key])) {
            return $recent[$key];
        }
    }

    if ($module === 'B') {
        return 'APRS / D-PRS';
    }

    if ($module === 'C') {
        return 'C4FM ou DMR';
    }

    if ($module === 'E') {
        return 'D-STAR Echo';
    }

    return 'Não identificado';
}

function mask_ip(string $ip): string {
    if(filter_var($ip,FILTER_VALIDATE_IP,FILTER_FLAG_IPV4)){
        $parts=explode('.',$ip); return $parts[0].'.'.$parts[1].'.x.x';
    }
    if(filter_var($ip,FILTER_VALIDATE_IP,FILTER_FLAG_IPV6)){
        $parts=explode(':',$ip); return implode(':',array_slice($parts,0,3)).':…';
    }
    return '';
}
function connection_origin_label(array $c): string {
    $via=trim((string)($c['via']??'')); $peer=trim((string)($c['peer']??''));
    if($via!=='' && $via!=='-') return $via;
    if($peer!=='' && $peer!=='-') return $peer;
    return trim((string)($c['callsign']??''));
}
function match_tx_connection(array $connections,string $call,string $suffix,string $module,string $protocol,int $ts): array {
    $best=null; $bestScore=-999999; $exact=false;
    foreach($connections as $c){
        $score=0;
        if(($c['module']??'?')===$module) $score+=80; else $score-=80;
        if(($c['callsign']??'')===$call){$score+=100;$exact=true;}
        if($suffix!=='' && ($c['suffix']??'')===$suffix) $score+=25;
        if($protocol!=='' && $protocol!=='Não identificado' && ($c['protocol']??'')===$protocol) $score+=40;
        $age=abs($ts-(int)($c['last_activity']??0));
        if($age<=5)$score+=35; elseif($age<=30)$score+=20; elseif($age<=120)$score+=8; else $score-=min(40,(int)floor($age/300));
        if($score>$bestScore){$bestScore=$score;$best=$c;}
    }
    if(!$best || $bestScore<20) return ['gateway'=>'Não identificado','via'=>'','peer'=>'','endpoint_ip'=>'','origin_match'=>'indisponível'];
    return [
      'gateway'=>connection_origin_label($best)?:'Não identificado',
      'via'=>(string)($best['via']??''),
      'peer'=>(string)($best['peer']??''),
      'endpoint_ip'=>mask_ip((string)($best['ip']??'')),
      'origin_match'=>$exact?'exata':'estimada'
    ];
}


/*
 * XLX026 — operador real de uma transmissão D-STAR.
 *
 * Log:
 *   client = gateway/nó
 *
 * XML:
 *   STATION  = operador
 *   Via node = gateway/nó
 */
function xlxmodern_dstar_station_index(): array {
    $path=cfg()['xml_path'];

    if(!is_readable($path)) return [];

    $raw=@file_get_contents($path);

    if($raw===false || $raw==='') return [];

    preg_match_all(
        '/<STATION>(.*?)<\/STATION>/si',
        $raw,
        $matches
    );

    $out=[];

    foreach($matches[1]??[] as $block){
        $stationRaw=trim(tag_value($block,'Callsign'));
        $viaRaw=trim(tag_value($block,'Via node'));
        $moduleRaw=trim(tag_value($block,'On module'));
        $heardRaw=trim(tag_value($block,'LastHeardTime'));

        if(
            $stationRaw===''
            || $viaRaw===''
            || $moduleRaw===''
            || $heardRaw===''
        ){
            continue;
        }

        $stationParts=preg_split(
            '/\s*\/\s*/',
            $stationRaw,
            2
        ) ?: [];

        $stationCall=norm_call(
            (string)($stationParts[0]??'')
        );

        [$gatewayCall,$gatewaySuffix]=split_call_suffix(
            $viaRaw
        );

        $module=strtoupper(
            substr($moduleRaw,0,1)
        );

        $heard=strtotime($heardRaw);

        if(
            $heard===false
            && preg_match(
                '/^[A-Za-z]+\s+(.+)$/',
                $heardRaw,
                $tm
            )
        ){
            $heard=strtotime($tm[1]);
        }

        if(
            $stationCall===''
            || $gatewayCall===''
            || $module===''
            || $heard===false
        ){
            continue;
        }

        $key=$gatewayCall.'|'.$module;

        $out[$key][]=[
            'callsign'=>$stationCall,
            'gateway'=>$gatewayCall,
            'gateway_suffix'=>strtoupper(
                trim($gatewaySuffix)
            ),
            'module'=>$module,
            'heard_at'=>(int)$heard
        ];
    }

    return $out;
}

function xlxmodern_find_dstar_station(
    array $index,
    string $gateway,
    string $gatewaySuffix,
    string $module,
    int $startedAt,
    int $endedAt
): ?array {
    $gateway=norm_call($gateway);
    $gatewaySuffix=strtoupper(trim($gatewaySuffix));
    $module=strtoupper(trim($module));

    if(
        $gateway===''
        || $module===''
        || $startedAt<=0
    ){
        return null;
    }

    $items=$index[$gateway.'|'.$module]??[];

    if($items===[]) return null;

    $best=null;
    $bestScore=PHP_INT_MAX;

    foreach($items as $station){
        $xmlSuffix=strtoupper(
            trim((string)(
                $station['gateway_suffix']??''
            ))
        );

        /*
         * O sufixo pertence ao gateway remoto e pode representar o
         * módulo dele, não o módulo local do XLX. Uma divergência não
         * pode descartar o operador; ela só serve de desempate.
         */
        $suffixPenalty=(
            $gatewaySuffix!==''
            && $xmlSuffix!==''
            && $gatewaySuffix!==$xmlSuffix
        ) ? 5 : 0;

        $heard=(int)($station['heard_at']??0);

        if($heard<=0) continue;

        if($heard<$startedAt){
            $outside=$startedAt-$heard;
        }elseif($heard>$endedAt){
            $outside=$heard-$endedAt;
        }else{
            $outside=0;
        }

        /*
         * Margem para diferença entre LastHeardTime do XML
         * e Opening/Closing stream do log.
         */
        if($outside>30) continue;

        $score=
            ($outside*100000)
            +abs($heard-$endedAt)
            +$suffixPenalty;

        if($score<$bestScore){
            $bestScore=$score;
            $best=$station;
        }
    }

    return $best;
}


/*
 * XLXMODERN_STATION_STREAM_IDENTITY_V1
 *
 * Para protocolos que não são D-STAR:
 * só aceita STATION cuja atividade corresponda
 * praticamente ao mesmo instante do Opening stream.
 *
 * Isso evita atribuir o operador errado quando
 * várias pessoas usam o mesmo gateway/repetidora.
 */
function xlxmodern_find_stream_station(
    array $index,
    string $gateway,
    string $gatewaySuffix,
    string $module,
    int $startedAt
): ?array {
    $gateway=norm_call($gateway);
    $gatewaySuffix=strtoupper(trim($gatewaySuffix));
    $module=strtoupper(trim($module));

    if(
        $gateway===''
        || $module===''
        || $startedAt<=0
    ){
        return null;
    }

    $items=$index[$gateway.'|'.$module]??[];

    if($items===[]) return null;

    $best=null;
    $bestDistance=PHP_INT_MAX;
    $ambiguous=false;

    foreach($items as $station){
        $xmlSuffix=strtoupper(
            trim(
                (string)(
                    $station['gateway_suffix']??''
                )
            )
        );

        if(
            $gatewaySuffix!==''
            && $xmlSuffix!==''
            && $gatewaySuffix!==$xmlSuffix
        ){
            continue;
        }

        $heard=(int)($station['heard_at']??0);

        if($heard<=0) continue;

        /*
         * Nos dados reais do XLX026:
         * LastHeardTime coincide com Opening stream.
         *
         * Permitimos somente 2 segundos de diferença.
         */
        $distance=abs($heard-$startedAt);

        if($distance>2) continue;

        if($distance<$bestDistance){
            $best=$station;
            $bestDistance=$distance;
            $ambiguous=false;
            continue;
        }

        if(
            $distance===$bestDistance
            && $best!==null
            && norm_call(
                (string)($best['callsign']??'')
            )!==norm_call(
                (string)($station['callsign']??'')
            )
        ){
            $ambiguous=true;
        }
    }

    if($ambiguous) return null;

    return $best;
}

function xlxmodern_apply_stream_station(
    array $tx,
    array $station
): array {
    $networkCall=norm_call(
        (string)($tx['callsign']??'')
    );

    $networkSuffix=strtoupper(
        trim((string)($tx['suffix']??''))
    );

    $tx=xlxmodern_apply_dstar_station(
        $tx,
        $station
    );

    if($networkCall!==''){
        $tx['network_callsign']=$networkCall;
    }

    if($networkSuffix!==''){
        $tx['network_suffix']=$networkSuffix;
    }

    $gatewaySuffix=strtoupper(
        trim(
            (string)(
                $station['gateway_suffix']??''
            )
        )
    );

    if($gatewaySuffix!==''){
        $tx['gateway_suffix']=$gatewaySuffix;
    }

    $tx['identity_source']='xlxd-station-stream';

    return $tx;
}

function xlxmodern_apply_dstar_station(
    array $tx,
    array $station
): array {
    $call=norm_call(
        (string)($station['callsign']??'')
    );

    if($call==='') return $tx;

    $user=user_lookup($call);

    $tx['callsign']=$call;
    $tx['suffix']='';
    $tx['operator_callsign']=$call;
    $tx['operator_identity']='station';
    $tx['name']=$user['name'];
    $tx['location']=$user['location'];
    $tx['country']=country_for_call($call);
    $tx['qrz']=qrz_url($call);

    $gateway=norm_call(
        (string)($station['gateway']??'')
    );

    if($gateway!==''){
        $tx['gateway']=$gateway;
    }

    return $tx;
}


function history_log_lines(string $currentLog,int $bytes=4194304): array {
    $sources=[];
    $rotated=$currentLog.'.1.gz';

    if(is_readable($rotated)) $sources[]=['path'=>$rotated,'gzip'=>true];
    if(is_readable($currentLog)) $sources[]=['path'=>$currentLog,'gzip'=>false];

    /*
     * XLXMODERN_HISTORY_SORT_ONCE_V1
     *
     * Antes, parse_any_time() era executado repetidamente
     * dentro do comparador do usort().
     *
     * Agora cada linha tem seu timestamp calculado uma única
     * vez. A ordenação compara somente inteiros.
     */
    $rows=[];
    $seen=[];
    $sequence=0;

    foreach($sources as $source){
        $raw='';

        if($source['gzip']){
            $handle=@gzopen($source['path'],'rb');

            if($handle){
                while(!gzeof($handle)){
                    $chunk=gzread($handle,65536);

                    if($chunk===false) break;

                    $raw.=$chunk;

                    if(strlen($raw)>$bytes){
                        $raw=substr($raw,-$bytes);
                    }
                }

                gzclose($handle);
            }
        }else{
            $raw=tail_file($source['path'],$bytes);
        }

        foreach(preg_split('/\R/',$raw)?:[] as $line){
            if($line==='') continue;

            /*
             * XLXMODERN_HISTORY_RELEVANT_FILTER_V1
             *
             * active_and_history() somente interpreta estas
             * tres classes de evento. Linhas restantes nao
             * precisam de SHA1, parse de horario ou ordenacao.
             */
            if(
                stripos($line,'New client')===false
                && stripos(
                    $line,
                    'Opening stream on module'
                )===false
                && stripos(
                    $line,
                    'Closing stream of module'
                )===false
            ){
                continue;
            }


            $hash=sha1($line);

            if(isset($seen[$hash])) continue;

            $seen[$hash]=true;

            $rows[]=[
                'time'=>parse_any_time($line),
                'sequence'=>$sequence++,
                'line'=>$line
            ];
        }
    }

    /*
     * PHP 8 usa ordenação estável. sequence preserva
     * explicitamente a ordem original quando dois registros
     * possuem exatamente o mesmo timestamp.
     */
    usort(
        $rows,
        static function(array $a,array $b): int {
            $cmp=$a['time']<=>$b['time'];

            if($cmp!==0){
                return $cmp;
            }

            return $a['sequence']<=>$b['sequence'];
        }
    );

    $lines=[];

    foreach($rows as $row){
        $lines[]=$row['line'];
    }

    return $lines;
}

function active_and_history(array $connections, ?int $historyLimit = null, ?int $historySince = null): array {
    $lines=history_log_lines(cfg()['log_path']);
    $dstarStations=xlxmodern_dstar_station_index();
    $active=[];
    $history=[];
    $recent=[];

    foreach($lines as $line){
        $ts=parse_any_time($line);

        if(preg_match('/New client\s+([A-Z0-9]+)(?:\s+([A-Z0-9]+))?.*?protocol\s+([A-Za-z0-9+_-]+)(?:.*?module\s+([A-Z]))?/i',$line,$m)){
            $call=norm_call($m[1]);
            $s=strtoupper(trim($m[2]??''));
            $mod=strtoupper(trim($m[4]??'?'));
            $lab=protocol_label($m[3]);
            if(($mod===''||$mod==='?')&&$lab==='DMR') $mod='C';
            $recent[$call.'|'.$s.'|'.$mod]=$lab;
            $recent[$call.'||'.$mod]=$lab;
            $recent[$call.'|'.$s.'|*']=$lab;
            $recent[$call.'||*']=$lab;
        }

        /* XLXMODERN_LOG260_COMPAT_V2: parser compatível XLXD 2.5/2.6 */
        if(preg_match('/Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9\/\-]+)(?:\s+((?!(?:on|via)\b)[A-Z0-9]+))?(?:\s*\/\s*[A-Z0-9+_-]+)?(?:\s+(?:on|via)\s+[A-Z0-9\/\-]+(?:\s+[A-Z0-9]+)?)?\s+with sid\s+(\d+)/i',$line,$m)){
            $mod=strtoupper($m[1]);
            $call=norm_call($m[2]);
            $s=strtoupper(trim($m[3]??''));
            $sid=(int)$m[4];
            $u=user_lookup($call);
            $protocol=candidate_protocol($connections,$call,$s,$mod,$recent,$ts);
            $origin=match_tx_connection($connections,$call,$s,$mod,$protocol,$ts);
            $active[$mod]=array_merge([
                'key'=>$mod.':'.$sid,
                'module'=>$mod,
                'stream_id'=>$sid,
                'callsign'=>$call,
                'suffix'=>$s,
                'name'=>$u['name'],
                'location'=>$u['location'],
                'country'=>country_for_call($call),
                'protocol'=>$protocol,
                'started_at'=>$ts,
                'qrz'=>qrz_url($call),
                'state'=>'transmitting'
            ],$origin);

            /*
             * Em D-STAR o "client" do log pode ser a repetidora. Só
             * apresentamos um operador quando o XML STATION o confirma.
             */
            if(strpos($protocol,'D-STAR/')===0){
                $active[$mod]['operator_callsign']='';
                $active[$mod]['operator_identity']='unresolved';
            }
        }

        if(preg_match('/Closing stream of module\s+([A-Z])/i',$line,$m)){
            $mod=strtoupper($m[1]);
            if(isset($active[$mod])){
                $tx=$active[$mod];
                $tx['ended_at']=$ts;
                $tx['duration']=max(0,$ts-$tx['started_at']);
                $tx['state']='ended';

                if(
                    strpos(
                        (string)($tx['protocol']??''),
                        'D-STAR/'
                    )===0
                ){
                    /*
                     * D-STAR preservado exatamente como já estava.
                     */
                    $station=xlxmodern_find_dstar_station(
                        $dstarStations,
                        (string)($tx['callsign']??''),
                        (string)($tx['suffix']??''),
                        (string)($tx['module']??''),
                        (int)($tx['started_at']??0),
                        $ts
                    );

                    if($station!==null){
                        $tx=xlxmodern_apply_dstar_station(
                            $tx,
                            $station
                        );
                    }
                }else{
                    /*
                     * XLXMODERN_STATION_STREAM_HISTORY_V1
                     * C4FM/YSF, DMR e outros:
                     * casamento estrito pelo início do stream.
                     */
                    $station=xlxmodern_find_stream_station(
                        $dstarStations,
                        (string)($tx['callsign']??''),
                        (string)($tx['suffix']??''),
                        (string)($tx['module']??''),
                        (int)($tx['started_at']??0)
                    );

                    if($station!==null){
                        $tx=xlxmodern_apply_stream_station(
                            $tx,
                            $station
                        );
                    }
                }

                $history[]=$tx;
                unset($active[$mod]);
            }
        }
    }

    foreach($active as $m=>$tx){
        if(time()-$tx['started_at']>600){
            unset($active[$m]);
            continue;
        }

        if(
            strpos(
                (string)($tx['protocol']??''),
                'D-STAR/'
            )===0
        ){
            /*
             * D-STAR preservado exatamente como já estava.
             */
            $station=xlxmodern_find_dstar_station(
                $dstarStations,
                (string)($tx['callsign']??''),
                (string)($tx['suffix']??''),
                (string)($tx['module']??''),
                (int)($tx['started_at']??0),
                time()
            );

            if($station!==null){
                $active[$m]=xlxmodern_apply_dstar_station(
                    $tx,
                    $station
                );
            }
        }else{
            /*
             * XLXMODERN_STATION_STREAM_ACTIVE_V1
             */
            $station=xlxmodern_find_stream_station(
                $dstarStations,
                (string)($tx['callsign']??''),
                (string)($tx['suffix']??''),
                (string)($tx['module']??''),
                (int)($tx['started_at']??0)
            );

            if($station!==null){
                $active[$m]=xlxmodern_apply_stream_station(
                    $tx,
                    $station
                );
            }
        }
    }

    $unique=[];
    foreach($history as $tx){
        $key=implode('|',[
            (string)($tx['module']??''),
            (string)($tx['stream_id']??''),
            (string)($tx['callsign']??''),
            (string)($tx['started_at']??''),
            (string)($tx['ended_at']??'')
        ]);
        $unique[$key]=$tx;
    }

    $history=array_values($unique);
    usort($history,fn($a,$b)=>$b['started_at']<=>$a['started_at']);

    if ($historySince !== null) {
        $history = array_values(
            array_filter(
                $history,
                static fn(array $tx): bool =>
                    (int)($tx['started_at'] ?? 0) >= $historySince
            )
        );
    }

    $limit = $historyLimit ?? (int)cfg()['history_limit'];
    $limit = max(1, min(5000, $limit));

    return [
        'active'=>$active,
        'history'=>array_slice($history,0,$limit)
    ];
}
function online_index(array $connections): array { $idx=[]; foreach($connections as $c){ $idx[$c['callsign']] = true; } return $idx; }
function detect_callinghome_url(): string {
    return 'http://xlxapi.rlx.lu/api.php';
}
function parse_reflectors_payload(string $raw): array {
    $items=[];
    preg_match_all('/<reflector>(.*?)<\/reflector>/si',$raw,$m);

    foreach($m[1]??[] as $block){
        $pick=static function(string $tag) use($block): string {
            return preg_match('/<'.preg_quote($tag,'/').'>(.*?)<\/'.preg_quote($tag,'/').'>/si',$block,$x)
                ? trim(strip_tags(html_entity_decode($x[1],ENT_QUOTES|ENT_XML1,'UTF-8')))
                : '';
        };

        $last=(int)$pick('lastcontact');
        $items[]=[
            'name'=>$pick('name'),
            'country'=>$pick('country'),
            'status'=>$last<(time()-1800)?'Offline':'Online',
            'comment'=>$pick('comment'),
            'dashboardurl'=>$pick('dashboardurl')
        ];
    }

    return $items;
}

function read_reflectors_cache(string $cacheFile,int $maxAge): array {
    if(!is_readable($cacheFile)) return [];
    $mtime=@filemtime($cacheFile);
    if($mtime===false || (time()-$mtime)>$maxAge) return [];

    $raw=@file_get_contents($cacheFile);
    if($raw===false || $raw==='') return [];

    $items=json_decode($raw,true);
    return is_array($items)?$items:[];
}

function write_reflectors_cache(string $cacheFile,array $items): void {
    $json=json_encode($items,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
    if($json===false) return;

    $temp=$cacheFile.'.'.getmypid().'.tmp';
    if(@file_put_contents($temp,$json,LOCK_EX)===false) return;

    @chmod($temp,0640);
    if(!@rename($temp,$cacheFile)) @unlink($temp);
}

function fetch_reflectors(): array {
    $cacheFile=sys_get_temp_dir().'/xlxmodern_reflectors_cache_v1.json';
    $lockFile=sys_get_temp_dir().'/xlxmodern_reflectors_cache_v1.lock';
    $cacheTtl=60;

    $cached=read_reflectors_cache($cacheFile,$cacheTtl);
    if($cached!==[]) return $cached;

    $lock=@fopen($lockFile,'c');
    if($lock && @flock($lock,LOCK_EX)){
        $cached=read_reflectors_cache($cacheFile,$cacheTtl);
        if($cached!==[]){
            @flock($lock,LOCK_UN);
            @fclose($lock);
            return $cached;
        }

        $base=detect_callinghome_url();
        $url=rtrim($base,'?&').(str_contains($base,'?')?'&':'?').'do=GetReflectorList';
        $ctx=stream_context_create([
            'http'=>[
                'timeout'=>8,
                'user_agent'=>'XLX-Modern-Painel/6.1',
                'ignore_errors'=>true
            ],
            'ssl'=>[
                'verify_peer'=>true,
                'verify_peer_name'=>true
            ]
        ]);

        $raw=@file_get_contents($url,false,$ctx);
        $items=($raw!==false && trim($raw)!=='')
            ? parse_reflectors_payload($raw)
            : [];

        if($items!==[]) write_reflectors_cache($cacheFile,$items);

        @flock($lock,LOCK_UN);
        @fclose($lock);

        if($items!==[]) return $items;
    }elseif($lock){
        @fclose($lock);
    }

    $staleRaw=@file_get_contents($cacheFile);
    if($staleRaw!==false && $staleRaw!==''){
        $stale=json_decode($staleRaw,true);
        if(is_array($stale)) return $stale;
    }

    return [];
}
