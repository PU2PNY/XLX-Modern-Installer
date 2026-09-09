<?php
declare(strict_types=1);
$root = dirname(__DIR__);
$locales = ['pt-BR','en','es','fr','de','it'];
foreach ($locales as $locale) {
    $tmp = sys_get_temp_dir() . '/xlx-route-i18n-' . bin2hex(random_bytes(5));
    mkdir($tmp, 0700, true);
    $copy = 'cp -a ' . escapeshellarg($root . '/dashboard/.') . ' ' . escapeshellarg($tmp . '/');
    exec($copy, $o, $rc); if ($rc !== 0) exit(10);
    @mkdir($tmp . '/config', 0700, true);
    $cfg = <<<'PHP'
<?php
return [
 'reflector'=>['name'=>'XLX999','title'=>'XLX999 Test','description'=>'Test','sysop_callsign'=>'N0CALL','location'=>'Test City','country'=>'Test','domain'=>'xlx999.example.invalid','contact_email'=>'noreply@example.invalid'],
 'radio'=>['reflector_number'=>'999','reflector_short_number'=>'999','ysf_id'=>'99999','dmr_tg'=>'4999','aprs_service_callsign'=>'N0CALL-10'],
 'locale'=>['default'=>'pt-BR'],
];
PHP;
    file_put_contents($tmp . '/config/site.php', $cfg);
    passthru('php ' . escapeshellarg($tmp . '/i18n/build.php') . ' ' . escapeshellarg($tmp) . ' ' . escapeshellarg($locale), $rc);
    if ($rc !== 0) { fwrite(STDERR, "FAIL build $locale\n"); exit(20); }
    $index = file_get_contents($tmp . '/index.php');
    foreach (["'certificado'", "'digital-lab'", "certificado-view.php", "digital-lab-native.php", "qrcode.min.js"] as $needle) {
        if (!str_contains($index, $needle)) {
            fwrite(STDERR, "FAIL $locale missing $needle\n"); exit(30);
        }
    }
    if (preg_match('/__XLX_ROUTE_[A-Z0-9_]+__/', $index)) {
        fwrite(STDERR, "FAIL $locale unresolved route sentinel\n"); exit(40);
    }
    exec('rm -rf ' . escapeshellarg($tmp));
    echo "[OK] $locale native routes preserved\n";
}
