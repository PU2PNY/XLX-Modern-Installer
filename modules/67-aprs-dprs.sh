#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

readonly APRS_REPOSITORY="PU2PNY/XLX-APRS-DPRS"
readonly APRS_COMMIT="771abaa0c1ea662f33f3fa0c4a59ec712b1e4fcb"
readonly APRS_INSTALLER_SHA256="0c5c26adbf9b54fe803e3cbaf2ddc17e4ba737f7c9f3b5606231b67c9a9403f9"
readonly APRS_MANIFEST_SHA256="b4a0e8f1e1fec7e894cff4c61b18c5891122278ecf5f2f666e5398b361c808d4"
readonly VENDOR_ROOT="/opt/xlx-modern-installer/vendor/xlx-aprs-dprs"

MODE="install"
DASHBOARD="${XLX_DASHBOARD_DIR:-/var/www/html/xlx-dashboard}"
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
        -h|--help)
            cat <<'HELP'
XLX Modern — módulo opcional APRS/D-PRS

Uso:
  sudo bash modules/67-aprs-dprs.sh --check
  sudo bash modules/67-aprs-dprs.sh --dashboard-dir=/var/www/html/xlx-dashboard

O módulo baixa um commit fixado do repositório XLX-APRS-DPRS, valida SHA-256,
manifesto e sintaxe e somente então chama o instalador independente.
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
        fatal "Arquivo APRS/D-PRS contém caminho inseguro."
    fi
    warn "Python ainda não está disponível; validação avançada de links do arquivo foi adiada."
}

validate_source(){
    local source="$1" actual has_php=0 has_python=0

    [ -f "$source/install.sh" ] || fatal "install.sh ausente no componente APRS/D-PRS."
    [ -f "$source/SOURCE-MANIFEST.sha256" ] || fatal "SOURCE-MANIFEST.sha256 ausente."

    actual="$(sha256sum "$source/install.sh" | awk '{print $1}')"
    [ "$actual" = "$APRS_INSTALLER_SHA256" ] || fatal "SHA-256 do install.sh divergente. Esperado=$APRS_INSTALLER_SHA256 Obtido=$actual"

    actual="$(sha256sum "$source/SOURCE-MANIFEST.sha256" | awk '{print $1}')"
    [ "$actual" = "$APRS_MANIFEST_SHA256" ] || fatal "SHA-256 do manifesto divergente. Esperado=$APRS_MANIFEST_SHA256 Obtido=$actual"

    (
        cd "$source"
        sha256sum -c SOURCE-MANIFEST.sha256 >/dev/null
    ) || fatal "Manifesto APRS/D-PRS não confere."

    while IFS= read -r -d '' file; do
        bash -n "$file"
    done < <(find "$source" -type f -name '*.sh' -print0)

    if command -v php >/dev/null 2>&1; then
        has_php=1
        while IFS= read -r -d '' file; do
            php -l "$file" >/dev/null
        done < <(find "$source" -type f -name '*.php' -print0)
    elif [ "$MODE" = "install" ]; then
        fatal "PHP ainda não está disponível para instalar APRS/D-PRS."
    else
        warn "PHP ainda não está disponível; lint PHP será repetido na instalação real."
    fi

    if command -v python3 >/dev/null 2>&1; then
        has_python=1
        python3 - "$source/gateway/xlx_aprs_dprs.py" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1])
compile(p.read_text(encoding='utf-8'), str(p), 'exec')
PY
    elif [ "$MODE" = "install" ]; then
        fatal "Python 3 ainda não está disponível para instalar APRS/D-PRS."
    else
        warn "Python 3 ainda não está disponível; validação do gateway será repetida na instalação real."
    fi

    if [ "$has_php" -eq 1 ] && [ "$has_python" -eq 1 ] && [ -f "$source/scripts/validate-source.sh" ]; then
        bash -n "$source/scripts/validate-source.sh"
        (cd "$source" && bash scripts/validate-source.sh >/dev/null)
    fi

    ok "APRS/D-PRS validado no nível disponível neste host."
    info "Commit fixado: $APRS_COMMIT"
    info "SHA-256 install.sh: $APRS_INSTALLER_SHA256"
}

prepare_source(){
    local final="$VENDOR_ROOT/$APRS_COMMIT" archive url

    if [ -d "$final" ]; then
        validate_source "$final"
        SOURCE="$final"
        return
    fi

    TEMP_DIR="$(mktemp -d /opt/xlx-aprs-dprs-fetch.XXXXXX)"
    archive="$TEMP_DIR/source.tar.gz"
    url="https://github.com/${APRS_REPOSITORY}/archive/${APRS_COMMIT}.tar.gz"

    info "Baixando APRS/D-PRS do commit revisado..."
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
        --connect-timeout 10 --max-time 120 "$url" -o "$archive"
    [ -s "$archive" ] || fatal "Arquivo APRS/D-PRS vazio."

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
    ok "Pré-validação APRS/D-PRS concluída; nenhuma instalação executada."
    exit 0
fi

[ -d "$DASHBOARD" ] || fatal "Dashboard não encontrado: $DASHBOARD"
[ -f "$DASHBOARD/index.php" ] || fatal "Dashboard incompatível: index.php ausente."

args=("--dashboard-dir" "$DASHBOARD")
SITE_CONFIG="$DASHBOARD/config/site.php"

if [ -f "$SITE_CONFIG" ]; then
    REFLECTOR_NAME="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["name"]??"");' "$SITE_CONFIG")"
    SYSOP_CALLSIGN="$(php -r '$c=require $argv[1]; echo (string)($c["reflector"]["sysop_callsign"]??"");' "$SITE_CONFIG")"

    [ -z "$REFLECTOR_NAME" ] || args+=("--reflector-name" "$REFLECTOR_NAME")
    [ -z "$SYSOP_CALLSIGN" ] || args+=("--client-callsign" "$SYSOP_CALLSIGN")
fi

info "Iniciando instalador independente APRS/D-PRS."
bash "$SOURCE/install.sh" "${args[@]}"
ok "Integração APRS/D-PRS concluída."
