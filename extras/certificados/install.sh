#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
DATA="${XLX_CERT_DATA_DIR:-/var/lib/xlx-certificates}"
CONF="${XLX_CERT_CONF_DIR:-/etc/xlx-certificates}"
KEY="${XLX_CERT_KEY_FILE:-$CONF/hmac.key}"
SKIP_PACKAGES="${XLX_CERT_SKIP_PACKAGES:-0}"
SITE_CONFIG="$DEST/config/site.php"
APP="$DEST/assets/app.js"
MENU_MARKER='XLX_CERTIFICATE_MENU_V1'

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal 'Execute como root.'
[ -f "$SITE_CONFIG" ] || fatal "Configuração do dashboard ausente: $SITE_CONFIG"
[ -f "$APP" ] || fatal "app.js ausente: $APP"
getent group www-data >/dev/null 2>&1 || fatal 'Grupo www-data não encontrado.'
command -v php >/dev/null 2>&1 || fatal 'PHP não encontrado.'
command -v openssl >/dev/null 2>&1 || fatal 'OpenSSL não encontrado.'

if ! command -v qrencode >/dev/null 2>&1; then
  if [ "$SKIP_PACKAGES" = '1' ]; then
    warn 'qrencode ausente; instalação de pacote pulada por ambiente de teste.'
  else
    info 'Instalando qrencode para QR Code local e sem dependência externa.'
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y qrencode
  fi
fi

TIMEZONE="${XLX_TIMEZONE:-}"
if [ -z "$TIMEZONE" ] && command -v timedatectl >/dev/null 2>&1; then
  TIMEZONE="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
fi
[ -n "$TIMEZONE" ] || TIMEZONE='UTC'

ANNIVERSARY="${XLX_REFLECTOR_ANNIVERSARY:-}"
if [ -z "$ANNIVERSARY" ] && [ -t 0 ]; then
  printf 'Aniversário do refletor em MM-DD (opcional, Enter para ignorar): '
  read -r ANNIVERSARY
fi
if [ -n "$ANNIVERSARY" ] && [[ ! "$ANNIVERSARY" =~ ^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
  fatal "Data de aniversário inválida: $ANNIVERSARY (use MM-DD)."
fi

php -r '
$f=$argv[1]; $tz=$argv[2]; $ann=$argv[3];
$c=require $f; if(!is_array($c)){fwrite(STDERR,"invalid config\n"); exit(2);}
$c["timezone"]=$tz;
$cert=(array)($c["certificates"]??[]);
$cert["enabled"]=true;
if($ann!=="") $cert["anniversary"]=$ann;
elseif(!array_key_exists("anniversary",$cert)) $cert["anniversary"]="";
$c["certificates"]=$cert;
$out="<?php\ndeclare(strict_types=1);\nreturn ".var_export($c,true).";\n";
if(file_put_contents($f,$out,LOCK_EX)===false) exit(3);
' "$SITE_CONFIG" "$TIMEZONE" "$ANNIVERSARY"
php -l "$SITE_CONFIG" >/dev/null
ok "Configuração universal aplicada: timezone=$TIMEZONE"

install -d -m 0750 -o root -g www-data "$DATA" "$CONF"
if [ ! -s "$KEY" ]; then
  openssl rand -hex 32 > "$KEY"
  ok 'Nova chave HMAC criada.'
else
  ok 'Chave HMAC existente preservada.'
fi
chown root:www-data "$KEY"; chmod 0640 "$KEY"

if [ ! -e "$DATA/emissoes.jsonl" ]; then
  install -m 0660 -o root -g www-data /dev/null "$DATA/emissoes.jsonl"
fi
chown root:www-data "$DATA/emissoes.jsonl"; chmod 0660 "$DATA/emissoes.jsonl"

install -D -m 0640 -o root -g www-data "$SRC/certificado.php" "$DEST/certificado.php"
install -D -m 0640 -o root -g www-data "$SRC/certificado-validar.php" "$DEST/certificado-validar.php"
install -D -m 0640 -o root -g www-data "$SRC/certificado-config.php" "$DEST/certificado-config.php"
install -D -m 0640 -o root -g www-data "$SRC/api/certificado.php" "$DEST/api/certificado.php"
install -D -m 0644 -o root -g www-data "$SRC/assets/certificado.css" "$DEST/assets/certificado.css"
install -D -m 0644 -o root -g www-data "$SRC/assets/certificado.js" "$DEST/assets/certificado.js"
install -D -m 0644 -o root -g www-data "$SRC/assets/certificado-menu.js" "$DEST/assets/certificado-menu.js"

if ! grep -Fq "$MENU_MARKER" "$APP"; then
  {
    printf '\n;/* %s */\n' "$MENU_MARKER"
    cat "$SRC/assets/certificado-menu.js"
    printf '\n'
  } >> "$APP"
fi

for file in "$DEST/certificado.php" "$DEST/certificado-validar.php" "$DEST/certificado-config.php" "$DEST/api/certificado.php"; do
  php -l "$file" >/dev/null || fatal "PHP inválido: $file"
done

ok "Sistema de certificados instalado em $DEST/certificado.php"
ok "Registros permanentes: $DATA/emissoes.jsonl"
ok "Validação HMAC: $KEY"
