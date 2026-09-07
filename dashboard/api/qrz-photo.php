<?php
declare(strict_types=1);

header('X-Content-Type-Options: nosniff');

$call = strtoupper(trim((string)($_GET['callsign'] ?? '')));
$call = preg_replace('/[^A-Z0-9]/', '', $call) ?? '';
if ($call === '' || !preg_match('/^[A-Z0-9]{3,10}$/', $call)) {
    header('Content-Type: application/json; charset=utf-8');
    http_response_code(400);
    echo json_encode(['ok'=>false,'error'=>'invalid_callsign']);
    exit;
}

$cacheDir = '/var/cache/xlx-dashboard/qrz-photos';
$metaFile = $cacheDir . '/' . $call . '.json';
$positiveTtl = 7 * 86400;
$negativeTtl = 12 * 3600;
$now = time();

if (!is_dir($cacheDir)) {
    @mkdir($cacheDir, 0750, true);
}

$readMeta = static function(string $file): ?array {
    if (!is_readable($file)) return null;
    $raw = @file_get_contents($file);
    $data = is_string($raw) ? json_decode($raw, true) : null;
    return is_array($data) ? $data : null;
};

$writeMeta = static function(string $file, array $data): void {
    $tmp = $file . '.' . getmypid() . '.tmp';
    if (@file_put_contents($tmp, json_encode($data, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE), LOCK_EX) !== false) {
        @chmod($tmp, 0640);
        @rename($tmp, $file);
    }
};

$serveImage = static function(array $meta) use ($cacheDir): void {
    $name = basename((string)($meta['file'] ?? ''));
    if ($name === '') {
        http_response_code(404);
        exit;
    }
    $file = $cacheDir . '/' . $name;
    if (!is_readable($file)) {
        http_response_code(404);
        exit;
    }
    $mime = (string)($meta['mime'] ?? 'image/jpeg');
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . (string)filesize($file));
    header('Cache-Control: public, max-age=604800, immutable');
    readfile($file);
    exit;
};

$meta = $readMeta($metaFile);
$imageMode = isset($_GET['image']) && $_GET['image'] === '1';

if (is_array($meta)) {
    $age = $now - (int)($meta['fetched_at'] ?? 0);
    $hasPhoto = !empty($meta['photo']);
    $ttl = $hasPhoto ? $positiveTtl : $negativeTtl;
    if ($age >= 0 && $age < $ttl) {
        if ($imageMode) {
            if ($hasPhoto) $serveImage($meta);
            http_response_code(404);
            exit;
        }
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode([
            'ok'=>true,
            'callsign'=>$call,
            'photo'=>$hasPhoto,
            'url'=>$hasPhoto ? '/api/qrz-photo.php?callsign=' . rawurlencode($call) . '&image=1&v=' . (int)$meta['fetched_at'] : null,
            'cache'=>'fresh',
        ], JSON_UNESCAPED_SLASHES);
        exit;
    }
}

$fetch = static function(string $url, string $accept, float $timeout = 3.5): array {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS => 3,
        CURLOPT_CONNECTTIMEOUT_MS => 1500,
        CURLOPT_TIMEOUT_MS => (int)round($timeout * 1000),
        CURLOPT_USERAGENT => 'XLX-Modern-QRZ-Public-Photo/1.0',
        CURLOPT_HTTPHEADER => ['Accept: ' . $accept],
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $body = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $type = (string)curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
    $err = curl_error($ch);
    curl_close($ch);
    return [is_string($body) ? $body : '', $code, $type, $err];
};

[$html, $http] = $fetch('https://www.qrz.com/db/' . rawurlencode($call), 'text/html,application/xhtml+xml', 3.5);

$photoUrl = '';
if ($http >= 200 && $http < 300 && $html !== '') {
    if (preg_match('/<meta\s+[^>]*property=["\']og:image["\'][^>]*content=["\']([^"\']+)["\'][^>]*>/i', $html, $m) ||
        preg_match('/<meta\s+[^>]*content=["\']([^"\']+)["\'][^>]*property=["\']og:image["\'][^>]*>/i', $html, $m)) {
        $candidate = html_entity_decode(trim($m[1]), ENT_QUOTES|ENT_HTML5, 'UTF-8');
        $parts = @parse_url($candidate);
        $host = strtolower((string)($parts['host'] ?? ''));
        if (($parts['scheme'] ?? '') === 'https' && $host === 'cdn-bio.qrz.com') {
            $photoUrl = $candidate;
        }
    }
}

if ($photoUrl === '') {
    if (is_array($meta) && !empty($meta['photo']) && is_readable($cacheDir . '/' . basename((string)$meta['file']))) {
        if ($imageMode) $serveImage($meta);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode([
            'ok'=>true,'callsign'=>$call,'photo'=>true,
            'url'=>'/api/qrz-photo.php?callsign=' . rawurlencode($call) . '&image=1&v=' . (int)($meta['fetched_at'] ?? 0),
            'cache'=>'stale'
        ], JSON_UNESCAPED_SLASHES);
        exit;
    }
    $negative = ['callsign'=>$call,'photo'=>false,'fetched_at'=>$now];
    $writeMeta($metaFile, $negative);
    if ($imageMode) { http_response_code(404); exit; }
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode(['ok'=>true,'callsign'=>$call,'photo'=>false,'url'=>null,'cache'=>'fresh']);
    exit;
}

[$image, $imageHttp, $remoteType] = $fetch($photoUrl, 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8', 4.0);
if ($imageHttp < 200 || $imageHttp >= 300 || $image === '' || strlen($image) > 3_000_000) {
    if (is_array($meta) && !empty($meta['photo'])) {
        if ($imageMode) $serveImage($meta);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode(['ok'=>true,'callsign'=>$call,'photo'=>true,'url'=>'/api/qrz-photo.php?callsign=' . rawurlencode($call) . '&image=1&v=' . (int)($meta['fetched_at'] ?? 0),'cache'=>'stale'], JSON_UNESCAPED_SLASHES);
        exit;
    }
    http_response_code(502);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok'=>false,'error'=>'photo_fetch_failed']);
    exit;
}

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = (string)$finfo->buffer($image);
$extMap = ['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp','image/gif'=>'gif'];
if (!isset($extMap[$mime])) {
    http_response_code(415);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok'=>false,'error'=>'unsupported_image']);
    exit;
}
$ext = $extMap[$mime];
$fileName = $call . '.' . $ext;
$tmpImage = $cacheDir . '/' . $fileName . '.' . getmypid() . '.tmp';
if (@file_put_contents($tmpImage, $image, LOCK_EX) === false) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok'=>false,'error'=>'cache_write_failed']);
    exit;
}
@chmod($tmpImage, 0640);
foreach (['jpg','png','webp','gif'] as $oldExt) {
    $old = $cacheDir . '/' . $call . '.' . $oldExt;
    if ($old !== $cacheDir . '/' . $fileName) @unlink($old);
}
@rename($tmpImage, $cacheDir . '/' . $fileName);
$newMeta = ['callsign'=>$call,'photo'=>true,'file'=>$fileName,'mime'=>$mime,'fetched_at'=>$now];
$writeMeta($metaFile, $newMeta);

if ($imageMode) $serveImage($newMeta);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
echo json_encode([
    'ok'=>true,'callsign'=>$call,'photo'=>true,
    'url'=>'/api/qrz-photo.php?callsign=' . rawurlencode($call) . '&image=1&v=' . $now,
    'cache'=>'fresh'
], JSON_UNESCAPED_SLASHES);
