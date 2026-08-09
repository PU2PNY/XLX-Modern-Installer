<?php
declare(strict_types=1);
require __DIR__ . '/certificado-config.php';
$reflector = cert_reflector();
$id = strtoupper(trim((string)($_GET['id'] ?? '')));
$sig = strtolower(trim((string)($_GET['sig'] ?? '')));
$valid = false;
$certificate = null;

$dataDir = getenv('XLX_CERT_DATA_DIR') ?: '/var/lib/xlx-certificates';
$keyFile = getenv('XLX_CERT_KEY_FILE') ?: '/etc/xlx-certificates/hmac.key';
$records = $dataDir . '/emissoes.jsonl';
$key = @file_get_contents($keyFile);

if ($id !== '' && preg_match('/^[A-Z0-9-]{12,80}$/', $id) && preg_match('/^[a-f0-9]{64}$/', $sig) && $key !== false && is_readable($records)) {
    $handle = fopen($records, 'rb');
    if ($handle) {
        while (($line = fgets($handle)) !== false) {
            $row = json_decode(trim($line), true);
            if (!is_array($row) || ($row['id'] ?? '') !== $id) continue;
            $canonical = implode('|', [
                (string)($row['id'] ?? ''),
                (string)($row['campaign_id'] ?? ''),
                (string)($row['callsign'] ?? ''),
                (string)($row['issued_at'] ?? ''),
                (string)($row['reflector'] ?? ''),
            ]);
            $expected = hash_hmac('sha256', $canonical, trim($key));
            if (hash_equals($expected, $sig)) {
                $valid = true;
                $certificate = $row;
            }
            break;
        }
        fclose($handle);
    }
}
?>
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Validar certificado — <?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></title><link rel="stylesheet" href="assets/certificado.css?v=1"></head><body><main class="cert-shell"><header class="cert-page-header"><a class="cert-back" href="./">← Painel</a><div><span class="cert-kicker">VALIDAÇÃO DE CERTIFICADO</span><h1><?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></h1></div></header><section class="cert-search-card"><?php if ($valid && is_array($certificate)): ?><h2>✅ Certificado válido</h2><p><strong><?=htmlspecialchars((string)$certificate['callsign'], ENT_QUOTES, 'UTF-8')?></strong> — <?=htmlspecialchars((string)$certificate['name'], ENT_QUOTES, 'UTF-8')?></p><p><?=htmlspecialchars((string)$certificate['campaign_title'], ENT_QUOTES, 'UTF-8')?> • ID <?=htmlspecialchars((string)$certificate['id'], ENT_QUOTES, 'UTF-8')?></p><p>Emitido por <?=htmlspecialchars((string)$certificate['reflector_title'], ENT_QUOTES, 'UTF-8')?>.</p><?php else: ?><h2>❌ Certificado não confirmado</h2><p>O código informado não corresponde a uma emissão válida deste servidor.</p><?php endif; ?></section></main></body></html>
