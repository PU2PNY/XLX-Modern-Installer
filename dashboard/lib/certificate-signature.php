<?php
declare(strict_types=1);

/** Stable certificate-signature contract shared by issuance and verification. */
function xlx_cert_payload(array $record): string
{
    return implode('|', [
        'v1',
        (string)($record['id'] ?? ''),
        (string)($record['callsign'] ?? ''),
        (string)($record['campaign']['id'] ?? ''),
        (string)($record['issued_at'] ?? ''),
    ]);
}

function xlx_cert_token_from_record(array $record, string $secret): string
{
    if (strlen($secret) < 32) {
        throw new RuntimeException('Certificate signing secret is unavailable.');
    }
    $raw = hash_hmac('sha256', xlx_cert_payload($record), $secret, true);
    return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
}

function xlx_cert_token_valid(array $record, string $secret, string $provided): bool
{
    if ($provided === '') return false;
    return hash_equals(xlx_cert_token_from_record($record, $secret), $provided);
}
