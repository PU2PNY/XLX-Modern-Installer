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

/*
 * Display labels for modules. The raw letter (A..Z) is ALWAYS the internal
 * key used by filters, logic and APIs; the label is display-only. Default is
 * "DV <letter>"; override per module in site.php: radio.module_labels.
 */
$moduleLabelOverrides = is_array($site['radio']['module_labels'] ?? null)
    ? $site['radio']['module_labels'] : [];
$moduleLabels = [];
for ($index = 0; $index < $moduleCount; $index++) {
    $letter = chr(65 + $index);
    $custom = $moduleLabelOverrides[$letter] ?? null;
    $custom = is_string($custom)
        ? trim(preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $custom) ?? '')
        : '';
    $moduleLabels[$letter] = $custom !== ''
        ? mb_substr($custom, 0, 40)
        : 'DV ' . $letter;
}

/*
 * XLXD convention: DMR talkgroup 4001 = module A, 4002 = module B, ...
 * The base can be changed with radio.dmr_module_tg_base (default 4000).
 */
$dmrModuleBase = (int)($site['radio']['dmr_module_tg_base'] ?? 4000);
if ($dmrModuleBase < 0) {
    $dmrModuleBase = 4000;
}
$dmrModuleTg = static fn(int $index): string =>
    'DMR TG ' . ($dmrModuleBase + $index + 1);

$standardModules = [
    'A' => ['name' => 'D-STAR data', 'protocol' => 'D-STAR', 'access' => '{{REFLECTOR_NAME}}-A'],
    'B' => ['name' => 'APRS / D-PRS', 'protocol' => 'APRS data', 'access' => '{{REFLECTOR_NAME}}-B'],
    'C' => ['name' => 'Digital voice', 'protocol' => 'DMR / C4FM / YSF', 'access' => ($ysfId !== '' ? 'YSF ' . $ysfId . ' • ' : '') . $dmrModuleTg(2)],
    'D' => ['name' => 'D-STAR', 'protocol' => 'D-STAR', 'access' => '{{REFLECTOR_NAME}}-D / XRF{{REFLECTOR_NUMBER}}-D'],
    'E' => ['name' => 'Echo test', 'protocol' => 'D-STAR Echo', 'access' => 'Audio test'],
];
for ($index = 0; $index < $moduleCount; $index++) {
    $letter = chr(65 + $index);
    $modules[$letter] = $standardModules[$letter] ?? [
        'name' => $moduleLabels[$letter],
        'protocol' => 'Digital voice',
        'access' => $dmrModuleTg($index)
            . ($ysfId !== '' ? ' • YSF ' . $ysfId : ''),
    ];
    $modules[$letter]['label'] = $moduleLabels[$letter];
}

/*
 * Display-only protocol label overrides (radio.protocol_labels). Keys are the
 * canonical protocol values; see protocol_label()/protocol_key() in api/common.php.
 */
$protocolLabels = is_array($site['radio']['protocol_labels'] ?? null)
    ? $site['radio']['protocol_labels'] : [];

return [
  'server_name' => '{{REFLECTOR_TITLE}}',
  'xml_path' => '/var/log/xlxd.xml',
  'log_path' => '/var/log/xlx.log',
  'users_db' => '/xlxd/users_db/users.db',
  'users_override_db' => '/var/lib/xlx-user-directory/overrides.db',
  'history_limit' => 30,
  'modules' => $modules,
  'module_labels' => $moduleLabels,
  'protocol_labels' => $protocolLabels,
];
