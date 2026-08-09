<?php
declare(strict_types=1);
require __DIR__ . '/certificado-config.php';
$reflector = cert_reflector();
$campaign = cert_current_campaign();
?>
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,follow">
<title>Certificados — <?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></title>
<link rel="stylesheet" href="assets/certificado.css?v=1">
</head>
<body>
<main class="cert-shell">
  <header class="cert-page-header">
    <a href="./" class="cert-back">← Painel</a>
    <div>
      <span class="cert-kicker">CERTIFICADOS DE PARTICIPAÇÃO</span>
      <h1><?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></h1>
      <p><?=htmlspecialchars($campaign['title'], ENT_QUOTES, 'UTF-8')?> • <?=htmlspecialchars($campaign['period_label'], ENT_QUOTES, 'UTF-8')?></p>
    </div>
  </header>

  <section class="cert-search-card">
    <label for="certCallsign">Digite seu indicativo</label>
    <div class="cert-search-row">
      <input id="certCallsign" maxlength="12" autocomplete="off" spellcheck="false" placeholder="Ex.: PU2PNY">
      <button id="certSearch" type="button">Verificar participação</button>
    </div>
    <p id="certMessage" class="cert-message" aria-live="polite"></p>
  </section>

  <section id="certPreview" class="certificate" hidden>
    <div class="certificate-border">
      <div class="certificate-topline"></div>
      <div class="certificate-brand"><?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></div>
      <div class="certificate-special"><?=htmlspecialchars($campaign['title'], ENT_QUOTES, 'UTF-8')?></div>
      <h2>Certificado de Participação</h2>
      <p class="certificate-intro">Certificamos a participação do radioamador</p>
      <div id="certName" class="certificate-name"></div>
      <div id="certCall" class="certificate-call"></div>
      <p id="certText" class="certificate-text"></p>
      <div class="certificate-stats">
        <div><strong id="statTx">0</strong><span>transmissões</span></div>
        <div><strong id="statTime">0s</strong><span>tempo no ar</span></div>
        <div><strong id="statModes">—</strong><span>protocolos</span></div>
      </div>
      <div class="certificate-footer">
        <div>
          <span>Validação</span>
          <strong id="certId">—</strong>
          <small id="certIssued"></small>
        </div>
        <div id="certQr" class="certificate-qr"></div>
        <div class="certificate-signature">
          <span>Responsável</span>
          <strong><?=htmlspecialchars($reflector['sysop_callsign'], ENT_QUOTES, 'UTF-8')?></strong>
          <small><?=htmlspecialchars($reflector['title'], ENT_QUOTES, 'UTF-8')?></small>
        </div>
      </div>
    </div>
  </section>

  <div id="certActions" class="cert-actions" hidden>
    <button id="certIssue" type="button">Emitir certificado</button>
    <button id="certPrint" type="button" disabled>Imprimir / Salvar PDF</button>
  </div>
</main>
<script>
window.XLX_CERT = <?=json_encode([
    'api' => 'api/certificado.php',
    'reflector' => $reflector,
    'campaign' => $campaign,
], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)?>;
</script>
<script src="assets/certificado.js?v=1" defer></script>
</body>
</html>
