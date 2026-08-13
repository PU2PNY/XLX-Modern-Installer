#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

readonly CERT_REPOSITORY="PU2PNY/XLX-Certificate-Generator"
readonly CERT_COMMIT="30722407eb2bd98adab7a67a7bb74ae83859e0e9"
readonly CERT_INSTALLER_SHA256="7a1e3d6420a590ce24be5774e92cb115dbdf150fb6d0bc53690379360c9363a8"
readonly CERT_MANIFEST_SHA256="705224e997a7cabecaf7e9e8bcb2683484ea4db43364b17bbacf176df204e44c"
readonly VENDOR_ROOT="/opt/xlx-modern-installer/vendor/xlx-certificate-generator"

MODE="install"
DASHBOARD="${XLX_DASHBOARD_DIR:-/var/www/html/xlx-dashboard}"
SITE_CONFIG=""
DATA_DIR="${XLX_CERT_DATA_DIR:-}"
SECRET_FILE="${XLX_CERT_SECRET_FILE:-}"
CAMPAIGN_PACK="${XLX_CERT_CAMPAIGN_PACK:-auto}"
SOURCE=""
TEMP_DIR=""

cleanup(){
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        --dashboard-dir=*) DASHBOARD="${arg#*=}" ;;
        --site-config=*) SITE_CONFIG="${arg#*=}" ;;
        --data-dir=*) DATA_DIR="${arg#*=}" ;;
        --secret-file=*) SECRET_FILE="${arg#*=}" ;;
        --campaign-pack=*) CAMPAIGN_PACK="${arg#*=}" ;;
        -h|--help)
            cat <<'HELP'
XLX Modern — módulo opcional XLX Certificate Generator

Uso:
  sudo bash modules/66-certificates.sh --check
  sudo bash modules/66-certificates.sh --dashboard-dir=/var/www/html/xlx-dashboard

O módulo baixa um commit fixado do repositório XLX-Certificate-Generator,
valida SHA-256, manifesto e sintaxe e somente então chama o instalador
independente. Dados, certificados emitidos e segredo HMAC não fazem parte
do repositório público.
HELP
            exit 0
            ;;
        *) fatal "Opção desconhecida: $arg" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fatal "Execute como root."
for cmd in bash curl find mktemp sha256sum tar; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "Comando obrigatório ausente: $cmd"
done

validate_archive_paths(){
    local archive="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$archive" <<'PY'
import sys, tarfile
p=sys.argv[1]
with tarfile.open(p, 'r:gz') as tf:
    for m in tf.getmembers():
        name=m.name
        parts=[x for x in name.split('/') if x not in ('', '.')]
        if name.startswith('/') or any(x == '..' for x in parts):
            raise SystemExit(f'unsafe archive path: {name}')
        if m.issym() or m.islnk():
            link=m.linkname
            link_parts=[x for x in link.split('/') if x not in ('', '.')]
            if link.startswith('/') or any(x == '..' for x in link_parts):
                raise SystemExit(f'unsafe archive link: {name} -> {link}')
PY
        return
    fi
    if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        fatal "Arquivo de Certificados contém caminho inseguro."
    fi
    warn "Python ainda não está disponível; validação avançada de links foi adiada."
}

validate_source(){
    local source="$1" actual
    [ -f "$source/install.sh" ] || fatal "install.sh ausente no XLX Certificate Generator."
    [ -f "$source/MANIFEST.sha256" ] || fatal "MANIFEST.sha256 ausente."

    actual="$(sha256sum "$source/install.sh" | awk '{print $1}')"
    [ "$actual" = "$CERT_INSTALLER_SHA256" ] || fatal "SHA-256 do install.sh divergente. Esperado=$CERT_INSTALLER_SHA256 Obtido=$actual"

    actual="$(sha256sum "$source/MANIFEST.sha256" | awk '{print $1}')"
    [ "$actual" = "$CERT_MANIFEST_SHA256" ] || fatal "SHA-256 do manifesto divergente. Esperado=$CERT_MANIFEST_SHA256 Obtido=$actual"

    (
        cd "$source"
        sha256sum -c MANIFEST.sha256 >/dev/null
    ) || fatal "Manifesto do XLX Certificate Generator não confere."

    while IFS= read -r -d '' file; do bash -n "$file"; done < <(find "$source" -type f -name '*.sh' -print0)
    if command -v php >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do php -l "$file" >/dev/null; done < <(find "$source" -type f -name '*.php' -print0)
    elif [ "$MODE" = "install" ]; then
        fatal "PHP ainda não está disponível para instalar Certificados."
    else
        warn "PHP ainda não está disponível; lint PHP será repetido na instalação real."
    fi
    if command -v node >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do node --check "$file" >/dev/null; done < <(find "$source/web/assets" -type f -name '*.js' ! -path '*/vendor/*' -print0)
    fi

    ok "XLX Certificate Generator validado no nível disponível neste host."
    info "Commit fixado: $CERT_COMMIT"
    info "SHA-256 install.sh: $CERT_INSTALLER_SHA256"
}

prepare_source(){
    local final="$VENDOR_ROOT/$CERT_COMMIT" archive url
    if [ -d "$final" ]; then
        validate_source "$final"
        SOURCE="$final"
        return
    fi

    TEMP_DIR="$(mktemp -d /opt/xlx-certificate-generator-fetch.XXXXXX)"
    archive="$TEMP_DIR/source.tar.gz"
    url="https://github.com/${CERT_REPOSITORY}/archive/${CERT_COMMIT}.tar.gz"

    info "Baixando XLX Certificate Generator do commit revisado..."
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
        --connect-timeout 10 --max-time 120 "$url" -o "$archive"
    [ -s "$archive" ] || fatal "Arquivo do XLX Certificate Generator vazio."

    validate_archive_paths "$archive"
    mkdir -p "$TEMP_DIR/source"
    tar -xzf "$archive" --strip-components=1 -C "$TEMP_DIR/source"
    validate_source "$TEMP_DIR/source"

    mkdir -p "$VENDOR_ROOT"
    chmod 700 "$VENDOR_ROOT"
    mv "$TEMP_DIR/source" "$final"
    chmod -R go-rwx "$final"
    rm -rf -- "$TEMP_DIR"
    TEMP_DIR=""
    SOURCE="$final"
}

prepare_source

if [ "$MODE" = "check" ]; then
    if [ -d "$DASHBOARD" ] && [ -f "$DASHBOARD/config/site.php" ]; then
        info "Dashboard existente detectado; validando compatibilidade sem alterar."
        bash "$SOURCE/install.sh" --check --dashboard-dir="$DASHBOARD" --site-config="${SITE_CONFIG:-$DASHBOARD/config/site.php}" --campaign-pack="$CAMPAIGN_PACK"
    else
        info "Dashboard ainda não existe; pré-validação limitada ao código-fonte pinado."
    fi
    ok "Pré-validação de Certificados concluída; nenhuma instalação executada."
    exit 0
fi

[ -d "$DASHBOARD" ] || fatal "Dashboard não encontrado: $DASHBOARD"
[ -f "$DASHBOARD/index.php" ] || fatal "Dashboard incompatível: index.php ausente."
[ -n "$SITE_CONFIG" ] || SITE_CONFIG="$DASHBOARD/config/site.php"
[ -f "$SITE_CONFIG" ] || fatal "Configuração universal ausente: $SITE_CONFIG"

a=(--apply "--dashboard-dir=$DASHBOARD" "--site-config=$SITE_CONFIG" "--campaign-pack=$CAMPAIGN_PACK" --trusted-parent)
[ -z "$DATA_DIR" ] || a+=("--data-dir=$DATA_DIR")
[ -z "$SECRET_FILE" ] || a+=("--secret-file=$SECRET_FILE")

info "Iniciando instalador independente XLX Certificate Generator."
XLX_CERTIFICATES_TRUSTED_PARENT=1 bash "$SOURCE/install.sh" "${a[@]}"
ok "Integração do XLX Certificate Generator concluída."
