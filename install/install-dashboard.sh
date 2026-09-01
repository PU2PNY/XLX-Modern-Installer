#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
BACKUPS="${BACKUP_ROOT:-/var/backups/xlx-reflector}"
DASHBOARD_LANG="${DASHBOARD_LANG:-}"

for arg in "$@"; do
    case "$arg" in
        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;
        -h|--help)
            cat <<'HELP'
XLX Modern Dashboard Installer

Usage / Uso:
  sudo bash install-dashboard.sh
  sudo bash install-dashboard.sh --lang=en

Supported dashboard languages / Idiomas suportados:
  pt-BR  Português (Brasil)
  en     English
  es     Español
  fr     Français
  de     Deutsch
  it     Italiano
HELP
            exit 0
            ;;
        *) echo "ERROR / ERRO: unknown option / opção desconhecida: $arg" >&2; exit 2 ;;
    esac
done

normalize_lang() {
    local value="${1:-}"
    value="${value/_/-}"
    case "${value,,}" in
        pt|pt-br) printf '%s' 'pt-BR' ;;
        en|en-us|en-gb) printf '%s' 'en' ;;
        es|es-es|es-mx|es-ar) printf '%s' 'es' ;;
        fr|fr-fr|fr-ca) printf '%s' 'fr' ;;
        de|de-de|de-at|de-ch) printf '%s' 'de' ;;
        it|it-it) printf '%s' 'it' ;;
        *) return 1 ;;
    esac
}

language_name() {
    case "$1" in
        pt-BR) printf '%s' 'Português (Brasil)' ;;
        en) printf '%s' 'English' ;;
        es) printf '%s' 'Español' ;;
        fr) printf '%s' 'Français' ;;
        de) printf '%s' 'Deutsch' ;;
        it) printf '%s' 'Italiano' ;;
        *) printf '%s' "$1" ;;
    esac
}

choose_language() {
    local answer normalized

    if [ -n "$DASHBOARD_LANG" ]; then
        normalized="$(normalize_lang "$DASHBOARD_LANG" 2>/dev/null || true)"
        [ -n "$normalized" ] || {
            echo "ERROR / ERRO: unsupported dashboard language / idioma não suportado: $DASHBOARD_LANG" >&2
            exit 2
        }
        DASHBOARD_LANG="$normalized"
        return
    fi

    cat <<'MENU'

============================================================
 Dashboard Language / Idioma do Painel
============================================================
  1) Português (Brasil)
  2) English
  3) Español
  4) Français
  5) Deutsch
  6) Italiano
MENU

    while :; do
        read -r -p "Choose / Escolha [1-6]: " answer
        case "$answer" in
            1) DASHBOARD_LANG='pt-BR'; break ;;
            2) DASHBOARD_LANG='en'; break ;;
            3) DASHBOARD_LANG='es'; break ;;
            4) DASHBOARD_LANG='fr'; break ;;
            5) DASHBOARD_LANG='de'; break ;;
            6) DASHBOARD_LANG='it'; break ;;
            *) echo "Invalid option / Opção inválida." ;;
        esac
    done
}

prompt_text() {
    local key="$1"
    case "$DASHBOARD_LANG:$key" in
        pt-BR:reflector) printf '%s' 'Identificação do refletor' ;;
        pt-BR:title) printf '%s' 'Nome exibido' ;;
        pt-BR:description) printf '%s' 'Descrição curta' ;;
        pt-BR:sysop) printf '%s' 'Indicativo do responsável' ;;
        pt-BR:location) printf '%s' 'Cidade e estado/região' ;;
        pt-BR:country) printf '%s' 'País' ;;
        pt-BR:domain) printf '%s' 'Domínio' ;;
        pt-BR:email) printf '%s' 'E-mail de contato' ;;

        es:reflector) printf '%s' 'Identificación del reflector' ;;
        es:title) printf '%s' 'Nombre mostrado' ;;
        es:description) printf '%s' 'Descripción corta' ;;
        es:sysop) printf '%s' 'Indicativo del responsable' ;;
        es:location) printf '%s' 'Ciudad y estado/región' ;;
        es:country) printf '%s' 'País' ;;
        es:domain) printf '%s' 'Dominio' ;;
        es:email) printf '%s' 'Correo de contacto' ;;

        fr:reflector) printf '%s' 'Identifiant du réflecteur' ;;
        fr:title) printf '%s' 'Nom affiché' ;;
        fr:description) printf '%s' 'Description courte' ;;
        fr:sysop) printf '%s' 'Indicatif du responsable' ;;
        fr:location) printf '%s' 'Ville et région' ;;
        fr:country) printf '%s' 'Pays' ;;
        fr:domain) printf '%s' 'Domaine' ;;
        fr:email) printf '%s' 'E-mail de contact' ;;

        de:reflector) printf '%s' 'Reflektorkennung' ;;
        de:title) printf '%s' 'Angezeigter Name' ;;
        de:description) printf '%s' 'Kurzbeschreibung' ;;
        de:sysop) printf '%s' 'Rufzeichen des Betreibers' ;;
        de:location) printf '%s' 'Stadt und Region' ;;
        de:country) printf '%s' 'Land' ;;
        de:domain) printf '%s' 'Domain' ;;
        de:email) printf '%s' 'Kontakt-E-Mail' ;;

        it:reflector) printf '%s' 'Identificativo del riflettore' ;;
        it:title) printf '%s' 'Nome visualizzato' ;;
        it:description) printf '%s' 'Descrizione breve' ;;
        it:sysop) printf '%s' 'Nominativo del responsabile' ;;
        it:location) printf '%s' 'Città e regione' ;;
        it:country) printf '%s' 'Paese' ;;
        it:domain) printf '%s' 'Dominio' ;;
        it:email) printf '%s' 'E-mail di contatto' ;;

        *:reflector) printf '%s' 'Reflector identifier' ;;
        *:title) printf '%s' 'Displayed name' ;;
        *:description) printf '%s' 'Short description' ;;
        *:sysop) printf '%s' 'Sysop callsign' ;;
        *:location) printf '%s' 'City and state/region' ;;
        *:country) printf '%s' 'Country' ;;
        *:domain) printf '%s' 'Domain' ;;
        *:email) printf '%s' 'Contact email' ;;
    esac
}

ask() {
    local var_name="$1" label_key="$2" value=""
    while [ -z "$value" ]; do
        read -r -p "$(prompt_text "$label_key"): " value
    done
    printf -v "$var_name" '%s' "$value"
}

reuse_or_ask() {
    local var_name label_key value
    var_name="$1"
    label_key="$2"
    value="${!var_name:-}"
    if [ -n "$value" ]; then
        printf '%s: %s [reaproveitado]\n' "$(prompt_text "$label_key")" "$value"
    else
        ask "$var_name" "$label_key"
    fi
}

module_last_letter() {
    local code
    printf -v code '%03o' "$((64 + $1))"
    printf '%b' "\\$code"
}

load_install_state() {
    local file="${XLX_INSTALL_STATE_FILE:-}"
    [ -n "$file" ] || return 0
    [ -f "$file" ] || { echo "ERROR / ERRO: dados iniciais não encontrados: $file" >&2; exit 1; }
    # This file is created by the root-owned base installer using printf %q.
    # It is read only by this same root installation process.
    # shellcheck disable=SC1090
    source "$file"
    printf 'Dados já informados serão reaproveitados.\n\n'
}

dashboard_site_value() {
    local key="$1"

    php -r '
        $site = require $argv[1];
        $value = $site;
        foreach (explode(".", $argv[2]) as $part) {
            if (!is_array($value) || !array_key_exists($part, $value)) {
                exit(0);
            }
            $value = $value[$part];
        }
        if (is_scalar($value)) {
            echo (string) $value;
        }
    ' "$DEST/config/site.php" "$key"
}

load_existing_dashboard_values() {
    [ -f "$DEST/config/site.php" ] || return 0

    [ -n "${REFLECTOR_NAME:-}" ] || REFLECTOR_NAME="$(dashboard_site_value reflector.name)"
    [ -n "${REFLECTOR_TITLE:-}" ] || REFLECTOR_TITLE="$(dashboard_site_value reflector.title)"
    [ -n "${REFLECTOR_DESCRIPTION:-}" ] || REFLECTOR_DESCRIPTION="$(dashboard_site_value reflector.description)"
    [ -n "${SYSOP_CALLSIGN:-}" ] || SYSOP_CALLSIGN="$(dashboard_site_value reflector.sysop_callsign)"
    [ -n "${LOCATION:-}" ] || LOCATION="$(dashboard_site_value reflector.location)"
    [ -n "${COUNTRY:-}" ] || COUNTRY="$(dashboard_site_value reflector.country)"
    [ -n "${DOMAIN:-}" ] || DOMAIN="$(dashboard_site_value reflector.domain)"
    [ -n "${CONTACT_EMAIL:-}" ] || CONTACT_EMAIL="$(dashboard_site_value reflector.contact_email)"
    [ -n "${YSF_ID:-}" ] || YSF_ID="$(dashboard_site_value radio.ysf_id)"
    [ -n "${MODULE_COUNT:-}" ] || MODULE_COUNT="$(dashboard_site_value radio.module_count)"
    [ -n "${DASHBOARD_LANG:-}" ] || DASHBOARD_LANG="$(dashboard_site_value locale.default)"

    # Normalize legacy values before checking for an existing certificate.
    if [ -n "${DOMAIN:-}" ]; then
        DOMAIN="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/*$##')"
    fi

    if [ -z "${ENABLE_HTTPS:-}" ] && [ -n "${DOMAIN:-}" ] \
        && [ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        ENABLE_HTTPS="yes"
    fi
}

escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"
}

[ "$(id -u)" -eq 0 ] || {
    echo "Run as root / Execute como root." >&2
    exit 1
}

load_install_state
load_existing_dashboard_values
choose_language

MODULE_COUNT="${MODULE_COUNT:-5}"
if [[ ! "$MODULE_COUNT" =~ ^[0-9]+$ ]] || [ "$MODULE_COUNT" -lt 1 ] || [ "$MODULE_COUNT" -gt 26 ]; then
    echo "ERROR / ERRO: invalid XLXD module count / quantidade de módulos XLXD inválida: $MODULE_COUNT" >&2
    exit 2
fi

printf 'Dashboard language / Idioma do painel: %s (%s)\n' "$(language_name "$DASHBOARD_LANG")" "$DASHBOARD_LANG"
printf 'XLXD modules / Módulos XLXD: A-%s (%s)\n\n' "$(module_last_letter "$MODULE_COUNT")" "$MODULE_COUNT"

reuse_or_ask REFLECTOR_NAME reflector
reuse_or_ask REFLECTOR_TITLE title
reuse_or_ask REFLECTOR_DESCRIPTION description
reuse_or_ask SYSOP_CALLSIGN sysop
reuse_or_ask LOCATION location
reuse_or_ask COUNTRY country
reuse_or_ask DOMAIN domain
reuse_or_ask CONTACT_EMAIL email

case "${ENABLE_HTTPS:-}" in
    Y|y|yes|YES|s|sim) ENABLE_HTTPS="yes"; printf 'HTTPS: ativado [reaproveitado]\n' ;;
    N|n|no|NO|nao|não) ENABLE_HTTPS="no"; printf 'HTTPS: não ativado [reaproveitado]\n' ;;
    *)
        while :; do
            read -r -p "Ativar HTTPS com certificado Let's Encrypt? / Enable HTTPS with a Let's Encrypt certificate? [S/n]: " HTTPS_ANSWER
            case "${HTTPS_ANSWER,,}" in
                ""|s|sim|y|yes) ENABLE_HTTPS="yes"; break ;;
                n|nao|não|no) ENABLE_HTTPS="no"; break ;;
                *) echo "Resposta inválida / Invalid answer. Use S ou N / Y or N." ;;
            esac
        done
        ;;
esac

REFLECTOR_NAME="$(printf '%s' "$REFLECTOR_NAME" | tr '[:lower:]' '[:upper:]')"

if [[ ! "$REFLECTOR_NAME" =~ ^XLX([0-9]{3})$ ]]; then
    echo "ERROR / ERRO: reflector identifier must use XLX + 3 digits, example XLX026." >&2
    exit 2
fi

REFLECTOR_NUMBER="${BASH_REMATCH[1]}"
REFLECTOR_SHORT_NUMBER="$((10#$REFLECTOR_NUMBER))"

DOMAIN="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/*$##')"
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; then
    echo "ERROR / ERRO: domínio inválido: $DOMAIN" >&2
    exit 2
fi

if [ -n "${YSF_ID:-}" ]; then
    if [[ ! "$YSF_ID" =~ ^[0-9]{1,8}$ ]]; then
        echo "ERROR / ERRO: Invalid YSF ID / ID YSF inválido: $YSF_ID" >&2
        exit 2
    fi
    printf 'YSF reflector ID / ID do refletor YSF: %s [reaproveitado]\n' "$YSF_ID"
else
    while :; do
        read -r -p "YSF reflector ID / ID do refletor YSF: " YSF_ID
        if [[ "$YSF_ID" =~ ^[0-9]{1,8}$ ]]; then
            break
        fi
        echo "Invalid YSF ID / ID YSF inválido."
    done
fi

# XLXD uses the standard DMR module mapping: A=4001, B=4002,
# C=4003 and so on. Voice traffic uses TG 6, so no individual TG needs
# to be requested from the sysop for the dashboard.
DMR_TG="6"

if [ -e "$DEST" ]; then
    stamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUPS"
    tar -C "$(dirname "$DEST")" -czpf "$BACKUPS/dashboard-$stamp.tar.gz" "$(basename "$DEST")"
    printf 'Backup: %s\n' "$BACKUPS/dashboard-$stamp.tar.gz"
fi

mkdir -p "$DEST"
rsync -a --delete --exclude='install/' --exclude='config/site.php' "$ROOT/" "$DEST/"
mkdir -p "$DEST/config"

# Every installed reflector receives its own neutral logo. This avoids the
# broken XLX026-specific image reference on a fresh installation.
cat > "$DEST/assets/logo-$REFLECTOR_NAME.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" role="img" aria-label="$REFLECTOR_NAME">
  <defs><radialGradient id="g" cx="35%" cy="25%"><stop stop-color="#12d8ff"/><stop offset="1" stop-color="#062433"/></radialGradient></defs>
  <circle cx="80" cy="80" r="74" fill="#04131c" stroke="#00d8ff" stroke-width="4"/>
  <circle cx="80" cy="80" r="63" fill="url(#g)" opacity=".32"/>
  <path d="M45 69h70M55 89h50" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity=".85"/>
  <text x="80" y="119" text-anchor="middle" fill="#fff" font-family="Arial,sans-serif" font-size="22" font-weight="700">$REFLECTOR_NAME</text>
</svg>
SVG
chown www-data:www-data "$DEST/assets/logo-$REFLECTOR_NAME.svg"
chmod 0644 "$DEST/assets/logo-$REFLECTOR_NAME.svg"

# Runtime cache directories used by status.php and ham-weather.php.
# Fresh installations must provision them before Apache serves the dashboard.
install -d -m 0750 -o www-data -g www-data /var/cache/xlx-dashboard
install -d -m 0750 -o www-data -g www-data /var/cache/xlx-ham-weather

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
  'show_contact_email'=>true,
  'show_location'=>true,'show_sysop_callsign'=>true,
 ],
 'radio'=>[
  'reflector_number'=>'$(escape "$REFLECTOR_NUMBER")',
  'reflector_short_number'=>'$(escape "$REFLECTOR_SHORT_NUMBER")',
  'module_count'=>$(escape "$MODULE_COUNT"),
  'ysf_id'=>'$(escape "$YSF_ID")',
  'dmr_tg'=>'$(escape "$DMR_TG")',
 ],
 'locale'=>[
  'default'=>'$(escape "$DASHBOARD_LANG")',
 ],
];
PHP

if [ ! -f "$DEST/i18n/build.php" ]; then
    echo "ERROR / ERRO: i18n builder not found: $DEST/i18n/build.php" >&2
    exit 1
fi

php "$DEST/i18n/build.php" "$DEST" "$DASHBOARD_LANG"

# install/ is intentionally excluded from the deployed web root. Execute the
# renderer from the source tree against the copied destination.
if [ ! -f "$ROOT/install/render-placeholders.php" ]; then
    echo "ERROR / ERRO: placeholder renderer not found: $ROOT/install/render-placeholders.php" >&2
    exit 1
fi

php "$ROOT/install/render-placeholders.php" "$DEST"

find "$DEST" -type d -exec chmod 755 {} \;
find "$DEST" -type f -exec chmod 644 {} \;
chown -R root:www-data "$DEST"
chmod 640 "$DEST/config/site.php"

find "$DEST" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null

APACHE_LOG_DIR="${APACHE_LOG_DIR:-/var/log/apache2}"
VHOST="/etc/apache2/sites-available/$DOMAIN.conf"
cat > "$VHOST" <<APACHE
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $DEST
    <Directory $DEST>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog ${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
APACHE

a2ensite "$DOMAIN.conf" >/dev/null
a2dissite 000-default >/dev/null 2>&1 || true

# Set Apache's global identity as well as the virtual host identity. This avoids
# AH00558 on clean Debian installations without modifying Debian's defaults.
SERVERNAME_CONF="/etc/apache2/conf-available/xlx-modern-servername.conf"
printf 'ServerName %s\n' "$DOMAIN" > "$SERVERNAME_CONF"
a2enconf xlx-modern-servername >/dev/null

apache2ctl configtest
systemctl enable --now apache2

if [ "$ENABLE_HTTPS" = "yes" ]; then
    if [ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] \
        && [ -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        printf 'HTTPS certificate already present / certificado HTTPS já existente: %s\n' "$DOMAIN"
    else
        certbot --apache --non-interactive --agree-tos --email "$CONTACT_EMAIL" -d "$DOMAIN" \
            || { echo "ERROR / ERRO: não foi possível emitir o certificado HTTPS. Confirme que o DNS de $DOMAIN aponta para esta VPS e que as portas 80/443 estão liberadas." >&2; exit 1; }
    fi
fi

# CallingHome is required for publication in the public XLX directory. The
# upstream implementation lived inside the legacy dashboard; install it here
# as a dedicated, non-web service so the Modern Dashboard remains standalone.
CALLINGHOME_DIR="/etc/xlx-modern"
CALLINGHOME_CONFIG="$CALLINGHOME_DIR/callinghome.php"
install -d -m 0750 -o root -g www-data "$CALLINGHOME_DIR"

CALLINGHOME_HASH="$(php -r '
    $file = $argv[1];
    if (is_file($file)) {
        $value = require $file;
        if (is_array($value) && isset($value["hash"])) {
            echo (string)$value["hash"];
        }
    }
' "$CALLINGHOME_CONFIG")"
if [[ ! "$CALLINGHOME_HASH" =~ ^[a-f0-9]{32,128}$ ]]; then
    CALLINGHOME_HASH="$(php -r 'echo bin2hex(random_bytes(16));')"
fi

CALLINGHOME_SCHEME="http"
[ "$ENABLE_HTTPS" = "yes" ] && CALLINGHOME_SCHEME="https"
CALLINGHOME_COMMENT="${REFLECTOR_DESCRIPTION:0:100}"

cat > "$CALLINGHOME_CONFIG" <<PHP
<?php
declare(strict_types=1);
return [
    'reflector_name' => '$(escape "$REFLECTOR_NAME")',
    'dashboard_url' => '$(escape "$CALLINGHOME_SCHEME://$DOMAIN")',
    'country' => '$(escape "$COUNTRY")',
    'comment' => '$(escape "$CALLINGHOME_COMMENT")',
    'hash' => '$(escape "$CALLINGHOME_HASH")',
    'server_url' => 'http://xlxapi.rlx.lu/api.php',
    'xml_path' => '/var/log/xlxd.xml',
    'interlink_path' => '/xlxd/xlxd.interlink',
];
PHP
chown root:www-data "$CALLINGHOME_CONFIG"
chmod 0640 "$CALLINGHOME_CONFIG"

install -d -m 0755 -o root -g root /usr/local/lib/xlx-modern
install -m 0755 "$ROOT/install/xlx-callinghome.php" /usr/local/lib/xlx-modern/xlx-callinghome.php
install -m 0644 "$ROOT/install/xlx-callinghome.service" /etc/systemd/system/xlx-callinghome.service
install -m 0644 "$ROOT/install/xlx-callinghome.timer" /etc/systemd/system/xlx-callinghome.timer
systemctl daemon-reload
systemctl enable --now xlx-callinghome.timer

if systemctl start xlx-callinghome.service; then
    printf 'CallingHome: registration submitted successfully.\n'
else
    printf 'WARNING / ATENÇÃO: CallingHome could not be confirmed now; the timer will retry every five minutes. Check: journalctl -u xlx-callinghome.service -n 30 --no-pager\n' >&2
fi

printf '\nXLX Modern Dashboard installed / instalado em: %s\n' "$DEST"
printf 'Language / Idioma: %s (%s)\n' "$(language_name "$DASHBOARD_LANG")" "$DASHBOARD_LANG"
printf 'Translation report / Relatório: %s\n' "$DEST/config/i18n-build-report.json"
