<?php
declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: validate-password-storage.php CONFIG\n");
    exit(64);
}

$configFile = $argv[1];
$password = stream_get_contents(STDIN);
if ($password === false || $password === '') {
    fwrite(STDERR, "password input missing\n");
    exit(65);
}

$config = require $configFile;
if (!is_array($config)) {
    fwrite(STDERR, "config is not an array\n");
    exit(66);
}

$hash = $config['password_hash'] ?? null;
if (!is_string($hash) || $hash === '' || !password_verify($password, $hash)) {
    fwrite(STDERR, "password_hash verification failed\n");
    exit(67);
}

$info = password_get_info($hash);
if (($info['algoName'] ?? 'unknown') === 'unknown') {
    fwrite(STDERR, "password_hash algorithm is invalid\n");
    exit(68);
}

$containsPlaintextPasswordField = static function (mixed $node) use (&$containsPlaintextPasswordField, $password): bool {
    if (!is_array($node)) {
        return false;
    }
    foreach ($node as $key => $value) {
        $keyString = (string)$key;
        if ($keyString === 'password_hash') {
            continue;
        }
        if (preg_match('/(?:^|_)(?:password|passwd|passphrase)(?:_|$)/i', $keyString) === 1) {
            if (is_scalar($value) && hash_equals($password, (string)$value)) {
                return true;
            }
        }
        if (is_array($value) && $containsPlaintextPasswordField($value)) {
            return true;
        }
    }
    return false;
};

if ($containsPlaintextPasswordField($config)) {
    fwrite(STDERR, "plain-text password field detected\n");
    exit(69);
}

exit(0);
