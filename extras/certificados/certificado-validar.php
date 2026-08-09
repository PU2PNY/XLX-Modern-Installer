<?php
declare(strict_types=1);
require __DIR__ . '/certificado-config.php';
$reflector = cert_reflector();
$id = strtoupper(trim((string)($_GET['id'] ?? '')));
$sig = strtolower(trim((string)($_GET['sig'] ?? '')));
$valid = false;
$certificate = null;

if ($id !== '' && preg_match('/^[a-f0-9]{64}$/', $sig)) {
    $query = http_build_query(['action' => 'verify', 'id' => $id, 'sig' => $sig]);
    $url = 'http://127.0.0.1/api/certificado.php?' . $query;
    $host = preg_replace('#^https?://#i', '', $reflector['domain']) ?? '';
    $context = stream_context_create(['http' => ['timeout' => 3, 'header' => "Host: {$host}\r\nConnection: close\r\n"]]);
    $json = @file_get_contents($url, false, $context);
    $decoded = $json !== false ? json_decode($json, true) : null;
    if (is_array($decoded) && !empty($decoded['ok']) && !empty($decoded['valid']) && is_array($decoded['certificate'])) {
        $valid = true;
        $certificate = $decoded['certificate'];
    }
}
?>
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Validar certificado — <?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/certificado.css?v=1"></head><body><main class="cert-shell"><header class="cert-page-header"><a class="cert-back" href="./">← Painel</a><div><span class="cert-kicker">VALIDAÇÃO DE CERTIFICADO</span><h1><?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></h1></div></header><section class="cert-search-card"><?php if ($valid): ?><h2>✅ Certificado válido</h2><p><strong><?=htmlspecialchars((string)$certificate['callsign'], ENT_QUOTES, 'UTF-8')?></strong> — <?=htmlspecialchars((string)$certificate['name'], ENT_QUOTES, 'UTF-8')?></p><p><?=htmlspecialchars((string)$certificate['campaign_title'], ENT_QUOTES, 'UTF-8')?> • ID <?=htmlspecialchars((string)$certificate['id'], ENT_QUOTES, 'UTF-8')?></p><p>Emitido por <?=htmlspecialchars((string)$certificate['reflector_title'], ENT_QUOTES, 'UTF-8')?>.</p><?php else: ?><h2>❌ Certificado não confirmado</h2><p>O código informado não corresponde a uma emissão válida deste servidor.</p><?php endif; ?></section></main></body></html>
