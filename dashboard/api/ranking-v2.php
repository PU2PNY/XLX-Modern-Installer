<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

$config = require dirname(__DIR__) . '/config.php';
$file = (string)($config['ranking_json'] ?? '/var/lib/xlx-ranking/ranking.json');

if (!is_readable($file)) {
    http_response_code(503);
    echo json_encode(['ok'=>false,'error'=>'ranking_unavailable']);
    exit;
}

$data = json_decode((string)file_get_contents($file), true);
if (!is_array($data) || empty($data['ok'])) {
    http_response_code(503);
    echo json_encode(['ok'=>false,'error'=>'ranking_invalid']);
    exit;
}

$data['age_seconds'] = max(0, time() - (int)($data['generated_at'] ?? 0));
echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
