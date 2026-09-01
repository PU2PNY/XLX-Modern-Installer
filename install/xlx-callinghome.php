#!/usr/bin/php
<?php
declare(strict_types=1);

/*
 * XLX Modern CallingHome client.
 * Keeps the public XLX directory registration independent from the legacy
 * dashboard. Compatible with the CallingHome XML accepted by xlxapi.rlx.lu.
 */

$configFile = '/etc/xlx-modern/callinghome.php';
if (!is_file($configFile)) {
    fwrite(STDERR, "callinghome configuration not found\n");
    exit(2);
}
$config = require $configFile;
if (!is_array($config)) {
    fwrite(STDERR, "invalid callinghome configuration\n");
    exit(2);
}

$required = ['reflector_name', 'dashboard_url', 'country', 'comment', 'hash', 'server_url'];
foreach ($required as $key) {
    if (!is_string($config[$key] ?? null) || trim($config[$key]) === '') {
        fwrite(STDERR, "missing callinghome value: {$key}\n");
        exit(2);
    }
}

function xml_text(string $value): string {
    return htmlspecialchars($value, ENT_XML1 | ENT_QUOTES, 'UTF-8');
}

function service_uptime(): int {
    $output = [];
    $status = 1;
    exec('systemctl show --property=ActiveEnterTimestamp --value xlxd.service 2>/dev/null', $output, $status);
    if ($status === 0 && isset($output[0])) {
        $started = strtotime(trim($output[0]));
        if ($started !== false) {
            return max(0, time() - $started);
        }
    }
    return 0;
}

function reflector_version(string $xmlPath): string {
    $xml = @file_get_contents($xmlPath);
    if (!is_string($xml) || $xml === '') {
        return '';
    }
    if (preg_match('/<Version>\s*([^<]+)\s*<\/Version>/i', $xml, $match)) {
        return trim($match[1]);
    }
    return '';
}

function interlinks_xml(string $path): string {
    if (!is_readable($path)) {
        return '<interlinks/>';
    }

    $items = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }
        $parts = preg_split('/\s+/', $line, 3) ?: [];
        if (count($parts) < 2) {
            continue;
        }
        $items[] = '<interlink><name>' . xml_text($parts[0])
            . '</name><address>' . xml_text($parts[1])
            . '</address><modules>' . xml_text($parts[2] ?? '')
            . '</modules></interlink>';
    }
    return '<interlinks>' . implode('', $items) . '</interlinks>';
}

$xmlPath = (string)($config['xml_path'] ?? '/var/log/xlxd.xml');
$interlinkPath = (string)($config['interlink_path'] ?? '/xlxd/xlxd.interlink');
$version = reflector_version($xmlPath);

$payload = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    . '<query>CallingHome</query>'
    . '<reflector>'
    . '<name>' . xml_text($config['reflector_name']) . '</name>'
    . '<uptime>' . service_uptime() . '</uptime>'
    . '<hash>' . xml_text($config['hash']) . '</hash>'
    . '<url>' . xml_text($config['dashboard_url']) . '</url>'
    . '<country>' . xml_text($config['country']) . '</country>'
    . '<comment>' . xml_text($config['comment']) . '</comment>'
    . '<ip></ip>'
    . '<reflectorversion>' . xml_text($version) . '</reflectorversion>'
    . '</reflector>'
    . interlinks_xml($interlinkPath);

$curl = curl_init($config['server_url']);
if ($curl === false) {
    fwrite(STDERR, "cannot initialize HTTP client\n");
    exit(3);
}
curl_setopt_array($curl, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query(['xml' => $payload], '', '&', PHP_QUERY_RFC3986),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_TIMEOUT => 30,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_USERAGENT => 'XLX-Modern-CallingHome/1.0',
    CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
]);
$response = curl_exec($curl);
$status = (int)curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
$error = curl_error($curl);
curl_close($curl);

if ($response === false || $status < 200 || $status >= 300) {
    fwrite(STDERR, "callinghome request failed: HTTP {$status}" . ($error !== '' ? " ({$error})" : '') . "\n");
    exit(4);
}
echo "CallingHome accepted by directory (HTTP {$status}).\n";
