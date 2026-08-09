<?php
declare(strict_types=1);

function xlx_user_directory_normalize(string $value): string
{
    $value = strtoupper(trim($value));
    return preg_replace('/[^A-Z0-9]/', '', $value) ?? '';
}

function xlx_user_directory_lookup(string $callsign, array $fallback = []): array
{
    static $db = null;
    static $cache = [];

    $callsign = xlx_user_directory_normalize($callsign);
    $result = [
        'callsign' => $callsign,
        'name' => trim((string)($fallback['name'] ?? '')),
        'location' => trim((string)($fallback['location'] ?? '')),
        'source' => 'base',
    ];

    if ($callsign === '') {
        return $result;
    }

    if (isset($cache[$callsign])) {
        $cached = $cache[$callsign];
        if ($cached['name'] === '') $cached['name'] = $result['name'];
        if ($cached['location'] === '') $cached['location'] = $result['location'];
        return $cached;
    }

    $config = function_exists('cfg') ? cfg() : [];
    $path = (string)($config['users_override_db'] ?? '/var/lib/xlx-user-directory/overrides.db');

    if (!class_exists('SQLite3') || !is_readable($path)) {
        return $cache[$callsign] = $result;
    }

    try {
        $db ??= new SQLite3($path, SQLITE3_OPEN_READONLY);
        $resolved = $callsign;

        $alias = $db->prepare(
            'SELECT new_callsign FROM callsign_aliases WHERE old_callsign=:call LIMIT 1'
        );
        $alias->bindValue(':call', $callsign, SQLITE3_TEXT);
        $aliasResult = $alias->execute();
        $aliasRow = $aliasResult ? $aliasResult->fetchArray(SQLITE3_ASSOC) : false;
        if (is_array($aliasRow) && !empty($aliasRow['new_callsign'])) {
            $resolved = xlx_user_directory_normalize((string)$aliasRow['new_callsign']);
        }

        $statement = $db->prepare(
            'SELECT callsign,name,city_state FROM user_overrides WHERE callsign=:call LIMIT 1'
        );
        $statement->bindValue(':call', $resolved, SQLITE3_TEXT);
        $query = $statement->execute();
        $row = $query ? $query->fetchArray(SQLITE3_ASSOC) : false;

        if (is_array($row)) {
            $result['callsign'] = $resolved;
            $result['name'] = trim((string)($row['name'] ?? '')) ?: $result['name'];
            $result['location'] = trim((string)($row['city_state'] ?? '')) ?: $result['location'];
            $result['source'] = 'override';
        } elseif ($resolved !== $callsign) {
            $result['callsign'] = $resolved;
            $result['source'] = 'alias';
        }
    } catch (Throwable $exception) {
        // Falha de override nunca derruba o painel; usa os dados da base principal.
    }

    return $cache[$callsign] = $result;
}

function xlx_user_directory_apply(array $record): array
{
    $callsign = (string)($record['callsign'] ?? '');
    if ($callsign === '') return $record;

    $directory = xlx_user_directory_lookup($callsign, [
        'name' => (string)($record['name'] ?? ''),
        'location' => (string)($record['location'] ?? ''),
    ]);

    if ($directory['name'] !== '') $record['name'] = $directory['name'];
    if ($directory['location'] !== '') $record['location'] = $directory['location'];
    $record['directory_callsign'] = $directory['callsign'];
    $record['directory_source'] = $directory['source'];

    return $record;
}
