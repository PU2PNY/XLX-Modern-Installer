<?php
declare(strict_types=1);
/* Verified old callsign -> current Radio ID identity, read only and local. */
function xlx026_current_radioid_call(array &$row): void {
    $old = strtoupper((string)($row['callsign'] ?? ''));
    if ($old === '' || !str_contains(strtoupper((string)($row['protocol'] ?? '')), 'DMR')) return;
    static $aliases = null;
    if ($aliases === null) {
        $raw = @file_get_contents('/var/lib/xlx026-identity/radioid-aliases.json');
        $decoded = is_string($raw) ? json_decode($raw, true) : null;
        $aliases = is_array($decoded) ? $decoded : [];
    }
    $entry = $aliases[$old] ?? null;
    if (!is_array($entry) || !preg_match('/^[0-9]{7}$/', (string)($entry['id'] ?? ''))) return;
    $current = strtoupper((string)($entry['callsign'] ?? ''));
    if (!preg_match('/^[A-Z0-9]{3,8}$/', $current) || $current === $old) return;
    $row['network_callsign'] = $row['network_callsign'] ?? $old;
    $row['callsign'] = $current;
    $row['name'] = (string)($entry['name'] ?? $row['name'] ?? '');
    $row['location'] = (string)($entry['location'] ?? $row['location'] ?? '');
    $row['qrz'] = 'https://www.qrz.com/db/' . rawurlencode($current);
    if (strtoupper((string)($row['gateway'] ?? '')) === $old) $row['gateway'] = $current;
    $row['display_source'] = 'radioid-verified-id-alias';
}
