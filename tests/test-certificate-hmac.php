<?php
declare(strict_types=1);
require dirname(__DIR__) . '/dashboard/lib/certificate-signature.php';
$record = [
  'id'=>'XLX999-2026-TEST-ABC123',
  'callsign'=>'N0CALL',
  'campaign'=>['id'=>'test-campaign'],
  'issued_at'=>'2026-09-09T00:00:00Z',
];
$secret = str_repeat('S', 48);
$token = xlx_cert_token_from_record($record, $secret);
if (!xlx_cert_token_valid($record, $secret, $token)) { fwrite(STDERR,"valid token rejected\n"); exit(1); }
$tampered = $token;
$tampered[5] = $tampered[5] === 'A' ? 'B' : 'A';
if (xlx_cert_token_valid($record, $secret, $tampered)) { fwrite(STDERR,"tampered token accepted\n"); exit(2); }
$changed = $record; $changed['callsign']='N1CALL';
if (xlx_cert_token_valid($changed, $secret, $token)) { fwrite(STDERR,"changed record accepted\n"); exit(3); }
if (!str_starts_with(xlx_cert_payload($record), 'v1|')) { fwrite(STDERR,"payload version missing\n"); exit(4); }
echo "[OK] certificate HMAC valid/tampered/changed-record checks passed\n";
