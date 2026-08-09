<?php
declare(strict_types=1);

/*
 * Extensões isoladas das páginas autorizadas do XLX Modern.
 * Depende de common.php já carregado pelo chamador.
 */

function flag_for_country_code_sync(string $code): string {
    $code=strtoupper(trim($code));
    if(!preg_match('/^[A-Z]{2}$/',$code)) return '🌐';
    return html_entity_decode(
        '&#'.(127397+ord($code[0])).';&#'.(127397+ord($code[1])).';',
        ENT_NOQUOTES,
        'UTF-8'
    );
}

function country_from_xlxd_csv_sync(string $call): ?array {
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
                'flag'=>flag_for_country_code_sync($code)
            ];
        }
    }

    return null;
}

function country_for_call_sync(string $call): array {
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

    $fallback=country_from_xlxd_csv_sync($c);
    if($fallback!==null) return $fallback;

    return ['code'=>'','name'=>'País não identificado','flag'=>'🌐'];
}

function parse_xml_connections_sync(): array { $p=cfg()['xml_path'];if(!is_readable($p))return []; $raw=@file_get_contents($p);if($raw===false)return []; $out=[];foreach(node_blocks($raw) as $b){$callRaw=tag_value($b,'Callsign');[$call,$suffix]=split_call_suffix($callRaw);if(!$call)continue;$protocol=protocol_label(tag_value($b,'Protocol'));$rawModule=trim(tag_value($b,'LinkedModule'));$module=$rawModule!==''?strtoupper(substr($rawModule,0,1)):'?';if($module==='?'&&$protocol==='DMR')$module='C';$ct=strtotime(tag_value($b,'ConnectTime'))?:0;$lt=strtotime(tag_value($b,'LastHeardTime'))?:0;$u=user_lookup($call);$country=country_for_call_sync($call);$out[]=['callsign'=>$call,'suffix'=>$suffix,'name'=>$u['name'],'location'=>$u['location'],'country'=>$country,'module'=>$module,'protocol'=>$protocol,'connected_at'=>$ct,'last_activity'=>$lt,'qrz'=>qrz_url($call),'via'=>tag_value($b,'Via'),'peer'=>tag_value($b,'Peer'),'ip'=>tag_value($b,'IP')];}usort($out,fn($a,$b)=>$b['connected_at']<=>$a['connected_at']);return $out; }

function xlx_dstar_station_index_sync(): array {
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

function xlx_find_dstar_station_sync(
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

        if(
            $gatewaySuffix!==''
            && $xmlSuffix!==''
            && $gatewaySuffix!==$xmlSuffix
        ){
            continue;
        }

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
            +abs($heard-$endedAt);

        if($score<$bestScore){
            $bestScore=$score;
            $best=$station;
        }
    }

    return $best;
}

function xlx_apply_dstar_station_sync(
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
    $tx['name']=$user['name'];
    $tx['location']=$user['location'];
    $tx['country']=country_for_call_sync($call);
    $tx['qrz']=qrz_url($call);

    $gateway=norm_call(
        (string)($station['gateway']??'')
    );

    if($gateway!==''){
        $tx['gateway']=$gateway;
    }

    return $tx;
}

function active_and_history_sync(array $connections, ?int $historyLimit = null, ?int $historySince = null): array {
    $lines=history_log_lines(cfg()['log_path']);
    $dstarStations=xlx_dstar_station_index_sync();
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

        if(preg_match('/Opening stream on module\s+([A-Z])\s+for client\s+([A-Z0-9]+)\s*([A-Z0-9]+)?\s+with sid\s+(\d+)/i',$line,$m)){
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
                'country'=>country_for_call_sync($call),
                'protocol'=>$protocol,
                'started_at'=>$ts,
                'qrz'=>qrz_url($call),
                'state'=>'transmitting'
            ],$origin);
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
                    $station=xlx_find_dstar_station_sync(
                        $dstarStations,
                        (string)($tx['callsign']??''),
                        (string)($tx['suffix']??''),
                        (string)($tx['module']??''),
                        (int)($tx['started_at']??0),
                        $ts
                    );

                    if($station!==null){
                        $tx=xlx_apply_dstar_station_sync(
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
            $station=xlx_find_dstar_station_sync(
                $dstarStations,
                (string)($tx['callsign']??''),
                (string)($tx['suffix']??''),
                (string)($tx['module']??''),
                (int)($tx['started_at']??0),
                time()
            );

            if($station!==null){
                $active[$m]=xlx_apply_dstar_station_sync(
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
