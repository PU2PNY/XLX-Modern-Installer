<?php
declare(strict_types=1); require __DIR__.'/common.php';
$list = fetch_reflectors();
json_out(['ok'=>true,'reflectors'=>$list,'count'=>count($list)]);
