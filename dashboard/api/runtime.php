<?php
declare(strict_types=1);

require __DIR__ . '/common.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=3, stale-while-revalidate=10');

$connections = parse_xml_connections();
$modules = [];

foreach (cfg()['modules'] as $letter => $meta) {
    $modules[$letter] = [
        'module' => $letter,
        'connected_count' => 0,
    ];
}

$compactConnections = [];

foreach ($connections as $connection) {
    $module = (string)($connection['module'] ?? '');

    if (isset($modules[$module])) {
        $modules[$module]['connected_count']++;
    }

    $compactConnections[] = [
        'callsign' => (string)($connection['callsign'] ?? ''),
        'protocol' => (string)($connection['protocol'] ?? ''),
        'module' => $module,
    ];
}

echo json_encode(
    [
        'ok' => true,
        'generated_at' => time(),
        'connected_count' => count($compactConnections),
        'modules' => $modules,
        'connections' => $compactConnections,
    ],
    JSON_UNESCAPED_UNICODE |
    JSON_UNESCAPED_SLASHES |
    JSON_INVALID_UTF8_SUBSTITUTE
);
