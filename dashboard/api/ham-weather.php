<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store');

const CACHE_DIR = '/var/cache/xlx-ham-weather';
const WEATHER_TTL = 600;
const SPACE_TTL = 300;
const MAX_BODY = 1048576;
const KP_MAX_AGE = 28800;       // 8 h: produto Kp tem cadencia de 3 h
const SFI_MAX_AGE = 129600;     // 36 h: fluxo F10.7 e tipicamente diario

function out(array $data, int $status = 200): never {
    http_response_code($status);
    $data['served_at'] = time();
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function finiteFloat(mixed $v): ?float {
    if (!is_numeric($v)) return null;
    $f=(float)$v;
    return is_finite($f)?$f:null;
}
function cleanText(mixed $v, int $max=100): string {
    $s=trim((string)$v);
    $s=preg_replace('/[^\pL\pN .,_\-\/]/u','',$s)??'';
    return mb_substr($s,0,$max,'UTF-8');
}
function cleanHeader(string $name, int $max=100): string {
    return cleanText($_SERVER[$name]??'', $max);
}
function allowedHost(string $url): bool {
    $p=parse_url($url);
    if (!is_array($p)||($p['scheme']??'')!=='https') return false;
    return in_array(strtolower((string)($p['host']??'')), [
        'api.open-meteo.com',
        'services.swpc.noaa.gov',
        'ipwho.is'
    ], true);
}
function httpJson(string $url): ?array {
    if (!allowedHost($url)) return null;
    $body='';
    $ch=curl_init($url);
    if ($ch===false) return null;
    curl_setopt_array($ch,[
        CURLOPT_RETURNTRANSFER=>false,
        CURLOPT_FOLLOWLOCATION=>false,
        CURLOPT_CONNECTTIMEOUT=>5,
        CURLOPT_TIMEOUT=>12,
        CURLOPT_SSL_VERIFYPEER=>true,
        CURLOPT_SSL_VERIFYHOST=>2,
        CURLOPT_USERAGENT=>'XLX-Modern-HamWeather/3',
        CURLOPT_HTTPHEADER=>['Accept: application/json'],
        CURLOPT_WRITEFUNCTION=>static function($ch,string $chunk) use (&$body): int {
            if (strlen($body)+strlen($chunk)>MAX_BODY) return 0;
            $body.=$chunk;
            return strlen($chunk);
        }
    ]);
    if (defined('CURLOPT_PROTOCOLS')&&defined('CURLPROTO_HTTPS')) {
        curl_setopt($ch,CURLOPT_PROTOCOLS,CURLPROTO_HTTPS);
    }
    $ok=curl_exec($ch);
    $status=(int)curl_getinfo($ch,CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    if ($ok===false||$status<200||$status>=300||$body==='') return null;
    $j=json_decode($body,true);
    return is_array($j)?$j:null;
}
function cacheRead(string $file,int $ttl): ?array {
    if (!is_file($file)||time()-(int)filemtime($file)>=$ttl) return null;
    $j=json_decode((string)@file_get_contents($file),true);
    return is_array($j)?$j:null;
}
function cacheWrite(string $file,array $data): void {
    $tmp=$file.'.tmp.'.getmypid();
    $j=json_encode($data,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
    if (is_string($j)&&@file_put_contents($tmp,$j,LOCK_EX)!==false){
        @chmod($tmp,0640);
        @rename($tmp,$file);
    } else {
        @unlink($tmp);
    }
}
function validPublicIp(mixed $candidate): ?string {
    $ip=trim((string)$candidate);
    if ($ip==='') return null;
    $flags=FILTER_FLAG_NO_PRIV_RANGE|FILTER_FLAG_NO_RES_RANGE;
    return filter_var($ip,FILTER_VALIDATE_IP,$flags)!==false?$ip:null;
}
function publicVisitorIp(): array {
    // Se veio realmente pela Cloudflare, CF-Connecting-IP e a fonte canonica.
    $cf=validPublicIp($_SERVER['HTTP_CF_CONNECTING_IP']??'');
    if ($cf!==null) return ['ip'=>$cf,'source'=>'cf_connecting_ip'];

    // Se existe CF-Ray mas o CF-Connecting-IP foi removido, nao usamos REMOTE_ADDR:
    // nesse caso REMOTE_ADDR tende a ser um edge Cloudflare e nao o visitante.
    if (trim((string)($_SERVER['HTTP_CF_RAY']??''))!=='') {
        return ['ip'=>null,'source'=>'cloudflare_without_visitor_ip'];
    }

    // Acesso direto ao Apache (DNS sem proxy): REMOTE_ADDR e o visitante.
    $remote=validPublicIp($_SERVER['REMOTE_ADDR']??'');
    if ($remote!==null) return ['ip'=>$remote,'source'=>'remote_addr'];

    return ['ip'=>null,'source'=>'unavailable'];
}
function dashboardLocale(): string {
    $configFile = dirname(__DIR__) . '/config/site.php';
    if (!is_file($configFile)) {
        return 'en';
    }
    $site = require $configFile;
    $configured = strtolower(str_replace('_', '-', (string)($site['locale']['default'] ?? 'en')));
    return match ($configured) {
        'pt', 'pt-br' => 'pt-BR',
        'en' => 'en',
        'es' => 'es',
        'fr' => 'fr',
        'de' => 'de',
        'it' => 'it',
        default => 'en',
    };
}
function ipFallback(): ?array {
    $v=publicVisitorIp();
    if (!is_string($v['ip']??null)) return null;
    $url='https://ipwho.is/'.rawurlencode($v['ip']).'?fields=success,country,country_code,region,region_code,city,latitude,longitude&lang='.rawurlencode(dashboardLocale());
    $g=httpJson($url);
    if (!is_array($g)||($g['success']??false)!==true) return null;
    $lat=finiteFloat($g['latitude']??null);
    $lon=finiteFloat($g['longitude']??null);
    if ($lat===null||$lon===null||$lat < -90||$lat > 90||$lon < -180||$lon > 180) return null;
    return [
        'lat'=>$lat,'lon'=>$lon,
        'city'=>cleanText($g['city']??''),
        'region'=>cleanText($g['region_code']??($g['region']??''),30),
        'country'=>cleanText($g['country_code']??($g['country']??''),20),
        'source'=>'ip_fallback',
        'ip_source'=>$v['source']
    ];
}
function location(): array {
    // 1) Coordenadas precisas opcionais do navegador.
    $lat=finiteFloat($_GET['lat']??null);
    $lon=finiteFloat($_GET['lon']??null);
    if ($lat!==null&&$lon!==null&&$lat>=-90&&$lat<=90&&$lon>=-180&&$lon<=180) {
        return [
            'ok'=>true,'lat'=>round($lat,4),'lon'=>round($lon,4),
            'cache_lat'=>round($lat,1),'cache_lon'=>round($lon,1),
            'city'=>'','region'=>'','country'=>'',
            'source'=>'browser','ip_source'=>null
        ];
    }

    // 2) Coordenadas de geolocalizacao da Cloudflare, quando Managed Transform estiver ativo.
    $lat=finiteFloat($_SERVER['HTTP_CF_IPLATITUDE']??null);
    $lon=finiteFloat($_SERVER['HTTP_CF_IPLONGITUDE']??null);
    if ($lat!==null&&$lon!==null&&$lat>=-90&&$lat<=90&&$lon>=-180&&$lon<=180) {
        return [
            'ok'=>true,'lat'=>round($lat,4),'lon'=>round($lon,4),
            'cache_lat'=>round($lat,1),'cache_lon'=>round($lon,1),
            'city'=>cleanHeader('HTTP_CF_IPCITY'),
            'region'=>cleanHeader('HTTP_CF_REGION',30),
            'country'=>cleanHeader('HTTP_CF_IPCOUNTRY',8),
            'source'=>'cloudflare_ip','ip_source'=>'cloudflare_headers'
        ];
    }

    // 3) Fallback por IP real: CF-Connecting-IP ou REMOTE_ADDR quando o site esta direto.
    $g=ipFallback();
    if ($g!==null) {
        return [
            'ok'=>true,'lat'=>round($g['lat'],4),'lon'=>round($g['lon'],4),
            'cache_lat'=>round($g['lat'],1),'cache_lon'=>round($g['lon'],1),
            'city'=>$g['city'],'region'=>$g['region'],'country'=>$g['country'],
            'source'=>'ip_fallback','ip_source'=>$g['ip_source']
        ];
    }
    return ['ok'=>false,'needs_location'=>true,'ip_source'=>(publicVisitorIp()['source']??'unavailable')];
}
function weather(array $loc): ?array {
    $key=str_replace(['-','.'],['m','_'],(string)$loc['cache_lat']).'_'.str_replace(['-','.'],['m','_'],(string)$loc['cache_lon']);
    $file=CACHE_DIR.'/weather_'.$key.'.json';
    $cached=cacheRead($file,WEATHER_TTL);
    if($cached!==null) return $cached;

    $params=http_build_query([
        'latitude'=>$loc['lat'],
        'longitude'=>$loc['lon'],
        'current'=>'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,cloud_cover,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m',
        'hourly'=>'temperature_2m,relative_humidity_2m,dew_point_2m,surface_pressure,wind_speed_10m,wind_direction_10m,precipitation_probability,visibility',
        'daily'=>'sunrise,sunset,uv_index_max,precipitation_probability_max',
        'timezone'=>'auto',
        'forecast_days'=>2,
        'wind_speed_unit'=>'kmh'
    ]);
    $data=httpJson('https://api.open-meteo.com/v1/forecast?'.$params);
    if($data===null||!isset($data['current'])) return $cached;

    $c=$data['current'];
    $h=is_array($data['hourly']??null)?$data['hourly']:[];
    $d=is_array($data['daily']??null)?$data['daily']:[];
    $idx=0;
    if(isset($h['time'])&&is_array($h['time'])){
        $now=strtotime((string)($c['time']??''))?:time();
        $best=PHP_INT_MAX;
        foreach($h['time'] as $i=>$t){
            $delta=abs((strtotime((string)$t)?:0)-$now);
            if($delta<$best){$best=$delta;$idx=(int)$i;}
        }
    }
    $hv=static fn(string $n)=>$h[$n][$idx]??null;
    $temp=finiteFloat($c['temperature_2m']??null);
    $dew=finiteFloat($hv('dew_point_2m'));
    $rh=finiteFloat($c['relative_humidity_2m']??null);
    $pressure=finiteFloat($c['surface_pressure']??null);
    $wind=finiteFloat($c['wind_speed_10m']??null);
    $gust=finiteFloat($c['wind_gusts_10m']??null);
    $prec=finiteFloat($c['precipitation']??null);

    $score=0;
    if($temp!==null&&$dew!==null){
        $spread=$temp-$dew;
        if($spread<=2.5)$score+=2;
        elseif($spread<=5)$score+=1;
    }
    if($rh!==null&&$rh>=85)$score+=2;
    elseif($rh!==null&&$rh>=70)$score+=1;
    if($pressure!==null&&$pressure>=1018)$score+=2;
    elseif($pressure!==null&&$pressure>=1012)$score+=1;
    if($wind!==null&&$wind<=10)$score+=1;
    if($gust!==null&&$gust>=35)$score-=1;
    if($prec!==null&&$prec>0.5)$score-=2;
    $tropo=$score>=5?['level'=>'elevado','score'=>$score]:($score>=3?['level'=>'moderado','score'=>$score]:['level'=>'baixo','score'=>$score]);

    $res=[
        'updated_at'=>$c['time']??null,
        'timezone'=>$data['timezone']??null,
        'temperature'=>$temp,
        'apparent_temperature'=>finiteFloat($c['apparent_temperature']??null),
        'humidity'=>$rh,
        'dew_point'=>$dew,
        'pressure'=>$pressure,
        'wind_speed'=>$wind,
        'wind_direction'=>finiteFloat($c['wind_direction_10m']??null),
        'wind_gust'=>$gust,
        'precipitation'=>$prec,
        'precipitation_probability'=>finiteFloat($hv('precipitation_probability')),
        'cloud_cover'=>finiteFloat($c['cloud_cover']??null),
        'visibility_km'=>(($vv=finiteFloat($hv('visibility')))!==null?round($vv/1000,1):null),
        'weather_code'=>(int)($c['weather_code']??-1),
        'sunrise'=>$d['sunrise'][0]??null,
        'sunset'=>$d['sunset'][0]??null,
        'uv_max'=>finiteFloat($d['uv_index_max'][0]??null),
        'tropo'=>$tropo
    ];
    cacheWrite($file,$res);
    return $res;
}
function isoTs(mixed $v): ?int {
    $s=trim((string)$v);
    if($s==='') return null;
    $ts=strtotime($s);
    return $ts===false?null:$ts;
}
function freshValue(?float $value, mixed $time, int $maxAge): array {
    $ts=isoTs($time);
    $age=$ts===null?null:max(0,time()-$ts);
    $fresh=$value!==null&&$ts!==null&&$age<=$maxAge;
    return ['value'=>$fresh?$value:null,'time'=>$fresh?(string)$time:null,'age_seconds'=>$age,'fresh'=>$fresh];
}
function currentScales(?array $raw): array {
    $sc=['R'=>0,'S'=>0,'G'=>0];
    if(!is_array($raw)) return $sc;
    $cur=$raw['0']??$raw[0]??$raw['current']??null;
    if(!is_array($cur)) return $sc;
    foreach(['R','S','G'] as $t){
        $v=$cur[$t]['Scale']??$cur[$t]['scale']??$cur[$t]??0;
        if(is_string($v)&&preg_match('/([0-5])/',$v,$m)) $v=$m[1];
        $sc[$t]=max(0,min(5,(int)$v));
    }
    return $sc;
}
function spaceWeather(): array {
    $file=CACHE_DIR.'/space_v3.json';
    $cached=cacheRead($file,SPACE_TTL);
    if($cached!==null) return $cached;

    $kpRaw=httpJson('https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json');
    $sfiRaw=httpJson('https://services.swpc.noaa.gov/products/summary/10cm-flux.json');
    $scRaw=httpJson('https://services.swpc.noaa.gov/products/noaa-scales.json');

    // Kp: o produto atual retorna objetos associativos com chave "Kp" maiuscula.
    $kp=null;$kpTime=null;
    if(is_array($kpRaw)){
        for($i=count($kpRaw)-1;$i>=0;$i--){
            $r=$kpRaw[$i]??null;
            if(!is_array($r)) continue;
            foreach(['Kp','kp','kp_index','planetary_k_index','estimated_kp'] as $k){
                $f=finiteFloat($r[$k]??null);
                if($f!==null){
                    $kp=$f;
                    $kpTime=$r['time_tag']??$r['time']??null;
                    break 2;
                }
            }
        }
    }

    // SFI/F10.7: usar o endpoint summary atual, evitando o historico antigo.
    $sfi=null;$sfiTime=null;
    if(is_array($sfiRaw)){
        for($i=count($sfiRaw)-1;$i>=0;$i--){
            $r=$sfiRaw[$i]??null;
            if(!is_array($r)) continue;
            $f=finiteFloat($r['flux']??$r['f107']??null);
            if($f!==null){
                $sfi=$f;
                $sfiTime=$r['time_tag']??$r['time']??null;
                break;
            }
        }
    }

    $kpFresh=freshValue($kp,$kpTime,KP_MAX_AGE);
    $sfiFresh=freshValue($sfi,$sfiTime,SFI_MAX_AGE);
    $sc=currentScales($scRaw);

    $score=0;
    $known=0;
    if($sfiFresh['value']!==null){
        $known++;
        $v=$sfiFresh['value'];
        $score+=$v>=150?3:($v>=110?2:($v>=80?1:0));
    }
    if($kpFresh['value']!==null){
        $known++;
        $v=$kpFresh['value'];
        $score+=$v<=2?3:($v<=4?1:-2);
    }
    $score-=$sc['R']*2;

    $hf=$known===0?'indisponivel':($score>=5?'favoravel':($score>=2?'moderada':'desfavoravel'));
    $res=[
        'kp'=>$kpFresh['value'],
        'kp_time'=>$kpFresh['time'],
        'kp_age_seconds'=>$kpFresh['age_seconds'],
        'kp_fresh'=>$kpFresh['fresh'],
        'sfi'=>$sfiFresh['value'],
        'sfi_time'=>$sfiFresh['time'],
        'sfi_age_seconds'=>$sfiFresh['age_seconds'],
        'sfi_fresh'=>$sfiFresh['fresh'],
        'scales'=>$sc,
        'hf_estimate'=>$hf,
        'data_status'=>[
            'kp'=>$kpFresh['fresh']?'atual':($kp===null?'indisponivel':'antigo'),
            'sfi'=>$sfiFresh['fresh']?'atual':($sfi===null?'indisponivel':'antigo')
        ],
        'updated_at'=>gmdate(DATE_ATOM)
    ];
    cacheWrite($file,$res);
    return $res;
}

$loc=location();
$space=spaceWeather();

if(!($loc['ok']??false)){
    out([
        'ok'=>true,
        'needs_location'=>true,
        'location'=>null,
        'weather'=>null,
        'space'=>$space,
        'location_debug'=>['ip_source'=>$loc['ip_source']??'unavailable'],
        'privacy'=>'Nao foi possivel obter local aproximado automaticamente. A localizacao precisa continua opcional.'
    ]);
}

$w=weather($loc);
$source=$loc['source'];
$sourceLabel=$source==='browser'
    ?'localizacao precisa do navegador'
    :($source==='cloudflare_ip'?'Cloudflare IP':'IP aproximado');

out([
    'ok'=>$w!==null,
    'needs_location'=>false,
    'location'=>[
        'city'=>$loc['city'],
        'region'=>$loc['region'],
        'country'=>$loc['country'],
        'latitude'=>$loc['lat'],
        'longitude'=>$loc['lon'],
        'source'=>$source,
        'source_label'=>$sourceLabel,
        'ip_source'=>$loc['ip_source']??null,
        'approximate'=>$source!=='browser'
    ],
    'weather'=>$w,
    'space'=>$space,
    'privacy'=>$source==='ip_fallback'
        ?'O IP foi usado somente para obter uma localizacao aproximada e nao e gravado pelo widget.'
        :'O IP nao e armazenado pelo widget.'
]);
