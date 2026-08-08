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

escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"
}

[ "$(id -u)" -eq 0 ] || {
    echo "Run as root / Execute como root." >&2
    exit 1
}

choose_language
printf 'Dashboard language / Idioma do painel: %s (%s)\n\n' "$(language_name "$DASHBOARD_LANG")" "$DASHBOARD_LANG"

ask REFLECTOR_NAME reflector
ask REFLECTOR_TITLE title
ask REFLECTOR_DESCRIPTION description
ask SYSOP_CALLSIGN sysop
ask LOCATION location
ask COUNTRY country
ask DOMAIN domain
ask CONTACT_EMAIL email

REFLECTOR_NAME="$(printf '%s' "$REFLECTOR_NAME" | tr '[:lower:]' '[:upper:]')"

if [[ ! "$REFLECTOR_NAME" =~ ^XLX([0-9]{3})$ ]]; then
    echo "ERROR / ERRO: reflector identifier must use XLX + 3 digits, example XLX026." >&2
    exit 2
fi

REFLECTOR_NUMBER="${BASH_REMATCH[1]}"
REFLECTOR_SHORT_NUMBER="$((10#$REFLECTOR_NUMBER))"

DOMAIN="$(printf '%s' "$DOMAIN" | sed -E 's#^https?://##; s#/*$##')"

while :; do
    read -r -p "YSF reflector ID / ID do refletor YSF: " YSF_ID

    if [[ "$YSF_ID" =~ ^[0-9]{1,8}$ ]]; then
        break
    fi

    echo "Invalid YSF ID / ID YSF inválido."
done

while :; do
    read -r -p "DMR TalkGroup / TG DMR: " DMR_TG

    if [[ "$DMR_TG" =~ ^[0-9]{1,8}$ ]]; then
        break
    fi

    echo "Invalid DMR TG / TG DMR inválido."
done

if [ -e "$DEST" ]; then
    stamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUPS"
    tar -C "$(dirname "$DEST")" -czpf "$BACKUPS/dashboard-$stamp.tar.gz" "$(basename "$DEST")"
    printf 'Backup: %s\n' "$BACKUPS/dashboard-$stamp.tar.gz"
fi

mkdir -p "$DEST"
rsync -a --delete --exclude='install/' --exclude='config/site.php' "$ROOT/" "$DEST/"
mkdir -p "$DEST/config"

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

printf '\nXLX Modern Dashboard installed / instalado em: %s\n' "$DEST"
printf 'Language / Idioma: %s (%s)\n' "$(language_name "$DASHBOARD_LANG")" "$DASHBOARD_LANG"
printf 'Translation report / Relatório: %s\n' "$DEST/config/i18n-build-report.json"
