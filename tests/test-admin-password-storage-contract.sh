#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d /tmp/xlx-password-contract.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
PASS='controle'
HASH="$(printf '%s' "$PASS" | php -r '$p=stream_get_contents(STDIN);echo password_hash($p,PASSWORD_DEFAULT);')"

cat > "$TMP/good.php" <<PHP
<?php
return ['username'=>'controle','password_hash'=>'$HASH','title'=>'Admin XLXPNY'];
PHP
printf '%s' "$PASS" | php "$ROOT/control/validate-password-storage.php" "$TMP/good.php"

cat > "$TMP/bad-plain.php" <<PHP
<?php
return ['username'=>'controle','password_hash'=>'$HASH','password'=>'controle'];
PHP
if printf '%s' "$PASS" | php "$ROOT/control/validate-password-storage.php" "$TMP/bad-plain.php" >/dev/null 2>&1; then
  echo 'FAIL | plaintext password field was accepted' >&2
  exit 1
fi

cat > "$TMP/bad-hash.php" <<'PHP'
<?php
return ['username'=>'controle','password_hash'=>'not-a-password-hash'];
PHP
if printf '%s' "$PASS" | php "$ROOT/control/validate-password-storage.php" "$TMP/bad-hash.php" >/dev/null 2>&1; then
  echo 'FAIL | invalid hash was accepted' >&2
  exit 1
fi

if grep -Fq 'grep -Fq "$PASSWORD"' "$ROOT/modules/68-control-panel.sh"; then
  echo 'FAIL | old whole-file plaintext grep is still present' >&2
  exit 1
fi
grep -Fq 'validate-password-storage.php' "$ROOT/modules/68-control-panel.sh"
echo 'OK | username may equal password without false positive; plaintext password fields remain rejected'
