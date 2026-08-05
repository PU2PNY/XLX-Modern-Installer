#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
BACKUPS="${BACKUP_ROOT:-/var/backups/xlx-reflector}"
ask(){ local n="$1" p="$2" v=""; while [ -z "$v" ]; do read -r -p "$p: " v; done; printf -v "$n" '%s' "$v"; }
escape(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"; }
[ "$(id -u)" -eq 0 ] || { echo "Execute como root." >&2; exit 1; }
ask REFLECTOR_NAME "Identificação do refletor"
ask REFLECTOR_TITLE "Nome exibido"
ask REFLECTOR_DESCRIPTION "Descrição curta"
ask SYSOP_CALLSIGN "Indicativo do responsável"
ask LOCATION "Cidade e estado/região"
ask COUNTRY "País"
ask DOMAIN "Domínio"
ask CONTACT_EMAIL "E-mail de contato"
if [ -e "$DEST" ]; then stamp="$(date +%Y%m%d_%H%M%S)"; mkdir -p "$BACKUPS"; tar -C "$(dirname "$DEST")" -czpf "$BACKUPS/dashboard-$stamp.tar.gz" "$(basename "$DEST")"; fi
mkdir -p "$DEST"
rsync -a --delete --exclude='install/' --exclude='config/site.php' "$ROOT/" "$DEST/"
mkdir -p "$DEST/config"
cat > "$DEST/config/site.php" <<PHP
<?php
declare(strict_types=1);
return [
 'reflector'=>[
  'name'=>'$(escape "$REFLECTOR_NAME")','title'=>'$(escape "$REFLECTOR_TITLE")',
  'description'=>'$(escape "$REFLECTOR_DESCRIPTION")',
  'sysop_callsign'=>'$(escape "$SYSOP_CALLSIGN")',
  'location'=>'$(escape "$LOCATION")','country'=>'$(escape "$COUNTRY")',
  'domain'=>'$(escape "$DOMAIN")','contact_email'=>'$(escape "$CONTACT_EMAIL")',
 ],
 'branding'=>[
  'header_title'=>'$(escape "$REFLECTOR_TITLE")',
  'header_subtitle'=>'$(escape "$REFLECTOR_DESCRIPTION")','footer_text'=>'',
 ],
 'features'=>[
  'show_support_menu'=>false,'show_contact_email'=>true,
  'show_location'=>true,'show_sysop_callsign'=>true,
 ],
];
PHP
find "$DEST" -type d -exec chmod 755 {} \;
find "$DEST" -type f -exec chmod 644 {} \;
chown -R root:www-data "$DEST"
chmod 640 "$DEST/config/site.php"
find "$DEST" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null
printf 'XLX Modern Dashboard instalado em %s\n' "$DEST"
