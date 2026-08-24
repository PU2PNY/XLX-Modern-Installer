<?php
declare(strict_types=1);

const CTRL_VER = '1.1.0';
const CFG = '/etc/xlx-modern-control/config.php';
const STATE = '/var/lib/xlx-modern-control';
const HELPER = '/usr/local/sbin/xlx-modern-control-helper';

header('X-Robots-Tag: noindex, nofollow, noarchive, nosnippet');
header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header("Content-Security-Policy: default-src 'self'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'; object-src 'none'");
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

if (!is_file(CFG)) {
    http_response_code(503);
    exit('Controle XLX Modern indisponível.');
}

$cfg = require CFG;
foreach (['username', 'password_hash', 'expected_core_sha', 'expected_core_version', 'base_url', 'title'] as $key) {
    if (empty($cfg[$key]) || !is_string($cfg[$key])) {
        http_response_code(503);
        exit('Configuração inválida.');
    }
}

$baseUrl = rtrim($cfg['base_url'], '/');
$title = $cfg['title'];
$testPaths = $cfg['test_paths'] ?? [
    ['/ao-vivo', 200, 'html'],
    ['/conectados', 200, 'html'],
    ['/suporte', 200, 'html'],
    ['/ranking', 200, 'html'],
    ['/refletores', 200, 'html'],
    ['/noticias', 200, 'html'],
    ['/api/status.php', 200, 'json'],
    ['/api/live.php', 200, 'json'],
    ['/api/mtr.php', 400, 'json'],
];
if (!is_array($testPaths)) {
    $testPaths = [];
}

session_name('XLXMODERNCTRL');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/controle/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Strict',
]);
ini_set('session.use_strict_mode', '1');
ini_set('session.use_only_cookies', '1');
session_start();

function h(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function remote_ip(): string
{
    return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return (string) $_SESSION['csrf'];
}

function csrf_ok(string $value): bool
{
    return isset($_SESSION['csrf']) && hash_equals((string) $_SESSION['csrf'], $value);
}

function authenticated(): bool
{
    if (($_SESSION['auth'] ?? false) !== true) {
        return false;
    }
    $now = time();
    $last = (int) ($_SESSION['last'] ?? 0);
    $born = (int) ($_SESSION['born'] ?? 0);
    if (!$last || !$born || $now - $last > 1200 || $now - $born > 28800) {
        $_SESSION = [];
        session_destroy();
        return false;
    }
    $_SESSION['last'] = $now;
    return true;
}

function audit_event(string $event): void
{
    $safe = preg_replace('/[^A-Za-z0-9_.:-]/', '_', $event) ?? 'invalid';
    @file_put_contents(
        STATE . '/audit.log',
        date('c') . ' ip=' . remote_ip() . ' event=' . $safe . "\n",
        FILE_APPEND | LOCK_EX
    );
}

function rate_file(): string
{
    return STATE . '/login-' . hash('sha256', remote_ip()) . '.json';
}

function rate_state(): array
{
    $file = rate_file();
    $decoded = is_file($file) ? json_decode((string) @file_get_contents($file), true) : null;
    return is_array($decoded) ? $decoded : ['fails' => 0, 'first' => 0, 'locked' => 0];
}

function record_login_failure(): void
{
    $state = rate_state();
    $now = time();
    if (empty($state['first']) || $now - (int) $state['first'] > 900) {
        $state = ['fails' => 0, 'first' => $now, 'locked' => 0];
    }
    $state['fails'] = (int) $state['fails'] + 1;
    if ($state['fails'] >= 5) {
        $state['locked'] = $now + 900;
    }
    @file_put_contents(rate_file(), json_encode($state), LOCK_EX);
}

function run_helper(string $command): array
{
    $allowed = ['status', 'listeners', 'logs', 'backups', 'restart'];
    if (!in_array($command, $allowed, true)) {
        return [false, '', 64];
    }
    $output = [];
    $rc = 0;
    exec('/usr/bin/sudo -n ' . escapeshellarg(HELPER) . ' ' . escapeshellarg($command) . ' 2>&1', $output, $rc);
    return [$rc === 0, implode("\n", $output), $rc];
}

function parse_kv(string $text): array
{
    $result = [];
    foreach (preg_split('/\R/', $text) ?: [] as $line) {
        if (str_contains($line, '=')) {
            [$key, $value] = explode('=', $line, 2);
            $result[trim($key)] = trim($value);
        }
    }
    return $result;
}

function probe_url(string $url): array
{
    $output = [];
    $rc = 0;
    exec(
        '/usr/bin/curl --silent --show-error --location --connect-timeout 4 --max-time 8 --output - --write-out ' .
        escapeshellarg("\n__CODE__:%{http_code}") . ' ' . escapeshellarg($url) . ' 2>&1',
        $output,
        $rc
    );
    $text = implode("\n", $output);
    $code = 0;
    if (preg_match('/\n__CODE__:(\d{3})\s*$/', $text, $match)) {
        $code = (int) $match[1];
        $text = preg_replace('/\n__CODE__:\d{3}\s*$/', '', $text) ?? $text;
    }
    return [$code, $text, $rc];
}

$message = '';
$isBad = false;
$tests = [];
$restartOutput = '';

if (isset($_GET['logout'])) {
    audit_event('logout');
    $_SESSION = [];
    session_destroy();
    header('Location: /controle/');
    exit;
}

if (!authenticated()) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'login') {
        $state = rate_state();
        $left = max(0, (int) ($state['locked'] ?? 0) - time());
        if ($left > 0) {
            $message = "Muitas tentativas. Aguarde {$left}s.";
            $isBad = true;
        } else {
            $username = (string) ($_POST['username'] ?? '');
            $password = (string) ($_POST['password'] ?? '');
            if (hash_equals($cfg['username'], $username) && password_verify($password, $cfg['password_hash'])) {
                @unlink(rate_file());
                session_regenerate_id(true);
                $_SESSION = [
                    'auth' => true,
                    'born' => time(),
                    'last' => time(),
                    'csrf' => bin2hex(random_bytes(32)),
                ];
                audit_event('login_ok');
                header('Location: /controle/');
                exit;
            }
            record_login_failure();
            usleep(500000);
            audit_event('login_fail');
            $message = 'Usuário ou senha inválidos.';
            $isBad = true;
        }
    }
    ?><!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow,noarchive"><title><?=h($title)?></title><style>body{margin:0;background:#07111f;color:#e8f0ff;font:16px system-ui;display:grid;min-height:100vh;place-items:center}.box{width:min(92vw,430px);background:#0d1b2e;border:1px solid #294a74;border-radius:18px;padding:28px}.title{font-size:27px;font-weight:800}.muted{color:#9fb3cf;margin:7px 0 22px}label{display:block;margin-top:13px}input{width:100%;box-sizing:border-box;padding:12px;margin-top:5px;border-radius:9px;border:1px solid #37577f;background:#07111f;color:#fff}button{width:100%;padding:12px;margin-top:18px;border:0;border-radius:9px;background:#1f6feb;color:#fff;font-weight:800}.error{padding:10px;background:#4b1d25;border-radius:8px}</style></head><body><main class="box"><div class="title"><?=h($title)?></div><div class="muted">Acesso restrito</div><?php if($message):?><div class="error"><?=h($message)?></div><?php endif;?><form method="post"><input type="hidden" name="action" value="login"><label>Usuário</label><input name="username" autocomplete="username" required autofocus><label>Senha</label><input type="password" name="password" autocomplete="current-password" required><button>Entrar</button></form><div class="muted" style="margin-top:18px">XLX Modern · Controle v<?=h(CTRL_VER)?></div></main></body></html><?php
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!csrf_ok((string) ($_POST['csrf'] ?? ''))) {
        http_response_code(400);
        audit_event('csrf_fail');
        exit('Requisição inválida.');
    }
    $action = (string) ($_POST['action'] ?? '');
    if ($action === 'tests') {
        foreach ($testPaths as $test) {
            if (!is_array($test) || count($test) < 3) {
                continue;
            }
            [$path, $expected, $kind] = $test;
            $path = (string) $path;
            $expected = (int) $expected;
            $kind = (string) $kind;
            [$code, $body] = probe_url($baseUrl . $path);
            $ok = $code === $expected;
            if ($ok && $kind === 'json') {
                $ok = is_array(json_decode($body, true));
            }
            $tests[] = [$path, $code, $expected, $ok];
        }
        audit_event('tests');
    }
    if ($action === 'restart') {
        $password = (string) ($_POST['restart_password'] ?? '');
        $confirmed = ($_POST['confirm_restart'] ?? '') === 'yes';
        if (!$confirmed || !password_verify($password, $cfg['password_hash'])) {
            $message = 'Reinício cancelado: confirmação ou senha inválida.';
            $isBad = true;
            audit_event('restart_denied');
        } else {
            [$restartOk, $restartOutput] = run_helper('restart');
            $message = $restartOk ? 'XLXD reiniciado e validado com sucesso.' : 'Falha no reinício/validação.';
            $isBad = !$restartOk;
            audit_event($restartOk ? 'restart_ok' : 'restart_fail');
        }
    }
}

[, $statusText] = run_helper('status');
$status = parse_kv($statusText);
[, $statusBody] = probe_url($baseUrl . '/api/status.php?history_hours=24&control=1');
$statusApi = json_decode($statusBody, true);
if (!is_array($statusApi)) {
    $statusApi = [];
}
[, $listeners] = run_helper('listeners');
[, $logs] = run_helper('logs');
[, $backups] = run_helper('backups');
$token = csrf_token();
?><!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow,noarchive"><title><?=h($title)?></title><style>*{box-sizing:border-box}body{margin:0;background:#07111f;color:#e8f0ff;font:15px system-ui}.wrap{max-width:1180px;margin:auto;padding:20px}.top{display:flex;justify-content:space-between;align-items:center}.title{font-size:28px;font-weight:850}.muted{color:#8fa6c4}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin-top:18px}.card,.panel{background:#0d1b2e;border:1px solid #27466f;border-radius:14px}.card{padding:15px}.value{font-size:22px;font-weight:850;margin-top:5px}.ok{color:#54d98c}.bad{color:#ff7a88}.panel{padding:18px;margin-top:14px}.panel h2{margin:0 0 12px;font-size:18px}button,.btn{padding:10px 14px;border:0;border-radius:9px;background:#1f6feb;color:white;font-weight:750;text-decoration:none;cursor:pointer}.danger{background:#a83243}pre{white-space:pre-wrap;word-break:break-word;background:#07111f;border:1px solid #203a5f;border-radius:9px;padding:11px;max-height:300px;overflow:auto}.msg{padding:10px;border-radius:9px;background:#123622}.msg.bad{background:#4b1d25}.actions{display:flex;gap:10px;flex-wrap:wrap}table{width:100%;border-collapse:collapse}td,th{padding:7px;border-bottom:1px solid #203a5f;text-align:left}.restart input[type=password]{padding:10px;background:#07111f;color:#fff;border:1px solid #37577f;border-radius:8px}.logout{color:#c8daf3}.foot{text-align:center;color:#7188a6;margin:20px}</style></head><body><div class="wrap"><div class="top"><div><div class="title"><?=h($title)?></div><div class="muted">Área técnica privada</div></div><a class="logout" href="?logout=1">Sair</a></div><?php if($message):?><div class="msg <?=$isBad?'bad':''?>"><?=h($message)?></div><?php endif;?><div class="grid"><div class="card"><div class="muted">XLXD</div><div class="value <?=($status['service']??'')==='active'?'ok':'bad'?>"><?=h($status['service']??'?')?></div></div><div class="card"><div class="muted">Core</div><div class="value"><?=h($status['version']??'?')?></div></div><div class="card"><div class="muted">PID</div><div class="value"><?=h($status['pid']??'?')?></div></div><div class="card"><div class="muted">Processos</div><div class="value"><?=h($status['processes']??'?')?></div></div><div class="card"><div class="muted">Conectados</div><div class="value"><?=h((string)($statusApi['connected_count']??'?'))?></div></div><div class="card"><div class="muted">TX ativa</div><div class="value"><?=h((string)($statusApi['active_count']??'?'))?></div></div></div><section class="panel"><h2>Integridade e testes</h2><pre><?=h($status['sha']??'?')?></pre><div class="actions"><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="tests"><button>Executar testes gerais</button></form><a class="btn" href="/controle/">Atualizar</a></div><?php if($tests):?><table><tr><th>Teste</th><th>HTTP</th><th>Esperado</th><th>Resultado</th></tr><?php foreach($tests as[$path,$code,$expected,$ok]):?><tr><td><?=h($path)?></td><td><?=$code?></td><td><?=$expected?></td><td class="<?=$ok?'ok':'bad'?>"><?=$ok?'OK':'FALHOU'?></td></tr><?php endforeach;?></table><?php endif;?></section><section class="panel"><h2>Listeners UDP</h2><pre><?=h($listeners)?></pre></section><section class="panel"><h2>Logs recentes</h2><pre><?=h($logs)?></pre></section><section class="panel"><h2>Backups recentes</h2><pre><?=h($backups)?></pre></section><section class="panel"><h2>Reiniciar XLXD</h2><p class="muted">Reinicia somente o serviço XLXD e valida versão, SHA e processo depois.</p><form method="post" class="restart"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="restart"><input type="password" name="restart_password" placeholder="Confirme sua senha" required> <button class="danger">Reiniciar XLXD</button><p><label><input type="checkbox" name="confirm_restart" value="yes" required> Confirmo o reinício somente do XLXD.</label></p></form><?php if($restartOutput):?><pre><?=h($restartOutput)?></pre><?php endif;?></section><div class="foot">XLX Modern · Controle v<?=h(CTRL_VER)?> · não indexado</div></div></body></html>
