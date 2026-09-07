<?php
declare(strict_types=1);

$configPath = '/etc/xlx-aprs-dprs/config.json';
$config = [];

if (is_readable($configPath)) {
    $raw = file_get_contents($configPath);
    $parsed = is_string($raw) ? json_decode($raw, true) : null;
    if (is_array($parsed)) {
        $config = $parsed;
    }
}

$reflector = strtoupper(trim((string)($config['site']['reflector'] ?? 'XLX')));
$title = trim((string)($config['site']['title'] ?? 'XLX APRS/D-PRS'));
$e = static fn(string $v): string => htmlspecialchars($v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
?><!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <meta name="theme-color" content="#06131d">
  <title><?= $e($title) ?> — <?= $e($reflector) ?></title>
  <link rel="stylesheet" href="../assets/app.css">
  <link rel="stylesheet" href="assets/standalone.css">
  <link rel="stylesheet" href="assets/digital-lab.css">
  <link rel="stylesheet" href="assets/digital-lab-operator.css">
</head>
<body data-page="aprs-dprs">
  <header class="aprs-standalone-header">
    <div>
      <strong><?= $e($reflector) ?></strong>
      <span>APRS / D-PRS</span>
    </div>
    <a href="../">Voltar ao painel</a>
  </header>

  <main class="aprs-standalone-main">
    <?php require __DIR__ . '/digital-lab-native.php'; ?>
  </main>

  <script src="assets/digital-lab.js" defer></script>
  <script src="assets/digital-lab-operator.js" defer></script>
</body>
</html>
