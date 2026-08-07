<?php
declare(strict_types=1);

$defaults = [
    'server_name' => 'XLX000',
    'reflector_code' => '000',
    'domain' => 'example.invalid',
    'sysop_callsign' => 'N0CALL',
    'location' => 'City / Region',
    'country' => 'Country',
    'locale' => 'pt-BR',
    'ysf_id' => '',
    'dmr_tg' => '',
    'dmr_radio_tg' => '',
    'dmr_default_module' => '',
    'xml_path' => '/var/log/xlxd.xml',
    'log_path' => '/var/log/xlx.log',
    'users_db' => '/xlxd/users_db/users.db',
    'ranking_json' => '/var/lib/xlx-ranking/ranking.json',
    'history_limit' => 30,
    'modules' => [
        'A' => ['name'=>'Module A','protocol'=>'D-STAR','access'=>'XLX000-A','dmr_tg'=>'','ysf_dgid'=>''],
        'B' => ['name'=>'Module B','protocol'=>'D-STAR','access'=>'XLX000-B','dmr_tg'=>'','ysf_dgid'=>''],
        'C' => ['name'=>'Module C','protocol'=>'D-STAR','access'=>'XLX000-C','dmr_tg'=>'','ysf_dgid'=>''],
        'D' => ['name'=>'Module D','protocol'=>'D-STAR','access'=>'XLX000-D','dmr_tg'=>'','ysf_dgid'=>''],
        'E' => ['name'=>'Module E','protocol'=>'D-STAR','access'=>'XLX000-E','dmr_tg'=>'','ysf_dgid'=>''],
    ],
];

$siteFile = __DIR__ . '/config/site.json';
if (!is_readable($siteFile)) {
    return $defaults;
}

try {
    $site = json_decode((string)file_get_contents($siteFile), true, 64, JSON_THROW_ON_ERROR);
    return is_array($site) ? array_replace_recursive($defaults, $site) : $defaults;
} catch (Throwable) {
    return $defaults;
}
