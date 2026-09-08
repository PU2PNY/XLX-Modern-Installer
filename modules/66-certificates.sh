#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s%s%s %s\n' "$YELLOW" "$(say '[ATENÇÃO]' '[WARNING]')" "$RESET" "$*"; }
fatal(){ printf '%s%s%s %s\n' "$RED" "$(say '[ERRO]' '[ERROR]')" "$RESET" "$*" >&2; exit 1; }

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CERT_HOOK_SCRIPT="$PROJECT_ROOT/dashboard/install/ensure-certificate-hook.py"
readonly CERT_REPOSITORY="PU2PNY/XLX-Certificate-Generator"
readonly CERT_COMMIT="b01d1e9b443238f8e45763377dfbf2649f328c3f"
readonly CERT_INSTALLER_SHA256="7a1e3d6420a590ce24be5774e92cb115dbdf150fb6d0bc53690379360c9363a8"
readonly CERT_MANIFEST_SHA256="015b7a2dd0815c2ec530b2972088fc8d9b7379eda277e5ab53bc22ff41dd93ea"
readonly VENDOR_ROOT="/opt/xlx-modern-installer/vendor/xlx-certificate-generator"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ if [ "$UI_LANG" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

MODE="install"
DASHBOARD="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
SITE_CONFIG=""
DATA_DIR="${XLX_CERT_DATA_DIR:-}"
SECRET_FILE="${XLX_CERT_SECRET_FILE:-}"
CAMPAIGN_PACK="${XLX_CERT_CAMPAIGN_PACK:-auto}"
SOURCE=""
TEMP_DIR=""
HOOK_BACKUP=""
HOOK_CHANGED=0

cleanup(){
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf -- "$TEMP_DIR"
    fi
    if [ -n "$HOOK_BACKUP" ] && [ -f "$HOOK_BACKUP" ]; then
        rm -f -- "$HOOK_BACKUP"
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
  sudo bash modules/66-certificates.sh --dashboard-dir=/var/www/html/xlxd

O módulo baixa um commit fixado do repositório XLX-Certificate-Generator,
valida SHA-256, manifesto e sintaxe e somente então chama o instalador
independente. Dados, certificados emitidos e segredo HMAC não fazem parte
do repositório público.
HELP
            exit 0
            ;;
        *) fatal "$(say "Opção desconhecida: $arg" "Unknown option: $arg")" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fatal "$(say 'Execute como root.' 'Run as root.')"
for cmd in bash curl find mktemp sha256sum tar; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "$(say "Comando obrigatório ausente: $cmd" "Required command missing: $cmd")"
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
        fatal "$(say 'Arquivo de Certificados contém caminho inseguro.' 'Certificate archive contains an unsafe path.')"
    fi
    warn "$(say 'Python ainda não está disponível; validação avançada de links foi adiada.' 'Python is not available yet; advanced link validation was deferred.')"
}

validate_source(){
    local source="$1" actual
    [ -f "$source/install.sh" ] || fatal "$(say 'install.sh ausente no XLX Certificate Generator.' 'install.sh missing from XLX Certificate Generator.')"
    [ -f "$source/MANIFEST.sha256" ] || fatal "$(say 'MANIFEST.sha256 ausente.' 'MANIFEST.sha256 missing.')"

    actual="$(sha256sum "$source/install.sh" | awk '{print $1}')"
    [ "$actual" = "$CERT_INSTALLER_SHA256" ] || fatal "SHA-256 do install.sh divergente. Esperado=$CERT_INSTALLER_SHA256 Obtido=$actual"

    actual="$(sha256sum "$source/MANIFEST.sha256" | awk '{print $1}')"
    [ "$actual" = "$CERT_MANIFEST_SHA256" ] || fatal "SHA-256 do manifesto divergente. Esperado=$CERT_MANIFEST_SHA256 Obtido=$actual"

    (
        cd "$source"
        sha256sum -c MANIFEST.sha256 >/dev/null
    ) || fatal "$(say 'Manifesto do XLX Certificate Generator não confere.' 'XLX Certificate Generator manifest validation failed.')"

    while IFS= read -r -d '' file; do bash -n "$file"; done < <(find "$source" -type f -name '*.sh' -print0)
    if command -v php >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do php -l "$file" >/dev/null; done < <(find "$source" -type f -name '*.php' -print0)
    elif [ "$MODE" = "install" ]; then
        fatal "$(say 'PHP ainda não está disponível para instalar Certificados.' 'PHP is not available yet to install Certificates.')"
    else
        warn "$(say 'PHP ainda não está disponível; lint PHP será repetido na instalação real.' 'PHP is not available yet; PHP lint will be repeated during the real installation.')"
    fi
    if command -v node >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do node --check "$file" >/dev/null; done < <(find "$source/web/assets" -type f -name '*.js' ! -path '*/vendor/*' -print0)
    fi

    ok "$(say 'XLX Certificate Generator validado no nível disponível neste host.' 'XLX Certificate Generator validated at the level available on this host.')"
    info "$(say "Commit fixado: $CERT_COMMIT" "Pinned commit: $CERT_COMMIT")"
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

    info "$(say 'Baixando XLX Certificate Generator do commit revisado...' 'Downloading XLX Certificate Generator from the reviewed commit...')"
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
        --connect-timeout 10 --max-time 120 "$url" -o "$archive"
    [ -s "$archive" ] || fatal "$(say 'Arquivo do XLX Certificate Generator vazio.' 'XLX Certificate Generator archive is empty.')"

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
        info "$(say 'Dashboard existente detectado; validando compatibilidade sem alterar.' 'Existing dashboard detected; validating compatibility without changes.')"
        bash "$SOURCE/install.sh" --check --dashboard-dir="$DASHBOARD" --site-config="${SITE_CONFIG:-$DASHBOARD/config/site.php}" --campaign-pack="$CAMPAIGN_PACK"
    else
        info "$(say 'Dashboard ainda não existe; pré-validação limitada ao código-fonte pinado.' 'Dashboard does not exist yet; pre-check limited to pinned source code.')"
    fi
    ok "$(say 'Pré-validação de Certificados concluída; nenhuma instalação executada.' 'Certificate pre-check completed; no installation performed.')"
    exit 0
fi

[ -d "$DASHBOARD" ] || fatal "$(say "Dashboard não encontrado: $DASHBOARD" "Dashboard not found: $DASHBOARD")"
[ -f "$DASHBOARD/index.php" ] || fatal "$(say 'Dashboard incompatível: index.php ausente.' 'Incompatible dashboard: index.php is missing.')"
[ -n "$SITE_CONFIG" ] || SITE_CONFIG="$DASHBOARD/config/site.php"
[ -f "$SITE_CONFIG" ] || fatal "$(say "Configuração universal ausente: $SITE_CONFIG" "Universal configuration missing: $SITE_CONFIG")"
[ -f "$CERT_HOOK_SCRIPT" ] || fatal "$(say "Instalador da âncora segura de Certificados ausente: $CERT_HOOK_SCRIPT" "Safe Certificate integration hook missing: $CERT_HOOK_SCRIPT")"
command -v python3 >/dev/null 2>&1 || fatal "$(say 'Python 3 é obrigatório para preparar a integração segura de Certificados.' 'Python 3 is required to prepare safe Certificate integration.')"
command -v php >/dev/null 2>&1 || fatal "$(say 'PHP é obrigatório para validar a integração segura de Certificados.' 'PHP is required to validate safe Certificate integration.')"

HOOK_BACKUP="$(mktemp /var/tmp/xlx-cert-index.before.XXXXXX)"
cp -a "$DASHBOARD/index.php" "$HOOK_BACKUP"
index_before="$(sha256sum "$DASHBOARD/index.php" | awk '{print $1}')"
python3 "$CERT_HOOK_SCRIPT" "$DASHBOARD/index.php"
php -l "$DASHBOARD/index.php" >/dev/null
index_after="$(sha256sum "$DASHBOARD/index.php" | awk '{print $1}')"
if [ "$index_before" != "$index_after" ]; then
    HOOK_CHANGED=1
    ok "$(say 'Âncora opcional de Certificados adicionada ao dashboard.' 'Optional Certificate hook added to the dashboard.')"
else
    info "$(say 'Âncora opcional de Certificados já estava presente.' 'Optional Certificate hook was already present.')"
fi

a=(--apply "--dashboard-dir=$DASHBOARD" "--site-config=$SITE_CONFIG" "--campaign-pack=$CAMPAIGN_PACK" --trusted-parent)
[ -z "$DATA_DIR" ] || a+=("--data-dir=$DATA_DIR")
[ -z "$SECRET_FILE" ] || a+=("--secret-file=$SECRET_FILE")

info "$(say 'Iniciando instalador independente XLX Certificate Generator.' 'Starting standalone XLX Certificate Generator installer.')"
set +e
XLX_CERTIFICATES_TRUSTED_PARENT=1 bash "$SOURCE/install.sh" "${a[@]}"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    if [ "$HOOK_CHANGED" -eq 1 ] && [ -f "$HOOK_BACKUP" ]; then
        cp -a "$HOOK_BACKUP" "$DASHBOARD/index.php"
        php -l "$DASHBOARD/index.php" >/dev/null 2>&1 || true
        warn "$(say 'Âncora do dashboard restaurada após falha do módulo opcional.' 'Dashboard hook restored after optional module failure.')"
    fi
    fatal "$(say "XLX Certificate Generator falhou (rc=$rc)." "XLX Certificate Generator failed (rc=$rc).")"
fi

php -l "$DASHBOARD/index.php" >/dev/null
grep -Fq 'XLX_CERTIFICATES_OPTIONAL_HOOK_V1' "$DASHBOARD/index.php" || fatal "$(say 'Âncora de Certificados desapareceu após a instalação.' 'Certificate hook disappeared after installation.')"
grep -Fq "\$allowed[] = 'certificado';" "$DASHBOARD/index.php" || fatal "$(say 'Rota de Certificados não ficou integrada.' 'Certificate route was not integrated.')"
grep -Fq "require __DIR__.'/certificado-view.php';" "$DASHBOARD/index.php" || fatal "$(say 'View de Certificados não ficou integrada.' 'Certificate view was not integrated.')"
ok "$(say 'Integração do XLX Certificate Generator concluída.' 'XLX Certificate Generator integration completed.')"
