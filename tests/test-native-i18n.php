<?php
declare(strict_types=1);
$root=dirname(__DIR__);
require_once $root.'/dashboard/i18n/bootstrap.php';
$locales=['en','es','fr','de','it'];
$pt=xlx_load_messages('pt-BR');
$files=['digital-lab-native.php','api/digital-lab-operator.php','api/digital-lab.php','assets/digital-lab-operator.js','assets/digital-lab.js','certificado-view.php','certificado-config.php','api/certificado.php','assets/certificado.js'];
$fail=0;
foreach($locales as $locale){
    $target=xlx_load_messages($locale);
    foreach($pt as $k=>$src){
        if(!str_starts_with((string)$k,'native.')) continue;
        if(!array_key_exists($k,$target)){
            fwrite(STDERR,"FAIL | $locale missing $k\n"); $fail++; continue;
        }
        if(str_contains((string)$target[$k],'ZXQ')){
            fwrite(STDERR,"FAIL | $locale mangled placeholder in $k\n"); $fail++;
        }
    }
    $tmp=sys_get_temp_dir().'/xlx-native-i18n-'.getmypid().'-'.$locale;
    @mkdir($tmp,0700,true);
    $cmd='rsync -a --exclude='.escapeshellarg('install/').' --exclude='.escapeshellarg('native/').' --exclude='.escapeshellarg('config/site.php').' '.escapeshellarg($root.'/dashboard/').' '.escapeshellarg($tmp.'/');
    exec($cmd,$o,$rc); if($rc!==0){fwrite(STDERR,"FAIL | rsync $locale\n");$fail++;continue;}
    @mkdir($tmp.'/config',0700,true);
    file_put_contents($tmp.'/config/site.php',"<?php return ['timezone'=>'UTC','reflector'=>['name'=>'XLX999','title'=>'XLX999','description'=>'Test','sysop_callsign'=>'N0CALL','location'=>'Test','country'=>'Test','domain'=>'example.invalid','contact_email'=>'x@example.invalid'],'radio'=>['reflector_number'=>'999','reflector_short_number'=>'999','module_count'=>5,'ysf_id'=>'99999','dmr_tg'=>'4003','aprs_service_callsign'=>'N0CALL-10'],'locale'=>['default'=>'$locale'],'software'=>['version'=>'TEST']];\n");
    passthru('php '.escapeshellarg($root.'/dashboard/i18n/build.php').' '.escapeshellarg($tmp).' '.escapeshellarg($locale).' >/dev/null',$rc); if($rc!==0){fwrite(STDERR,"FAIL | build $locale\n");$fail++;continue;}
    passthru('php '.escapeshellarg($root.'/dashboard/install/render-placeholders.php').' '.escapeshellarg($tmp).' >/dev/null',$rc); if($rc!==0){fwrite(STDERR,"FAIL | render $locale\n");$fail++;continue;}
    $blob=''; foreach($files as $f){$x=@file_get_contents($tmp.'/'.$f); if($x!==false)$blob.="\n".$x;}
    foreach($pt as $k=>$src){
        if(!str_starts_with((string)$k,'native.')) continue;
        $dst=(string)($target[$k]??''); $src=(string)$src;
        if(strlen($src)<12 || $src===$dst) continue;
        if(str_contains($blob,$src)){
            fwrite(STDERR,"FAIL | $locale untranslated $k: ".substr($src,0,90)."\n"); $fail++;
        }
    }
    passthru('rm -rf '.escapeshellarg($tmp));
    if($fail===0) echo "[OK] $locale native APRS/Certificate translation\n";
}
exit(min($fail,255));
