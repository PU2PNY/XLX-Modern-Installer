<?php
declare(strict_types=1);

$csvFile = $argv[1] ?? '/xlxd/users_db/users_base.csv';
$dbFile = $argv[2] ?? '/xlxd/users_db/users.db';

if (!is_readable($csvFile)) {
    fwrite(STDERR, "ERROR: CSV not readable: {$csvFile}\n");
    exit(2);
}

$dir = dirname($dbFile);
if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
    fwrite(STDERR, "ERROR: cannot create database directory: {$dir}\n");
    exit(3);
}

@unlink($dbFile);

try {
    $db = new SQLite3($dbFile);
    $db->busyTimeout(5000);
    $db->exec('PRAGMA journal_mode=DELETE');
    $db->exec('PRAGMA synchronous=FULL');
    $db->exec('CREATE TABLE users (callsign TEXT PRIMARY KEY, name TEXT, city_state TEXT)');
} catch (Throwable $e) {
    fwrite(STDERR, "ERROR: cannot create SQLite database: {$e->getMessage()}\n");
    exit(4);
}

$states = [
    'Acre'=>'AC','Alagoas'=>'AL','Amapa'=>'AP','Amapá'=>'AP','Amazonas'=>'AM','Bahia'=>'BA',
    'Ceara'=>'CE','Ceará'=>'CE','Distrito Federal'=>'DF','Espirito Santo'=>'ES','Espírito Santo'=>'ES',
    'Goias'=>'GO','Goiás'=>'GO','Maranhao'=>'MA','Maranhão'=>'MA','Mato Grosso'=>'MT',
    'Mato Grosso do Sul'=>'MS','Minas Gerais'=>'MG','Para'=>'PA','Pará'=>'PA','Paraiba'=>'PB','Paraíba'=>'PB',
    'Parana'=>'PR','Paraná'=>'PR','Pernambuco'=>'PE','Piaui'=>'PI','Piauí'=>'PI','Rio de Janeiro'=>'RJ',
    'Rio Grande do Norte'=>'RN','Rio Grande do Sul'=>'RS','Rondonia'=>'RO','Rondônia'=>'RO','Roraima'=>'RR',
    'Santa Catarina'=>'SC','Sao Paulo'=>'SP','São Paulo'=>'SP','Sergipe'=>'SE','Tocantins'=>'TO'
];

$handle = fopen($csvFile, 'rb');
if ($handle === false) {
    fwrite(STDERR, "ERROR: cannot open CSV: {$csvFile}\n");
    exit(5);
}

$header = fgetcsv($handle);
if (!is_array($header) || count($header) < 7) {
    fwrite(STDERR, "ERROR: invalid RadioID CSV header\n");
    exit(6);
}

$stmt = $db->prepare('INSERT OR REPLACE INTO users (callsign, name, city_state) VALUES (:callsign, :name, :city_state)');
if ($stmt === false) {
    fwrite(STDERR, "ERROR: cannot prepare SQLite insert\n");
    exit(7);
}

$db->exec('BEGIN IMMEDIATE TRANSACTION');
$count = 0;
while (($row = fgetcsv($handle)) !== false) {
    if (count($row) < 7) {
        continue;
    }

    $callsign = strtoupper(trim((string)$row[1]));
    if ($callsign === '' || !preg_match('/^[A-Z0-9\/\-]{3,16}$/', $callsign)) {
        continue;
    }

    $first = trim((string)$row[2]);
    $last = trim((string)$row[3]);
    $name = trim($first . ' ' . $last);
    $city = trim((string)$row[4]);
    $state = trim((string)$row[5]);
    $state = $states[$state] ?? $state;
    $cityState = trim($city . ($city !== '' && $state !== '' ? ', ' : '') . $state);

    $stmt->bindValue(':callsign', $callsign, SQLITE3_TEXT);
    $stmt->bindValue(':name', $name, SQLITE3_TEXT);
    $stmt->bindValue(':city_state', $cityState, SQLITE3_TEXT);
    $stmt->execute();
    $count++;
}

fclose($handle);
$db->exec('COMMIT');
$db->exec('CREATE INDEX IF NOT EXISTS idx_users_callsign ON users(callsign)');
$db->close();

if ($count < 1000) {
    fwrite(STDERR, "ERROR: suspiciously small user database: {$count} rows\n");
    @unlink($dbFile);
    exit(8);
}

fwrite(STDOUT, "USERS_DB_ROWS={$count}\n");
