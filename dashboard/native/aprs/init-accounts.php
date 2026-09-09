<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "[ERRO] Somente CLI.\n");
    exit(2);
}

$dbPath = $argv[1] ?? '';
$adminCall = strtoupper(trim($argv[2] ?? ''));
$credentialPath = $argv[3] ?? '';

if ($dbPath === '') {
    fwrite(STDERR, "[ERRO] Caminho do banco ausente.\n");
    exit(2);
}

if ($adminCall !== '' && !preg_match('/^(?=[A-Z0-9]*[0-9])[A-Z0-9]{3,8}$/D', $adminCall)) {
    fwrite(STDERR, "[ERRO] Indicativo administrativo inválido.\n");
    exit(2);
}

$dir = dirname($dbPath);
if (!is_dir($dir) && !mkdir($dir, 0750, true) && !is_dir($dir)) {
    fwrite(STDERR, "[ERRO] Não foi possível criar $dir.\n");
    exit(2);
}

$pdo = new PDO(
    'sqlite:' . $dbPath,
    null,
    null,
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]
);

$pdo->exec('PRAGMA foreign_keys=ON');
$pdo->exec('PRAGMA journal_mode=WAL');
$pdo->exec('PRAGMA synchronous=NORMAL');

$pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    callsign TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('ADMIN','COLLABORATOR','USER')),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','BLOCKED')),
    birth_day INTEGER,
    birth_month INTEGER,
    birthday_consent_at TEXT,
    auth_version INTEGER NOT NULL DEFAULT 1,
    reset_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    password_changed_at TEXT,
    created_by TEXT,
    last_login_at TEXT
);

CREATE TABLE IF NOT EXISTS remember_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    selector TEXT NOT NULL UNIQUE,
    token_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_remember_tokens_user
ON remember_tokens(user_id);

CREATE INDEX IF NOT EXISTS idx_remember_tokens_expires
ON remember_tokens(expires_at);

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    actor_callsign TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    action TEXT NOT NULL,
    target_callsign TEXT,
    detail TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_audit_log_ts
ON audit_log(ts DESC);
SQL);

if ($adminCall !== '') {
    $stmt = $pdo->prepare('SELECT id FROM accounts WHERE callsign=? LIMIT 1');
    $stmt->execute([$adminCall]);
    $existing = $stmt->fetch();

    if (!$existing) {
        if ($credentialPath === '') {
            fwrite(STDERR, "[ERRO] Caminho para credencial inicial ausente.\n");
            exit(2);
        }

        $password = rtrim(strtr(base64_encode(random_bytes(18)), '+/', '-_'), '=');
        $hash = password_hash($password, PASSWORD_DEFAULT);
        $now = gmdate('Y-m-d\TH:i:s\Z');

        $insert = $pdo->prepare(
            'INSERT INTO accounts(
                callsign,password_hash,role,status,
                birth_day,birth_month,birthday_consent_at,
                auth_version,reset_count,created_at,updated_at,
                password_changed_at,created_by,last_login_at
             ) VALUES(?,?,"ADMIN","ACTIVE",NULL,NULL,NULL,1,0,?,?,?,"INSTALLER",NULL)'
        );

        $insert->execute([$adminCall, $hash, $now, $now, $now]);

        $contents =
            "XLX APRS/D-PRS — CREDENCIAL ADMINISTRATIVA INICIAL\n" .
            "Indicativo: {$adminCall}\n" .
            "Senha: {$password}\n" .
            "Gerada em: {$now}\n" .
            "Troque a senha pelo painel após o primeiro acesso.\n";

        if (file_put_contents($credentialPath, $contents, LOCK_EX) === false) {
            fwrite(STDERR, "[ERRO] Não foi possível gravar a credencial inicial.\n");
            exit(2);
        }

        chmod($credentialPath, 0600);
        fwrite(STDOUT, "[OK] ADMIN criado; credencial salva localmente em {$credentialPath}\n");
    } else {
        fwrite(STDOUT, "[OK] ADMIN/conta já existe; nenhuma credencial foi alterada.\n");
    }
}

$check = $pdo->query('PRAGMA integrity_check')->fetchColumn();
if ($check !== 'ok') {
    fwrite(STDERR, "[ERRO] SQLite integrity_check falhou.\n");
    exit(2);
}

fwrite(STDOUT, "[OK] Banco de contas inicializado e íntegro.\n");
