#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${INSTALL_DIR:-/var/www/html/xlxd}"
BACKUPS="${BACKUP_ROOT:-/var/backups/xlx-reflector}"
DASHBOARD_LANG="${DASHBOARD_LANG:-}"
PROJECT_VERSION="$(cat "$ROOT/../VERSION" 2>/dev/null || printf 'unknown')"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
case "$UI_LANG" in pt-BR|en) ;; *) UI_LANG="pt-BR" ;; esac

ui() {
    local pt="$1" en="$2"
    if [ "$UI_LANG" = "en" ]; then printf '%s' "$en"; else printf '%s' "$pt"; fi
}

for arg in "$@"; do
    case "$arg" in
        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;
        -h|--help)
            if [ "$UI_LANG" = "en" ]; then
                cat <<'HELP_EN'
XLX Modern Dashboard Installer

Usage:
  sudo bash install-dashboard.sh
  sudo bash install-dashboard.sh --lang=en

Supported dashboard languages:
  pt-BR  Portuguese (Brazil)
  en     English
  es     Spanish
  fr     French
  de     German
  it     Italian
HELP_EN
            else
                cat <<'HELP_PT'
Instalador do Painel XLX Modern

Uso:
  sudo bash install-dashboard.sh
  sudo bash install-dashboard.sh --lang=pt-BR

Idiomas disponíveis para o painel:
  pt-BR  Português (Brasil)
  en     Inglês
  es     Espanhol
  fr     Francês
  de     Alemão
  it     Italiano
HELP_PT
            fi
            exit 0
            ;;
        *) echo "$(ui "ERRO: opção desconhecida: $arg" "ERROR: unknown option: $arg")" >&2; exit 2 ;;
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
            echo "$(ui "ERRO: idioma do painel não suportado: $DASHBOARD_LANG" "ERROR: unsupported dashboard language: $DASHBOARD_LANG")" >&2
            exit 2
        }
        DASHBOARD_LANG="$normalized"
        return
    fi

    printf '\n============================================================\n %s\n============================================================\n' "$(ui 'Idioma do Painel' 'Dashboard Language')"
    printf '%s\n' \
        '  1) Português (Brasil)' \
        '  2) English' \
        '  3) Español' \
        '  4) Français' \
        '  5) Deutsch' \
        '  6) Italiano'

    while :; do
        read -r -p "$(ui 'Escolha [1-6]: ' 'Choose [1-6]: ')" answer
        case "$answer" in
            1) DASHBOARD_LANG='pt-BR'; break ;;
            2) DASHBOARD_LANG='en'; break ;;
            3) DASHBOARD_LANG='es'; break ;;
            4) DASHBOARD_LANG='fr'; break ;;
            5) DASHBOARD_LANG='de'; break ;;
            6) DASHBOARD_LANG='it'; break ;;
            *) echo "$(ui 'Opção inválida.' 'Invalid option.')" ;;
        esac
    done
}

prompt_text() {
    local key="$1"
    case "$UI_LANG:$key" in
        pt-BR:reflector) printf '%s' 'Identificação do refletor' ;;
        pt-BR:title) printf '%s' 'Nome exibido' ;;
        pt-BR:description) printf '%s' 'Descrição curta' ;;
        pt-BR:sysop) printf '%s' 'Indicativo do responsável' ;;
        pt-BR:location) printf '%s' 'Cidade e estado/região' ;;
        pt-BR:country) printf '%s' 'País' ;;
        pt-BR:domain) printf '%s' 'Domínio' ;;
        pt-BR:email) printf '%s' 'E-mail de contato' ;;
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
        printf '%s: %s [%s]\n' "$(prompt_text "$label_key")" "$value" "$(ui 'reaproveitado' 'reused')"
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
    [ -f "$file" ] || { echo "$(ui "ERRO: dados iniciais não encontrados: $file" "ERROR: initial data not found: $file")" >&2; exit 1; }
    # This file is created by the root-owned base installer using printf %q.
    # It is read only by this same root installation process.
    # shellcheck disable=SC1090
    source "$file"
    printf '%s\n\n' "$(ui 'Dados já informados serão reaproveitados.' 'Previously supplied data will be reused.')"
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
    [ -n "${TIMEZONE:-}" ] || TIMEZONE="$(dashboard_site_value timezone)"
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
    echo "$(ui "Execute como root." "Run as root.")" >&2
    exit 1
}

load_install_state
load_existing_dashboard_values
choose_language

MODULE_COUNT="${MODULE_COUNT:-5}"
TIMEZONE="${TIMEZONE:-UTC}"
if [[ ! "$MODULE_COUNT" =~ ^[0-9]+$ ]] || [ "$MODULE_COUNT" -lt 1 ] || [ "$MODULE_COUNT" -gt 26 ]; then
    echo "$(ui "ERRO: quantidade de módulos XLXD inválida: $MODULE_COUNT" "ERROR: invalid XLXD module count: $MODULE_COUNT")" >&2
    exit 2
fi

printf '%s: %s (%s)\n' "$(ui 'Idioma do painel' 'Dashboard language')" "$(language_name "$DASHBOARD_LANG")" "$DASHBOARD_LANG"
printf '%s: A-%s (%s)\n\n' "$(ui 'Módulos XLXD' 'XLXD modules')" "$(module_last_letter "$MODULE_COUNT")" "$MODULE_COUNT"

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
            read -r -p "$(ui "Ativar HTTPS com certificado Let's Encrypt? [S/n]: " "Enable HTTPS with a Let's Encrypt certificate? [Y/n]: ")" HTTPS_ANSWER
            case "${HTTPS_ANSWER,,}" in
                ""|s|sim|y|yes) ENABLE_HTTPS="yes"; break ;;
                n|nao|não|no) ENABLE_HTTPS="no"; break ;;
                *) echo "$(ui "Resposta inválida. Use S ou N." "Invalid answer. Use Y or N.")" ;;
            esac
        done
        ;;
esac

REFLECTOR_NAME="$(printf '%s' "$REFLECTOR_NAME" | tr '[:lower:]' '[:upper:]')"

if [[ ! "$REFLECTOR_NAME" =~ ^XLX([A-Z0-9]{3})$ ]]; then
    echo "$(ui "ERRO: o identificador deve usar XLX + 3 caracteres alfanuméricos (A-Z/0-9), exemplos XLX123 ou XLXPNY." "ERROR: reflector identifier must use XLX + 3 alphanumeric characters (A-Z/0-9), examples XLX123 or XLXPNY.")" >&2
    exit 2
fi

REFLECTOR_NUMBER="${BASH_REMATCH[1]}"
if [[ "$REFLECTOR_NUMBER" =~ ^[0-9]{3}$ ]]; then
    REFLECTOR_SHORT_NUMBER="$((10#$REFLECTOR_NUMBER))"
else
    REFLECTOR_SHORT_NUMBER="$REFLECTOR_NUMBER"
fi

DOMAIN="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/*$##')"
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; then
    echo "$(ui "ERRO: domínio inválido: $DOMAIN" "ERROR: invalid domain: $DOMAIN")" >&2
    exit 2
fi

if [ -n "${YSF_ID:-}" ]; then
    if [[ ! "$YSF_ID" =~ ^[0-9]{1,8}$ ]]; then
        echo "$(ui "ERRO: ID YSF inválido: $YSF_ID" "ERROR: invalid YSF ID: $YSF_ID")" >&2
        exit 2
    fi
    printf '%s: %s [%s]\n' "$(ui 'ID do refletor YSF' 'YSF reflector ID')" "$YSF_ID" "$(ui 'reaproveitado' 'reused')"
else
    while :; do
        read -r -p "$(ui "ID do refletor YSF: " "YSF reflector ID: ")" YSF_ID
        if [[ "$YSF_ID" =~ ^[0-9]{1,8}$ ]]; then
            break
        fi
        echo "$(ui "ID YSF inválido." "Invalid YSF ID.")"
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
rsync -a --delete --exclude='install/' --exclude='native/' --exclude='config/site.php' "$ROOT/" "$DEST/"
mkdir -p "$DEST/config"

# Every installed reflector receives its own neutral logo. This avoids the
# broken production-specific image reference on a fresh installation.
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
 'timezone'=>'$(escape "$TIMEZONE")',
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
  'aprs_service_callsign'=>'$(escape "${SYSOP_CALLSIGN}-10")',
 ],
 'locale'=>[
  'default'=>'$(escape "$DASHBOARD_LANG")',
 ],
 'software'=>[
  'version'=>'$(escape "$PROJECT_VERSION")',
 ],
];
PHP

if [ ! -f "$DEST/i18n/build.php" ]; then
    echo "$(ui "ERRO: construtor i18n não encontrado: $DEST/i18n/build.php" "ERROR: i18n builder not found: $DEST/i18n/build.php")" >&2
    exit 1
fi

php "$DEST/i18n/build.php" "$DEST" "$DASHBOARD_LANG"

# install/ is intentionally excluded from the deployed web root. Execute the
# renderer from the source tree against the copied destination.
if [ ! -f "$ROOT/install/render-placeholders.php" ]; then
    echo "$(ui "ERRO: renderizador de placeholders não encontrado: $ROOT/install/render-placeholders.php" "ERROR: placeholder renderer not found: $ROOT/install/render-placeholders.php")" >&2
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

HTTPS_READY=0
HTTPS_STATUS_DIR="/var/lib/xlx-modern"
HTTPS_STATUS_FILE="$HTTPS_STATUS_DIR/https-status"
HTTPS_RETRY="/usr/local/sbin/xlx-modern-https-retry"
LE_LOG="${XLX_LETSENCRYPT_LOG:-/var/log/letsencrypt/letsencrypt.log}"
SYSTEMD_DIR="${XLX_SYSTEMD_DIR:-/etc/systemd/system}"
install -d -o root -g root -m 0755 "$HTTPS_STATUS_DIR"

cat > "$HTTPS_RETRY" <<'HTTPSRETRY'
#!/usr/bin/env bash
set -Eeuo pipefail
DOMAIN="${1:-}"
EMAIL="${2:-}"
LE_LOG="${XLX_LETSENCRYPT_LOG:-/var/log/letsencrypt/letsencrypt.log}"
[[ -n "$DOMAIN" && -n "$EMAIL" ]] || { echo "Usage: xlx-modern-https-retry DOMAIN EMAIL" >&2; exit 2; }
LOG="$(mktemp /tmp/xlx-modern-certbot.XXXXXX.log)"
trap 'rm -f "$LOG"' EXIT
if certbot --apache --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN" 2>&1 | tee "$LOG"; then
    [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]] || { echo "Certbot returned success but certificate files are missing." >&2; exit 3; }
    apache2ctl configtest
    systemctl reload apache2
    install -d -m 0755 /var/lib/xlx-modern
    printf 'HTTPS_OK domain=%s\n' "$DOMAIN" > /var/lib/xlx-modern/https-status
    if systemctl list-unit-files xlx-modern-https-retry.timer --no-legend 2>/dev/null | grep -q .; then
        systemctl disable --now xlx-modern-https-retry.timer >/dev/null 2>&1 || true
    fi
    echo "HTTPS_OK domain=$DOMAIN"
    exit 0
fi
rc=${PIPESTATUS[0]}
echo "HTTPS_FAILED rc=$rc" >&2
if grep -Fq "AttributeError: can't set attribute" "$LOG"; then
    echo "Debian 12 Certbot 2.1.x masked the ACME error with a known Python 3.11 bug." >&2
fi
if [[ -f $LE_LOG ]]; then
    echo "Last relevant Let's Encrypt diagnostics:" >&2
    grep -Ei 'too many|rate.?limit|unauthor|invalid|nxdomain|timeout|connection|error creating new order|detail:|failed authorization|acme:error' $LE_LOG | tail -n 12 >&2 || true
fi
exit "$rc"
HTTPSRETRY
chmod 0755 "$HTTPS_RETRY"

schedule_https_rate_limit_retry() {
    local retry_raw retry_at service timer
    retry_raw="$(grep -Eio 'retry after [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC' $LE_LOG 2>/dev/null | tail -n 1 | sed -E 's/^retry after //I' || true)"
    [[ -n "$retry_raw" ]] || return 1
    retry_at="$(date -u -d "$retry_raw + 10 minutes" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || true)"
    [[ -n "$retry_at" ]] || return 1
    service="$SYSTEMD_DIR/xlx-modern-https-retry.service"
    timer="$SYSTEMD_DIR/xlx-modern-https-retry.timer"
    cat > "$service" <<UNIT
[Unit]
Description=XLX Modern automatic HTTPS retry
After=network-online.target apache2.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$HTTPS_RETRY $DOMAIN $CONTACT_EMAIL
UNIT
    cat > "$timer" <<UNIT
[Unit]
Description=Retry XLX Modern HTTPS after Let's Encrypt rate limit

[Timer]
OnCalendar=$retry_at
Persistent=true
AccuracySec=1min
RandomizedDelaySec=2min
Unit=xlx-modern-https-retry.service

[Install]
WantedBy=timers.target
UNIT
    chmod 0644 "$service" "$timer"
    if [[ "${XLX_HTTPS_RETRY_TEST_MODE:-0}" != "1" ]]; then
        systemctl daemon-reload
        systemctl enable --now xlx-modern-https-retry.timer >/dev/null
    fi
    {
        printf 'HTTPS_PENDING domain=%s\n' "$DOMAIN"
        printf 'reason=letsencrypt_rate_limit\n'
        printf 'retry_at_utc=%s\n' "$retry_at"
        printf 'retry_timer=xlx-modern-https-retry.timer\n'
    } > "$HTTPS_STATUS_FILE"
    printf '[INFO] Automatic HTTPS retry scheduled for %s.\n' "$retry_at" >&2
    printf '[INFO] Nova tentativa automática de HTTPS agendada para %s.\n' "$retry_at" >&2
    return 0
}

https_backoff_active() {
    local retry_raw retry_epoch now_epoch
    HTTPS_PENDING_RETRY_AT=""
    [[ -f "$HTTPS_STATUS_FILE" ]] || return 1
    retry_raw="$(sed -n 's/^retry_at_utc=//p' "$HTTPS_STATUS_FILE" | tail -n 1)"
    [[ -n "$retry_raw" ]] || return 1
    retry_epoch="$(date -u -d "$retry_raw" '+%s' 2>/dev/null || true)"
    now_epoch="$(date -u '+%s')"
    [[ "$retry_epoch" =~ ^[0-9]+$ ]] || return 1
    (( now_epoch < retry_epoch )) || return 1
    HTTPS_PENDING_RETRY_AT="$retry_raw"
    return 0
}

if [ "$ENABLE_HTTPS" = "yes" ]; then
    if [ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] \
        && [ -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        printf '%s: %s\n' "$(ui 'Certificado HTTPS já existente' 'HTTPS certificate already present')" "$DOMAIN"
        HTTPS_READY=1
    elif https_backoff_active; then
        printf '[INFO] HTTPS retry already scheduled for %s; skipping Certbot until the backoff expires.\n' "$HTTPS_PENDING_RETRY_AT" >&2
        printf '[INFO] Nova tentativa HTTPS já agendada para %s; Certbot não será executado antes do fim do bloqueio.\n' "$HTTPS_PENDING_RETRY_AT" >&2
        if [[ "${XLX_HTTPS_RETRY_TEST_MODE:-0}" != "1" ]] \
            && systemctl list-unit-files xlx-modern-https-retry.timer --no-legend 2>/dev/null | grep -q .; then
            systemctl enable --now xlx-modern-https-retry.timer >/dev/null 2>&1 || true
        fi
    else
        CERTBOT_LOG="$(mktemp /tmp/xlx-modern-certbot.XXXXXX.log)"
        set +e
        certbot --apache --non-interactive --agree-tos --email "$CONTACT_EMAIL" -d "$DOMAIN" 2>&1 | tee "$CERTBOT_LOG"
        CERTBOT_RC=${PIPESTATUS[0]}
        set -e
        if [ "$CERTBOT_RC" -eq 0 ] \
            && [ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] \
            && [ -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
            HTTPS_READY=1
            printf 'HTTPS_OK domain=%s\n' "$DOMAIN" > "$HTTPS_STATUS_FILE"
            printf '[OK] %s: %s\n' "$(ui 'HTTPS ativado' 'HTTPS enabled')" "$DOMAIN"
        else
            {
                printf 'HTTPS_PENDING domain=%s rc=%s\n' "$DOMAIN" "$CERTBOT_RC"
                if grep -Fq "AttributeError: can't set attribute" "$CERTBOT_LOG"; then
                    printf 'reason=debian12_certbot_2.1_acme_error_masked\n'
                fi
            } > "$HTTPS_STATUS_FILE"
            printf '%s %s\n' "$(ui '[ATENÇÃO]' '[WARNING]')" "$(ui 'O certificado HTTPS não pôde ser emitido agora; a instalação continuará em HTTP.' 'HTTPS certificate could not be issued now; installation will continue over HTTP.')" >&2
            if grep -Fq "AttributeError: can't set attribute" "$CERTBOT_LOG"; then
                printf '%s %s\n' "$(ui '[ATENÇÃO]' '[WARNING]')" "$(ui 'O Certbot 2.1.x do Debian 12 encontrou o erro conhecido do Python 3.11 ao reportar uma falha ACME.' 'Debian 12 Certbot 2.1.x hit its known Python 3.11 error while reporting an ACME failure.')" >&2
            fi
            if [[ -f $LE_LOG ]]; then
                printf '%s\n' "--- Let's Encrypt diagnostics ---" >&2
                grep -Ei 'too many|rate.?limit|unauthor|invalid|nxdomain|timeout|connection|error creating new order|detail:|failed authorization|acme:error' $LE_LOG | tail -n 12 >&2 || true
            fi
            if grep -Eqi 'rate.?limit|too many certificates|retry after' $LE_LOG 2>/dev/null; then
                schedule_https_rate_limit_retry || printf '[WARNING] Rate limit detected but automatic retry could not be scheduled.\n' >&2
            fi
            printf '[INFO] %s: %s %q %q\n' "$(ui 'Tentativa manual' 'Manual retry')" "$HTTPS_RETRY" "$DOMAIN" "$CONTACT_EMAIL" >&2
        fi
        rm -f "$CERTBOT_LOG"
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
# Upstream XLXD uses CreateCode(16): a persistent 16-character alphanumeric
# ownership token. Preserve any already-issued alphanumeric token on upgrades,
# but generate new installations in the exact upstream format.
if [[ ! "$CALLINGHOME_HASH" =~ ^[A-Za-z0-9]{16,128}$ ]]; then
    CALLINGHOME_HASH="$(php -r '$chars="1234567890abcdefghijklmnopqrstuvwyxzABCDEFGHIJKLMNAOPQRSTUVWYXZ"; for($i=0;$i<16;$i++){echo $chars[random_int(0,strlen($chars)-1)];}')"
fi

CALLINGHOME_SCHEME="http"
[ "$HTTPS_READY" -eq 1 ] && CALLINGHOME_SCHEME="https"
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
    printf 'WARNING / ATENÇÃO: CallingHome could not be confirmed now; the timer will retry every ten minutes. Check: journalctl -u xlx-callinghome.service -n 30 --no-pager\n' >&2
fi

printf '\nXLX Modern Dashboard installed / instalado em: %s\n' "$DEST"
printf 'Language / Idioma: %s (%s)\n' "$(language_name "$DASHBOARD_LANG")" "$DASHBOARD_LANG"
printf 'Translation report / Relatório: %s\n' "$DEST/config/i18n-build-report.json"
