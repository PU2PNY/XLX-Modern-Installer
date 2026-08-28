<?php
declare(strict_types=1);

/*
 * The server installer records the number of enabled XLX modules in site.php.
 * Build the dashboard module list from that value so installations can use
 * any contiguous range from A through Z without editing this file.
 */
$site = require __DIR__ . '/config/site.php';
$moduleCount = (int)($site['radio']['module_count'] ?? 5);
$moduleCount = max(1, min(26, $moduleCount));
$ysfId = (string)($site['radio']['ysf_id'] ?? '');

$modules = [];

$standardModules = [
    'A' => ['name' => 'Envio de imagens D-STAR', 'protocol' => 'D-STAR', 'access' => '{{REFLECTOR_NAME}}-A'],
    'B' => ['name' => 'APRS / D-PRS', 'protocol' => 'Dados digitais', 'access' => '{{REFLECTOR_NAME}}-B'],
    'C' => ['name' => 'C4FM / YSF / DMR', 'protocol' => 'C4FM/YSF e DMR', 'access' => ($ysfId !== '' ? 'YSF ' . $ysfId . ' • ' : '') . 'DMR TG 4003'],
    'D' => ['name' => 'D-STAR', 'protocol' => 'D-STAR', 'access' => '{{REFLECTOR_NAME}}-D / XRF{{REFLECTOR_NUMBER}}-D'],
    'E' => ['name' => 'Teste / Echo', 'protocol' => 'D-STAR Echo', 'access' => 'Teste de áudio'],
];
for ($index = 0; $index < $moduleCount; $index++) {
    $letter = chr(65 + $index);
    $modules[$letter] = $standardModules[$letter] ?? [
        'name' => 'Módulo ' . $letter,
        'protocol' => 'D-STAR / DMR / C4FM-YSF',
        'access' => 'DMR TG ' . (4001 + $index)
            . ($ysfId !== '' ? ' • YSF ' . $ysfId : ''),
    ];
}

return [
  'server_name' => '{{REFLECTOR_TITLE}}',
  'xml_path' => '/var/log/xlxd.xml',
  'log_path' => '/var/log/xlx.log',
  'users_db' => '/xlxd/users_db/users.db',
  'users_override_db' => '/var/lib/xlx-user-directory/overrides.db',
  'history_limit' => 30,
  'modules' => $modules,
];
