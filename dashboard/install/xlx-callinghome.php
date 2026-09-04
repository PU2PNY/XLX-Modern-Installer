#!/usr/bin/php
<?php
declare(strict_types=1);

/*
 * XLX Modern CallingHome client.
 *
 * This client is intentionally independent from every dashboard entry point.
 * It reads protected local configuration, current XLXD XML/interlinks and
 * submits the native CallingHome XML directly to the XLX directory.
 */

function fail_callhome(string $message, int $code = 2): never
{
    fwrite(STDERR, 'CALLHOME_ERROR ' . $message . PHP_EOL);
    exit($code);
}

function xml_text(string $value): string
{
    return htmlspecialchars($value, ENT_XML1 | ENT_QUOTES, 'UTF-8');
}

function reflector_version(string $xmlPath): string
{
    $xml = @file_get_contents($xmlPath);
    if (!is_string($xml) || $xml === '') {
        fail_callhome('XLXD XML is unavailable');
    }
    if (!preg_match('/<Version>\s*([^<]+)\s*<\/Version>/i', $xml, $match)) {
        fail_callhome('XLXD version is missing from XML');
    }
    $version = trim($match[1]);
    if (!preg_match('/^[0-9]+\.[0-9]+\.[0-9]+$/', $version)) {
        fail_callhome('XLXD version has an invalid format');
    }
    return $version;
}

function interlinks_xml(string $path): string
{
    if (!is_readable($path)) {
        fail_callhome('Interlink file is not readable');
    }

    $items = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES) ?: [] as $number => $raw) {
        $line = trim($raw);
        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }
        $parts = preg_split('/\s+/', $line, 3) ?: [];
        if (count($parts) !== 3) {
            fail_callhome('invalid Interlink line ' . ($number + 1));
        }
        [$peer, $address, $modules] = $parts;
        $peer = strtoupper(trim($peer));
        $modules = strtoupper(trim($modules));
        if (!preg_match('/^[A-Z0-9]{1,8}$/', $peer)) {
            fail_callhome('invalid Interlink peer on line ' . ($number + 1));
        }
        if (!preg_match('/^[A-Za-z0-9._:-]{1,253}$/', $address)) {
            fail_callhome('invalid Interlink address on line ' . ($number + 1));
        }
        if ($modules !== '*' && !preg_match('/^[A-Z]{1,26}$/', $modules)) {
            fail_callhome('invalid Interlink modules on line ' . ($number + 1));
        }
        $items[] = '<interlink><name>' . xml_text($peer)
            . '</name><address>' . xml_text($address)
            . '</address><modules>' . xml_text($modules)
            . '</modules></interlink>';
    }

    return '<interlinks>' . implode('', $items) . '</interlinks>';
}

$configFile = (string)(getenv('XLX_CALLINGHOME_CONFIG') ?: '/etc/xlx-modern/callinghome.php');
if (!is_file($configFile) || !is_readable($configFile)) {
    fail_callhome('configuration not found');
}
$config = require $configFile;
if (!is_array($config)) {
    fail_callhome('invalid configuration');
}

$required = ['reflector_name', 'dashboard_url', 'country', 'comment', 'hash', 'server_url'];
foreach ($required as $key) {
    if (!is_string($config[$key] ?? null) || trim((string)$config[$key]) === '') {
        fail_callhome('missing configuration value: ' . $key);
    }
}

$reflectorName = strtoupper(trim((string)$config['reflector_name']));
if (!preg_match('/^XLX[0-9]{3}$/', $reflectorName)) {
    fail_callhome('invalid reflector name');
}
$hash = strtolower(trim((string)$config['hash']));
if (!preg_match('/^[a-f0-9]{32,128}$/', $hash)) {
    fail_callhome('invalid private CallingHome hash');
}
$dashboardUrl = trim((string)$config['dashboard_url']);
if (!filter_var($dashboardUrl, FILTER_VALIDATE_URL)) {
    fail_callhome('invalid dashboard URL');
}
$serverUrl = trim((string)$config['server_url']);
if (!filter_var($serverUrl, FILTER_VALIDATE_URL)) {
    fail_callhome('invalid directory URL');
}

$uptime = trim((string)getenv('XLX_UPTIME'));
if (!preg_match('/^[0-9]+$/', $uptime) || (int)$uptime <= 0) {
    fail_callhome('invalid XLXD uptime');
}

$xmlPath = (string)($config['xml_path'] ?? '/var/log/xlxd.xml');
$interlinkPath = (string)($config['interlink_path'] ?? '/xlxd/xlxd.interlink');
$version = reflector_version($xmlPath);

$payload = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    . '<query>CallingHome</query>'
    . '<reflector>'
    . '<name>' . xml_text($reflectorName) . '</name>'
    . '<uptime>' . xml_text($uptime) . '</uptime>'
    . '<hash>' . xml_text($hash) . '</hash>'
    . '<url>' . xml_text($dashboardUrl) . '</url>'
    . '<country>' . xml_text(trim((string)$config['country'])) . '</country>'
    . '<comment>' . xml_text(substr(trim((string)$config['comment']), 0, 100)) . '</comment>'
    . '<ip></ip>'
    . '<reflectorversion>' . xml_text($version) . '</reflectorversion>'
    . '</reflector>'
    . interlinks_xml($interlinkPath);

if (!function_exists('curl_init')) {
    fail_callhome('PHP cURL extension is unavailable', 3);
}
$curl = curl_init($serverUrl);
if ($curl === false) {
    fail_callhome('cannot initialize HTTP client', 3);
}
curl_setopt_array($curl, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query(['xml' => $payload]),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_TIMEOUT => 30,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_USERAGENT => 'XLX-Modern-CallingHome/2.0',
    CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
]);
$response = curl_exec($curl);
$status = (int)curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
$error = curl_error($curl);
curl_close($curl);

if ($response === false || $status < 200 || $status >= 300) {
    fail_callhome('directory POST failed HTTP=' . $status . ($error !== '' ? ' error=' . $error : ''), 4);
}

$responseBytes = strlen((string)$response);
echo 'CALLHOME_OK http=' . $status . ' response_bytes=' . $responseBytes . PHP_EOL;
