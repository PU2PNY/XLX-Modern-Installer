<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store, max-age=0');
header('Pragma: no-cache');

const ACCOUNTS_DB =
    '/var/lib/xlx-aprs-dprs/accounts.sqlite';

const GATEWAY_DB =
    '/var/lib/xlx-aprs-dprs/digital-lab.sqlite';

const SOCKET_FILE =
    '/var/lib/xlx-aprs-dprs/operator.sock';

const RATE_FILE =
    '/var/lib/xlx-aprs-dprs/operator-rate.json';

const REMEMBER_COOKIE =
    'XLX_APRS_DPRS_REMEMBER';

function respond(array $data, int $status = 200): never
{
    http_response_code($status);

    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES |
        JSON_INVALID_UTF8_SUBSTITUTE
    );

    exit;
}

function adb(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $pdo = new PDO(
        'sqlite:' . ACCOUNTS_DB,
        null,
        null,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $pdo->exec('PRAGMA foreign_keys=ON');
    $pdo->exec('PRAGMA busy_timeout=3000');

    return $pdo;
}

function gdb(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $pdo = new PDO(
        'sqlite:' . GATEWAY_DB,
        null,
        null,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $pdo->exec('PRAGMA busy_timeout=3000');

    return $pdo;
}

function nowUtc(): string
{
    return gmdate('Y-m-d\TH:i:s\Z');
}

function newPassword(): string
{
    return rtrim(
        strtr(
            base64_encode(random_bytes(18)),
            '+/',
            '-_'
        ),
        '='
    );
}

function normalizeCall(string $raw): string
{
    $call = strtoupper(
        preg_replace(
            '/[^A-Z0-9]/',
            '',
            $raw
        ) ?? ''
    );

    if (
        !preg_match(
            '/^(?=[A-Z0-9]*[0-9])[A-Z0-9]{3,8}$/D',
            $call
        )
    ) {
        return '';
    }

    return $call;
}

function validBirthday(int $day, int $month): bool
{
    return checkdate($month, $day, 2000);
}

function body(): array
{
    $length = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);

    if ($length > 8192) {
        respond(
            ['ok' => false, 'error' => 'payload_too_large'],
            413
        );
    }

    $raw = file_get_contents('php://input');

    if ($raw === false || strlen($raw) > 8192) {
        respond(
            ['ok' => false, 'error' => 'invalid_body'],
            400
        );
    }

    try {
        $data = json_decode(
            $raw,
            true,
            32,
            JSON_THROW_ON_ERROR
        );
    } catch (Throwable $e) {
        respond(
            ['ok' => false, 'error' => 'invalid_json'],
            400
        );
    }

    return is_array($data) ? $data : [];
}

function sameOrigin(): void
{
    $origin = trim((string)($_SERVER['HTTP_ORIGIN'] ?? ''));

    if ($origin === '') {
        return;
    }

    $originHost = strtolower((string)(parse_url($origin, PHP_URL_HOST) ?? ''));
    $requestHost = strtolower((string)($_SERVER['HTTP_HOST'] ?? ''));
    $requestHost = preg_replace('/:\\d+$/D', '', $requestHost) ?? '';

    if (
        $originHost === '' ||
        $requestHost === '' ||
        !hash_equals($requestHost, $originHost)
    ) {
        respond(
            ['ok' => false, 'error' => 'origin_denied'],
            403
        );
    }
}

function csrf(): void
{
    $expected = (string)($_SESSION['dlab_csrf'] ?? '');
    $actual = (string)($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');

    if (
        $expected === '' ||
        $actual === '' ||
        !hash_equals($expected, $actual)
    ) {
        respond(
            ['ok' => false, 'error' => 'csrf'],
            403
        );
    }
}

function passwordHash(string $password): string
{
    return password_hash(
        $password,
        PASSWORD_DEFAULT
    );
}

function userById(PDO $db, int $id): ?array
{
    $stmt = $db->prepare(
        'SELECT * FROM accounts WHERE id=? LIMIT 1'
    );

    $stmt->execute([$id]);

    $row = $stmt->fetch();

    return is_array($row) ? $row : null;
}

function userByCall(PDO $db, string $call): ?array
{
    $stmt = $db->prepare(
        'SELECT * FROM accounts WHERE callsign=? LIMIT 1'
    );

    $stmt->execute([$call]);

    $row = $stmt->fetch();

    return is_array($row) ? $row : null;
}

function clearRememberCookie(): void
{
    setcookie(
        REMEMBER_COOKIE,
        '',
        [
            'expires' => time() - 3600,
            'path' => '/',
            'secure' => true,
            'httponly' => true,
            'samesite' => 'Strict',
        ]
    );
}

function issueRemember(PDO $db, int $userId): void
{
    $selector = bin2hex(random_bytes(9));
    $validator = bin2hex(random_bytes(32));
    $hash = hash('sha256', $validator);

    $now = nowUtc();
    $expiresUnix = time() + 30 * 86400;
    $expires = gmdate(
        'Y-m-d\TH:i:s\Z',
        $expiresUnix
    );

    $stmt = $db->prepare(
        '
        INSERT INTO remember_tokens(
            user_id,
            selector,
            token_hash,
            created_at,
            expires_at
        ) VALUES(?,?,?,?,?)
        '
    );

    $stmt->execute([
        $userId,
        $selector,
        $hash,
        $now,
        $expires,
    ]);

    setcookie(
        REMEMBER_COOKIE,
        $selector . '.' . $validator,
        [
            'expires' => $expiresUnix,
            'path' => '/',
            'secure' => true,
            'httponly' => true,
            'samesite' => 'Strict',
        ]
    );
}

function revokeRemember(PDO $db, int $userId): void
{
    $stmt = $db->prepare(
        'DELETE FROM remember_tokens WHERE user_id=?'
    );

    $stmt->execute([$userId]);
}

function consumeRemember(PDO $db): ?array
{
    $cookie = (string)(
        $_COOKIE[REMEMBER_COOKIE] ?? ''
    );

    if (
        !preg_match(
            '/^([a-f0-9]{18})\.([a-f0-9]{64})$/D',
            $cookie,
            $m
        )
    ) {
        return null;
    }

    $selector = $m[1];
    $validator = $m[2];

    $stmt = $db->prepare(
        '
        SELECT
            r.id AS token_id,
            r.token_hash,
            r.expires_at,
            a.*
        FROM remember_tokens r
        JOIN accounts a ON a.id=r.user_id
        WHERE r.selector=?
        LIMIT 1
        '
    );

    $stmt->execute([$selector]);

    $row = $stmt->fetch();

    if (!is_array($row)) {
        clearRememberCookie();
        return null;
    }

    if (
        strtoupper((string)$row['status']) !== 'ACTIVE' ||
        strtotime((string)$row['expires_at']) < time() ||
        !hash_equals(
            (string)$row['token_hash'],
            hash('sha256', $validator)
        )
    ) {
        $delete = $db->prepare(
            'DELETE FROM remember_tokens WHERE selector=?'
        );

        $delete->execute([$selector]);

        clearRememberCookie();

        return null;
    }

    $delete = $db->prepare(
        'DELETE FROM remember_tokens WHERE selector=?'
    );

    $delete->execute([$selector]);

    issueRemember($db, (int)$row['id']);

    return $row;
}

function beginSession(array $user): void
{
    session_regenerate_id(true);

    $_SESSION['account_id'] = (int)$user['id'];
    $_SESSION['auth_version'] =
        (int)$user['auth_version'];

    $_SESSION['dlab_last'] = time();

    $_SESSION['dlab_csrf'] =
        bin2hex(random_bytes(32));

    $_SESSION['dlab_send_times'] = [];
}

function currentUser(): ?array
{
    $db = adb();

    $id = (int)($_SESSION['account_id'] ?? 0);

    if ($id > 0) {
        $user = userById($db, $id);

        if (
            is_array($user) &&
            strtoupper((string)$user['status']) === 'ACTIVE' &&
            (int)$user['auth_version'] ===
                (int)($_SESSION['auth_version'] ?? -1)
        ) {
            $_SESSION['dlab_last'] = time();
            return $user;
        }

        $_SESSION = [];
    }

    $remembered = consumeRemember($db);

    if (is_array($remembered)) {
        beginSession($remembered);
        return $remembered;
    }

    return null;
}

function publicAccount(array $user): array
{
    return [
        'callsign' => (string)$user['callsign'],
        'role' => (string)$user['role'],
        'status' => (string)$user['status'],
        'birth_complete' =>
            $user['birth_day'] !== null &&
            $user['birth_month'] !== null,
    ];
}

function permissions(array $user): array
{
    $role = strtoupper((string)$user['role']);

    return [
        'send_aprs' => $role === 'ADMIN',
        'manage_users' => $role === 'ADMIN',
        'reset_password' =>
            in_array(
                $role,
                ['ADMIN', 'COLLABORATOR'],
                true
            ),
        'manage_collaborators' =>
            $role === 'ADMIN',
        'audit' =>
            $role === 'ADMIN',
    ];
}

function requireRole(
    array $user,
    array $roles
): void {
    $role = strtoupper((string)$user['role']);

    if (!in_array($role, $roles, true)) {
        respond(
            ['ok' => false, 'error' => 'forbidden'],
            403
        );
    }
}

function audit(
    PDO $db,
    string $actor,
    string $actorRole,
    string $action,
    string $target = '',
    array $detail = []
): void {
    $stmt = $db->prepare(
        '
        INSERT INTO audit_log(
            ts,
            actor_callsign,
            actor_role,
            action,
            target_callsign,
            detail
        ) VALUES(?,?,?,?,?,?)
        '
    );

    $stmt->execute([
        nowUtc(),
        $actor,
        $actorRole,
        $action,
        $target !== '' ? $target : null,
        json_encode(
            $detail,
            JSON_UNESCAPED_UNICODE |
            JSON_UNESCAPED_SLASHES
        ),
    ]);
}

function recentlySeen(string $call): bool
{
    $db = gdb();

    $cutoff = gmdate(
        'Y-m-d\TH:i:s\Z',
        time() - 15 * 60
    );

    $prefix = $call . '-%';

    $stmt = $db->prepare(
        '
        SELECT 1
        FROM stations
        WHERE
            (
                callsign=:call1 OR
                callsign LIKE :prefix1
            )
            AND last_seen >= :cutoff1

        UNION ALL

        SELECT 1
        FROM messages
        WHERE
            direction="in"
            AND (
                peer=:call2 OR
                peer LIKE :prefix2
            )
            AND ts >= :cutoff2

        LIMIT 1
        '
    );

    $stmt->execute([
        ':call1' => $call,
        ':prefix1' => $prefix,
        ':cutoff1' => $cutoff,
        ':call2' => $call,
        ':prefix2' => $prefix,
        ':cutoff2' => $cutoff,
    ]);

    return (bool)$stmt->fetchColumn();
}

function rpc(array $payload): array
{
    $errno = 0;
    $error = '';

    $fp = @stream_socket_client(
        'unix://' . SOCKET_FILE,
        $errno,
        $error,
        2,
        STREAM_CLIENT_CONNECT
    );

    if ($fp === false) {
        return [
            'ok' => false,
            'error' => 'gateway_unavailable',
        ];
    }

    stream_set_timeout($fp, 3);

    fwrite(
        $fp,
        json_encode(
            $payload,
            JSON_UNESCAPED_UNICODE |
            JSON_UNESCAPED_SLASHES
        ) . "\n"
    );

    $line = fgets($fp, 65536);

    fclose($fp);

    if ($line === false) {
        return [
            'ok' => false,
            'error' => 'gateway_timeout',
        ];
    }

    try {
        $data = json_decode(
            $line,
            true,
            32,
            JSON_THROW_ON_ERROR
        );
    } catch (Throwable $e) {
        return [
            'ok' => false,
            'error' => 'gateway_invalid_response',
        ];
    }

    return is_array($data)
        ? $data
        : [
            'ok' => false,
            'error' => 'gateway_invalid_response',
        ];
}

function rateAllowed(
    string $bucket,
    int $limit,
    int $window
): bool {
    $fp = fopen(RATE_FILE, 'c+');

    if ($fp === false) {
        return true;
    }

    flock($fp, LOCK_EX);
    rewind($fp);

    $data = json_decode(
        (string)stream_get_contents($fp),
        true
    );

    if (!is_array($data)) {
        $data = [];
    }

    $key = hash(
        'sha256',
        $bucket . '|' .
        (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown')
    );

    $now = time();

    $times = array_values(
        array_filter(
            is_array($data[$key] ?? null)
                ? $data[$key]
                : [],
            static fn($v): bool =>
                is_numeric($v) &&
                ($now - (int)$v) < $window
        )
    );

    $allowed = count($times) < $limit;

    if ($allowed) {
        $times[] = $now;
        $data[$key] = $times;
    }

    rewind($fp);
    ftruncate($fp, 0);

    fwrite(
        $fp,
        json_encode(
            $data,
            JSON_UNESCAPED_SLASHES
        )
    );

    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);

    @chmod(RATE_FILE, 0640);

    return $allowed;
}

ini_set('session.use_strict_mode', '1');
ini_set('session.use_only_cookies', '1');

session_name('XLX_APRS_DPRS_OPERATOR');

session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Strict',
]);

session_start();

$method = strtoupper(
    (string)($_SERVER['REQUEST_METHOD'] ?? 'GET')
);

if ($method === 'GET') {
    $action = strtolower(
        trim((string)($_GET['action'] ?? 'status'))
    );

    $user = currentUser();

    if ($action === 'status') {
        if (!is_array($user)) {
            respond([
                'ok' => true,
                'auth' => false,
            ]);
        }

        $perm = permissions($user);

        $operator = null;

        if ($perm['send_aprs']) {
            $operator = rpc([
                'action' => 'status',
            ]);
        }

        respond([
            'ok' => true,
            'auth' => true,
            'csrf' =>
                (string)($_SESSION['dlab_csrf'] ?? ''),
            'account' => publicAccount($user),
            'permissions' => $perm,
            'operator' => $operator,
        ]);
    }

    if (!is_array($user)) {
        respond(
            ['ok' => false, 'error' => 'unauthorized'],
            401
        );
    }

    if ($action === 'users') {
        requireRole($user, ['ADMIN']);

        $q = normalizeCall(
            (string)($_GET['q'] ?? '')
        );

        if ($q !== '') {
            $stmt = adb()->prepare(
                '
                SELECT
                    callsign,
                    role,
                    status,
                    birth_day,
                    birth_month,
                    created_at,
                    last_login_at,
                    reset_count
                FROM accounts
                WHERE callsign LIKE ?
                ORDER BY callsign
                LIMIT 100
                '
            );

            $stmt->execute([$q . '%']);
        } else {
            $stmt = adb()->query(
                '
                SELECT
                    callsign,
                    role,
                    status,
                    birth_day,
                    birth_month,
                    created_at,
                    last_login_at,
                    reset_count
                FROM accounts
                ORDER BY callsign
                LIMIT 100
                '
            );
        }

        respond([
            'ok' => true,
            'users' => $stmt->fetchAll(),
        ]);
    }

    if ($action === 'audit') {
        requireRole($user, ['ADMIN']);

        $rows = adb()->query(
            '
            SELECT
                ts,
                actor_callsign,
                actor_role,
                action,
                target_callsign,
                detail
            FROM audit_log
            ORDER BY id DESC
            LIMIT 100
            '
        )->fetchAll();

        respond([
            'ok' => true,
            'audit' => $rows,
        ]);
    }

    respond(
        ['ok' => false, 'error' => 'unknown_action'],
        404
    );
}

if ($method !== 'POST') {
    header('Allow: GET, POST');

    respond(
        ['ok' => false, 'error' => 'method_not_allowed'],
        405
    );
}

sameOrigin();

$data = body();

$action = strtolower(
    trim((string)($data['action'] ?? ''))
);

$db = adb();

if ($action === 'register') {
    if (!rateAllowed('register', 3, 3600)) {
        respond(
            ['ok' => false, 'error' => 'rate_limited'],
            429
        );
    }

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $day = (int)($data['birth_day'] ?? 0);
    $month = (int)($data['birth_month'] ?? 0);

    $consent = !empty($data['birthday_consent']);

    if ($call === '') {
        respond(
            ['ok' => false, 'error' => 'invalid_callsign'],
            422
        );
    }

    if (!validBirthday($day, $month)) {
        respond(
            ['ok' => false, 'error' => 'invalid_birthday'],
            422
        );
    }

    if (!$consent) {
        respond(
            ['ok' => false, 'error' => 'birthday_consent_required'],
            422
        );
    }

    if (userByCall($db, $call)) {
        respond(
            ['ok' => false, 'error' => 'account_exists'],
            409
        );
    }

    if (!recentlySeen($call)) {
        respond(
            [
                'ok' => false,
                'error' => 'not_recently_seen',
                'message' =>
                    'Faça um beacon D-PRS no módulo B ou envie uma mensagem APRS para o indicativo de serviço configurado e tente novamente em até 15 minutos.',
            ],
            409
        );
    }

    $password = newPassword();
    $now = nowUtc();

    $stmt = $db->prepare(
        '
        INSERT INTO accounts(
            callsign,
            password_hash,
            role,
            status,
            birth_day,
            birth_month,
            birthday_consent_at,
            auth_version,
            reset_count,
            created_at,
            updated_at,
            password_changed_at,
            created_by
        ) VALUES(
            ?,
            ?,
            "USER",
            "ACTIVE",
            ?,
            ?,
            ?,
            1,
            0,
            ?,
            ?,
            ?,
            "SELF_REGISTER"
        )
        '
    );

    $stmt->execute([
        $call,
        passwordHash($password),
        $day,
        $month,
        $now,
        $now,
        $now,
        $now,
    ]);

    audit(
        $db,
        $call,
        'USER',
        'SELF_REGISTER',
        $call,
        [
            'birth_day' => $day,
            'birth_month' => $month,
        ]
    );

    respond([
        'ok' => true,
        'callsign' => $call,
        'password' => $password,
        'one_time_display' => true,
    ]);
}

if ($action === 'login') {
    if (!rateAllowed('login', 10, 900)) {
        respond(
            ['ok' => false, 'error' => 'rate_limited'],
            429
        );
    }

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $password =
        (string)($data['password'] ?? '');

    $remember = !empty($data['remember']);

    $user = $call !== ''
        ? userByCall($db, $call)
        : null;

    if (
        !is_array($user) ||
        strtoupper((string)$user['status']) !== 'ACTIVE' ||
        !password_verify(
            $password,
            (string)$user['password_hash']
        )
    ) {
        usleep(250000);

        respond(
            ['ok' => false, 'error' => 'invalid_credentials'],
            401
        );
    }

    if (
        password_needs_rehash(
            (string)$user['password_hash'],
            PASSWORD_DEFAULT
        )
    ) {
        $rehash = $db->prepare(
            '
            UPDATE accounts
            SET
                password_hash=?,
                updated_at=?
            WHERE id=?
            '
        );

        $rehash->execute([
            passwordHash($password),
            nowUtc(),
            (int)$user['id'],
        ]);

        $user = userById(
            $db,
            (int)$user['id']
        );
    }

    beginSession($user);

    $update = $db->prepare(
        '
        UPDATE accounts
        SET last_login_at=?, updated_at=?
        WHERE id=?
        '
    );

    $now = nowUtc();

    $update->execute([
        $now,
        $now,
        (int)$user['id'],
    ]);

    if ($remember) {
        revokeRemember(
            $db,
            (int)$user['id']
        );

        issueRemember(
            $db,
            (int)$user['id']
        );
    }

    respond([
        'ok' => true,
        'auth' => true,
        'csrf' => $_SESSION['dlab_csrf'],
        'account' => publicAccount($user),
        'permissions' => permissions($user),
    ]);
}

$user = currentUser();

if (!is_array($user)) {
    respond(
        ['ok' => false, 'error' => 'unauthorized'],
        401
    );
}

csrf();

$actor = (string)$user['callsign'];
$actorRole = strtoupper(
    (string)$user['role']
);

if ($action === 'logout') {
    revokeRemember(
        $db,
        (int)$user['id']
    );

    clearRememberCookie();

    $_SESSION = [];

    session_destroy();

    respond(['ok' => true]);
}

if ($action === 'set_birth') {
    if (
        $user['birth_day'] !== null ||
        $user['birth_month'] !== null
    ) {
        respond(
            ['ok' => false, 'error' => 'birthday_already_set'],
            409
        );
    }

    $day = (int)($data['birth_day'] ?? 0);
    $month = (int)($data['birth_month'] ?? 0);

    if (!validBirthday($day, $month)) {
        respond(
            ['ok' => false, 'error' => 'invalid_birthday'],
            422
        );
    }

    $now = nowUtc();

    $stmt = $db->prepare(
        '
        UPDATE accounts
        SET
            birth_day=?,
            birth_month=?,
            birthday_consent_at=?,
            updated_at=?
        WHERE id=?
        '
    );

    $stmt->execute([
        $day,
        $month,
        $now,
        $now,
        (int)$user['id'],
    ]);

    audit(
        $db,
        $actor,
        $actorRole,
        'BIRTHDAY_SET',
        $actor
    );

    respond(['ok' => true]);
}

if ($action === 'self_rotate_password') {
    $current =
        (string)($data['current_password'] ?? '');

    if (
        !password_verify(
            $current,
            (string)$user['password_hash']
        )
    ) {
        respond(
            ['ok' => false, 'error' => 'invalid_current_password'],
            401
        );
    }

    $password = newPassword();
    $now = nowUtc();
    $nextVersion =
        (int)$user['auth_version'] + 1;

    $stmt = $db->prepare(
        '
        UPDATE accounts
        SET
            password_hash=?,
            auth_version=?,
            reset_count=reset_count+1,
            password_changed_at=?,
            updated_at=?
        WHERE id=?
        '
    );

    $stmt->execute([
        passwordHash($password),
        $nextVersion,
        $now,
        $now,
        (int)$user['id'],
    ]);

    revokeRemember(
        $db,
        (int)$user['id']
    );

    clearRememberCookie();

    $_SESSION['auth_version'] =
        $nextVersion;

    audit(
        $db,
        $actor,
        $actorRole,
        'SELF_PASSWORD_ROTATED',
        $actor
    );

    respond([
        'ok' => true,
        'callsign' => $actor,
        'password' => $password,
        'one_time_display' => true,
    ]);
}

if ($action === 'send') {
    requireRole($user, ['ADMIN']);

    $dest = strtoupper(
        preg_replace(
            '/[^A-Z0-9-]/',
            '',
            (string)($data['dest'] ?? '')
        ) ?? ''
    );

    $message = trim(
        (string)($data['message'] ?? '')
    );

    if (
        strlen($dest) > 9 ||
        !preg_match(
            '/^[A-Z0-9]{3,8}(?:-[0-9]{1,2})?$/D',
            $dest
        )
    ) {
        respond(
            ['ok' => false, 'error' => 'invalid_destination'],
            422
        );
    }

    if (
        $message === '' ||
        strlen($message) > 60 ||
        !preg_match('/^[\x20-\x7E]+$/D', $message) ||
        str_contains($message, '{') ||
        str_contains($message, '}')
    ) {
        respond(
            ['ok' => false, 'error' => 'invalid_message'],
            422
        );
    }

    $now = time();

    $times = array_values(
        array_filter(
            is_array($_SESSION['dlab_send_times'] ?? null)
                ? $_SESSION['dlab_send_times']
                : [],
            static fn($v): bool =>
                is_numeric($v) &&
                ($now - (int)$v) < 3600
        )
    );

    if (
        (!empty($times) &&
         ($now - (int)end($times)) < 5) ||
        count($times) >= 20
    ) {
        respond(
            ['ok' => false, 'error' => 'rate_limited'],
            429
        );
    }

    $result = rpc([
        'action' => 'send',
        'dest' => $dest,
        'message' => $message,
    ]);

    if (empty($result['ok'])) {
        respond(
            [
                'ok' => false,
                'error' =>
                    (string)($result['error'] ?? 'send_failed'),
            ],
            409
        );
    }

    $times[] = $now;
    $_SESSION['dlab_send_times'] = $times;

    audit(
        $db,
        $actor,
        $actorRole,
        'APRS_MESSAGE_SENT',
        $dest,
        [
            'msg_id' => $result['msg_id'] ?? '',
        ]
    );

    respond([
        'ok' => true,
        'peer' => $result['peer'] ?? $dest,
        'msg_id' => $result['msg_id'] ?? '',
        'status' =>
            $result['status'] ?? 'awaiting_ack',
    ]);
}

if ($action === 'admin_create_user') {
    requireRole($user, ['ADMIN']);

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $day = (int)($data['birth_day'] ?? 0);
    $month = (int)($data['birth_month'] ?? 0);

    $role = strtoupper(
        (string)($data['role'] ?? 'USER')
    );

    if (
        $call === '' ||
        !validBirthday($day, $month) ||
        !in_array(
            $role,
            ['USER', 'COLLABORATOR'],
            true
        )
    ) {
        respond(
            ['ok' => false, 'error' => 'invalid_data'],
            422
        );
    }

    if (userByCall($db, $call)) {
        respond(
            ['ok' => false, 'error' => 'account_exists'],
            409
        );
    }

    $password = newPassword();
    $now = nowUtc();

    $stmt = $db->prepare(
        '
        INSERT INTO accounts(
            callsign,
            password_hash,
            role,
            status,
            birth_day,
            birth_month,
            birthday_consent_at,
            auth_version,
            reset_count,
            created_at,
            updated_at,
            password_changed_at,
            created_by
        ) VALUES(
            ?,?,?, "ACTIVE",?,?,?,
            1,0,?,?,?,?
        )
        '
    );

    $stmt->execute([
        $call,
        passwordHash($password),
        $role,
        $day,
        $month,
        $now,
        $now,
        $now,
        $now,
        $actor,
    ]);

    audit(
        $db,
        $actor,
        $actorRole,
        'ACCOUNT_CREATED',
        $call,
        [
            'role' => $role,
            'birth_day' => $day,
            'birth_month' => $month,
        ]
    );

    respond([
        'ok' => true,
        'callsign' => $call,
        'password' => $password,
        'one_time_display' => true,
    ]);
}

if ($action === 'reset_password') {
    requireRole(
        $user,
        ['ADMIN', 'COLLABORATOR']
    );

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $day = (int)($data['birth_day'] ?? 0);
    $month = (int)($data['birth_month'] ?? 0);

    $target = $call !== ''
        ? userByCall($db, $call)
        : null;

    if (!is_array($target)) {
        respond(
            ['ok' => false, 'error' => 'account_not_found'],
            404
        );
    }

    if (
        (int)$target['birth_day'] !== $day ||
        (int)$target['birth_month'] !== $month
    ) {
        audit(
            $db,
            $actor,
            $actorRole,
            'PASSWORD_RESET_BIRTHDAY_MISMATCH',
            $call
        );

        respond(
            ['ok' => false, 'error' => 'birthday_mismatch'],
            403
        );
    }

    $targetRole = strtoupper(
        (string)$target['role']
    );

    if ($targetRole === 'ADMIN') {
        respond(
            ['ok' => false, 'error' => 'admin_reset_denied'],
            403
        );
    }

    if (
        $actorRole === 'COLLABORATOR' &&
        $targetRole !== 'USER'
    ) {
        respond(
            ['ok' => false, 'error' => 'forbidden'],
            403
        );
    }

    $password = newPassword();
    $now = nowUtc();

    $stmt = $db->prepare(
        '
        UPDATE accounts
        SET
            password_hash=?,
            auth_version=auth_version+1,
            reset_count=reset_count+1,
            password_changed_at=?,
            updated_at=?
        WHERE id=?
        '
    );

    $stmt->execute([
        passwordHash($password),
        $now,
        $now,
        (int)$target['id'],
    ]);

    revokeRemember(
        $db,
        (int)$target['id']
    );

    audit(
        $db,
        $actor,
        $actorRole,
        'PASSWORD_RESET',
        $call
    );

    respond([
        'ok' => true,
        'callsign' => $call,
        'password' => $password,
        'one_time_display' => true,
    ]);
}

if ($action === 'set_role') {
    requireRole($user, ['ADMIN']);

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $role = strtoupper(
        (string)($data['role'] ?? '')
    );

    if (
        !in_array(
            $role,
            ['USER', 'COLLABORATOR'],
            true
        )
    ) {
        respond(
            ['ok' => false, 'error' => 'invalid_role'],
            422
        );
    }

    $target = $call !== ''
        ? userByCall($db, $call)
        : null;

    if (
        !is_array($target) ||
        strtoupper((string)$target['role']) === 'ADMIN'
    ) {
        respond(
            ['ok' => false, 'error' => 'target_denied'],
            403
        );
    }

    $stmt = $db->prepare(
        '
        UPDATE accounts
        SET
            role=?,
            auth_version=auth_version+1,
            updated_at=?
        WHERE id=?
        '
    );

    $stmt->execute([
        $role,
        nowUtc(),
        (int)$target['id'],
    ]);

    revokeRemember(
        $db,
        (int)$target['id']
    );

    audit(
        $db,
        $actor,
        $actorRole,
        'ROLE_CHANGED',
        $call,
        ['role' => $role]
    );

    respond(['ok' => true]);
}

if ($action === 'set_status') {
    requireRole($user, ['ADMIN']);

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $status = strtoupper(
        (string)($data['status'] ?? '')
    );

    if (
        !in_array(
            $status,
            ['ACTIVE', 'BLOCKED'],
            true
        )
    ) {
        respond(
            ['ok' => false, 'error' => 'invalid_status'],
            422
        );
    }

    $target = $call !== ''
        ? userByCall($db, $call)
        : null;

    if (
        !is_array($target) ||
        strtoupper((string)$target['role']) === 'ADMIN'
    ) {
        respond(
            ['ok' => false, 'error' => 'target_denied'],
            403
        );
    }

    $stmt = $db->prepare(
        '
        UPDATE accounts
        SET
            status=?,
            auth_version=auth_version+1,
            updated_at=?
        WHERE id=?
        '
    );

    $stmt->execute([
        $status,
        nowUtc(),
        (int)$target['id'],
    ]);

    revokeRemember(
        $db,
        (int)$target['id']
    );

    audit(
        $db,
        $actor,
        $actorRole,
        'STATUS_CHANGED',
        $call,
        ['status' => $status]
    );

    respond(['ok' => true]);
}

if ($action === 'update_birth') {
    requireRole($user, ['ADMIN']);

    $call = normalizeCall(
        (string)($data['callsign'] ?? '')
    );

    $day = (int)($data['birth_day'] ?? 0);
    $month = (int)($data['birth_month'] ?? 0);

    if (!validBirthday($day, $month)) {
        respond(
            ['ok' => false, 'error' => 'invalid_birthday'],
            422
        );
    }

    $target = $call !== ''
        ? userByCall($db, $call)
        : null;

    if (!is_array($target)) {
        respond(
            ['ok' => false, 'error' => 'account_not_found'],
            404
        );
    }

    $stmt = $db->prepare(
        '
        UPDATE accounts
        SET
            birth_day=?,
            birth_month=?,
            birthday_consent_at=?,
            updated_at=?
        WHERE id=?
        '
    );

    $now = nowUtc();

    $stmt->execute([
        $day,
        $month,
        $now,
        $now,
        (int)$target['id'],
    ]);

    audit(
        $db,
        $actor,
        $actorRole,
        'BIRTHDAY_UPDATED',
        $call
    );

    respond(['ok' => true]);
}

respond(
    ['ok' => false, 'error' => 'unknown_action'],
    404
);
