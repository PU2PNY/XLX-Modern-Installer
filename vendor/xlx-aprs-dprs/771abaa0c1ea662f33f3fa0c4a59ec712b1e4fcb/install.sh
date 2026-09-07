#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; BLUE=$'\033[1;34m'; RESET=$'\033[0m'
ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
info(){ printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$*"; }
warn(){ printf '%b[ATENCAO]%b %s\n' "$YELLOW" "$RESET" "$*"; }
fail(){ printf '%b[ERRO]%b %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
valid_base_call(){
    local value="${1:-}"
    [[ "$value" =~ ^[A-Z0-9]{3,8}$ ]] && [[ "$value" =~ [0-9] ]]
}

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD=""
REFLECTOR_NAME="XLX"
REFLECTOR_HOST="127.0.0.1"
CLIENT_CALLSIGN=""
APRS_LOGIN=""
APRS_TX=0
ACTIVATE=0
NON_INTERACTIVE=0
CHECK_ONLY=0

usage(){
cat <<'EOF'
Uso:
  sudo bash install.sh [opcoes]

Opcoes:
  --dashboard-dir PATH       Painel moderno existente
  --reflector-name NOME      Ex.: XLX123
  --reflector-host HOST      IP/host do XLXD; padrao 127.0.0.1
  --client-callsign CALL     Indicativo do cliente DExtra
  --aprs-login CALL-SSID     Indicativo APRS-IS do servico
  --enable-aprs-tx           Habilita TX APRS usando passcode "auto"
  --activate                 Habilita/inicia o servico apos instalar
  --non-interactive          Nao faz perguntas
  --check                    Somente pre-validacao; nao altera nada
  -h, --help                 Ajuda
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dashboard-dir) DASHBOARD="${2:-}"; shift 2 ;;
        --reflector-name) REFLECTOR_NAME="${2:-}"; shift 2 ;;
        --reflector-host) REFLECTOR_HOST="${2:-}"; shift 2 ;;
        --client-callsign) CLIENT_CALLSIGN="${2:-}"; shift 2 ;;
        --aprs-login) APRS_LOGIN="${2:-}"; shift 2 ;;
        --enable-aprs-tx) APRS_TX=1; shift ;;
        --activate) ACTIVATE=1; shift ;;
        --non-interactive) NON_INTERACTIVE=1; shift ;;
        --check) CHECK_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Opcao desconhecida: $1" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fail "Execute como root."

for cmd in python3 php install rsync sha256sum systemctl tar; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Comando obrigatorio ausente: $cmd"
done

php -r 'exit(extension_loaded("pdo_sqlite") ? 0 : 1);' \
    || fail "PHP pdo_sqlite nao esta habilitado."

python3 - <<'PY'
import sqlite3, sys
sys.exit(0 if sqlite3.sqlite_version_info >= (3, 8, 0) else 1)
PY

[ -f "$ROOT/gateway/xlx_aprs_dprs.py" ] || fail "Gateway ausente no pacote."
[ -f "$ROOT/web/index.php" ] || fail "Interface web ausente no pacote."
[ -f "$ROOT/systemd/xlx-aprs-dprs.service" ] || fail "Unit systemd ausente."
[ -f "$ROOT/scripts/init-accounts.php" ] || fail "Inicializador de contas ausente."

# Não permite instalar o novo serviço ao lado do legado ativo: dois gateways no módulo B
# poderiam duplicar conexões/atividade APRS.
if systemctl is-active --quiet xlx-legacy-digital-lab.service 2>/dev/null; then
    fail "Servico legado de Digital Lab esta ativo. Use um procedimento de migracao dedicado; este instalador nao executa coexistencia."
fi

if [ -e /etc/systemd/system/xlx-aprs-dprs.service ] || [ -d /opt/xlx-aprs-dprs ]; then
    fail "XLX APRS/D-PRS ja parece instalado. Use update.sh para atualizar."
fi

detect_dashboard(){
    local d
    for d in \
        /var/www/html/xlx-dashboard \
        /var/www/html/xlxd
    do
        if [ -f "$d/index.php" ] && [ -f "$d/assets/app.css" ]; then
            printf '%s' "$d"
            return 0
        fi
    done
    return 1
}

if [ -z "$DASHBOARD" ]; then
    DASHBOARD="$(detect_dashboard || true)"
fi

[ -n "$DASHBOARD" ] || fail "Painel moderno nao detectado. Informe --dashboard-dir."
[ -d "$DASHBOARD" ] || fail "Dashboard inexistente: $DASHBOARD"
[ -f "$DASHBOARD/index.php" ] || fail "index.php do dashboard ausente."
[ -f "$DASHBOARD/assets/app.css" ] || fail "assets/app.css do dashboard ausente."

REFLECTOR_NAME="$(printf '%s' "$REFLECTOR_NAME" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_-')"
CLIENT_CALLSIGN="$(printf '%s' "$CLIENT_CALLSIGN" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9')"
APRS_LOGIN="$(printf '%s' "$APRS_LOGIN" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9-')"

[ -n "$REFLECTOR_NAME" ] || fail "Nome do refletor invalido."

if [ -n "$CLIENT_CALLSIGN" ] && ! valid_base_call "$CLIENT_CALLSIGN"; then
    fail "Indicativo DExtra invalido: $CLIENT_CALLSIGN"
fi

if [ -n "$APRS_LOGIN" ] && ! [[ "$APRS_LOGIN" =~ ^[A-Z0-9]{3,8}(-[0-9]{1,2})?$ ]]; then
    fail "Indicativo APRS invalido: $APRS_LOGIN"
fi

if [ "$APRS_TX" -eq 1 ] && [ -z "$APRS_LOGIN" ]; then
    fail "--enable-aprs-tx exige --aprs-login."
fi

if [ "$NON_INTERACTIVE" -eq 0 ] && [ -t 0 ]; then
    if [ -z "$CLIENT_CALLSIGN" ]; then
        read -r -p "Indicativo do cliente DExtra (Enter para deixar desativado): " CLIENT_CALLSIGN
        CLIENT_CALLSIGN="$(printf '%s' "$CLIENT_CALLSIGN" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9')"
    fi

    if [ -z "$APRS_LOGIN" ]; then
        read -r -p "Indicativo APRS-IS/SSID (Enter para deixar desativado): " APRS_LOGIN
        APRS_LOGIN="$(printf '%s' "$APRS_LOGIN" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9-')"
    fi

    if [ -n "$APRS_LOGIN" ] && [ "$APRS_TX" -eq 0 ]; then
        read -r -p "Habilitar envio APRS pelo painel? [s/N]: " ANSWER
        [[ "${ANSWER,,}" == "s" || "${ANSWER,,}" == "sim" ]] && APRS_TX=1
    fi

    if [ "$ACTIVATE" -eq 0 ]; then
        read -r -p "Ativar o servico ao final? [s/N]: " ANSWER
        [[ "${ANSWER,,}" == "s" || "${ANSWER,,}" == "sim" ]] && ACTIVATE=1
    fi
fi

# Revalida entradas após possível modo interativo.
if [ -n "$CLIENT_CALLSIGN" ] && ! valid_base_call "$CLIENT_CALLSIGN"; then
    fail "Indicativo DExtra invalido."
fi
if [ -n "$APRS_LOGIN" ] && ! [[ "$APRS_LOGIN" =~ ^[A-Z0-9]{3,8}(-[0-9]{1,2})?$ ]]; then
    fail "Indicativo APRS invalido."
fi

info "Pre-validando sintaxe do pacote..."
php -l "$ROOT/web/index.php" >/dev/null
php -l "$ROOT/web/digital-lab-native.php" >/dev/null
php -l "$ROOT/web/api/digital-lab.php" >/dev/null
php -l "$ROOT/web/api/digital-lab-operator.php" >/dev/null
php -l "$ROOT/scripts/init-accounts.php" >/dev/null

python3 - "$ROOT/gateway/xlx_aprs_dprs.py" <<'PY'
import pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
compile(source, sys.argv[1], "exec")
PY

if command -v node >/dev/null 2>&1; then
    node --check "$ROOT/web/assets/digital-lab.js" >/dev/null
    node --check "$ROOT/web/assets/digital-lab-operator.js" >/dev/null
fi

echo
echo "Dashboard       : $DASHBOARD"
echo "Refletor        : $REFLECTOR_NAME"
echo "Host XLXD       : $REFLECTOR_HOST"
echo "Cliente DExtra  : ${CLIENT_CALLSIGN:-DESATIVADO}"
echo "APRS login      : ${APRS_LOGIN:-DESATIVADO}"
echo "APRS TX         : $([ "$APRS_TX" -eq 1 ] && echo SIM || echo NAO)"
echo "Ativar servico  : $([ "$ACTIVATE" -eq 1 ] && echo SIM || echo NAO)"
echo

if [ "$CHECK_ONLY" -eq 1 ]; then
    ok "Pre-validacao concluida; nenhuma alteracao realizada."
    echo "STATUS=CHECK_OK"
    exit 0
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
STAGE="$(mktemp -d /root/xlx-aprs-dprs-install.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/opt" "$STAGE/etc" "$STAGE/state" "$STAGE/web"

# Configuração candidata é criada em staging; nenhum segredo real é copiado do servidor.
python3 - \
    "$STAGE/etc/config.json" \
    "$REFLECTOR_NAME" \
    "$REFLECTOR_HOST" \
    "$CLIENT_CALLSIGN" \
    "$APRS_LOGIN" \
    "$APRS_TX" <<'PY'
import json, sys
out, name, host, client, aprs, tx = sys.argv[1:]
tx = tx == "1"
cfg = {
    "database": "/var/lib/xlx-aprs-dprs/digital-lab.sqlite",
    "public_snapshot": "/var/lib/xlx-aprs-dprs/public.json",
    "operator_socket": "/var/lib/xlx-aprs-dprs/operator.sock",
    "retention_days": 7,
    "snapshot_interval": 2,
    "reflector": {
        "enabled": bool(client),
        "host": host,
        "port": 30001,
        "module": "B",
        "client_callsign": client,
        "client_module": "G"
    },
    "aprs": {
        "enabled": bool(aprs),
        "host": "rotate.aprs2.net",
        "port": 14580,
        "login": aprs,
        "passcode": "auto" if tx else "-1",
        "filter": "",
        "tx_enabled": tx and bool(aprs)
    },
    "site": {
        "title": f"{name} APRS/D-PRS",
        "reflector": name,
        "module": "B"
    }
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

cp -a "$ROOT/gateway/xlx_aprs_dprs.py" "$STAGE/opt/"
cp -a "$ROOT/backup.sh" "$STAGE/opt/"
cp -a "$ROOT/web/." "$STAGE/web/"
cp -a "$ROOT/systemd/xlx-aprs-dprs.service" "$STAGE/xlx-aprs-dprs.service"

# O gateway valida a configuração candidata antes da publicação.
python3 "$STAGE/opt/xlx_aprs_dprs.py" \
    --config "$STAGE/etc/config.json" \
    --check-config

info "Publicando arquivos do modulo..."
install -d -o root -g root -m 0755 /opt/xlx-aprs-dprs
install -d -o root -g www-data -m 0750 /etc/xlx-aprs-dprs
install -d -o www-data -g www-data -m 0750 /var/lib/xlx-aprs-dprs
install -d -o root -g www-data -m 0755 "$DASHBOARD/aprs-dprs"

install -o root -g root -m 0755 \
    "$STAGE/opt/xlx_aprs_dprs.py" \
    /opt/xlx-aprs-dprs/xlx_aprs_dprs.py

install -o root -g root -m 0755 \
    "$STAGE/opt/backup.sh" \
    /opt/xlx-aprs-dprs/backup.sh

install -o root -g www-data -m 0640 \
    "$STAGE/etc/config.json" \
    /etc/xlx-aprs-dprs/config.json

rsync -a --delete \
    --chown=root:www-data \
    "$STAGE/web/" \
    "$DASHBOARD/aprs-dprs/"

find "$DASHBOARD/aprs-dprs" -type d -exec chmod 0755 {} +
find "$DASHBOARD/aprs-dprs" -type f -name '*.php' -exec chmod 0640 {} +
find "$DASHBOARD/aprs-dprs" -type f ! -name '*.php' -exec chmod 0644 {} +

install -o root -g root -m 0644 \
    "$STAGE/xlx-aprs-dprs.service" \
    /etc/systemd/system/xlx-aprs-dprs.service

printf 'DASHBOARD_DIR=%q\n' "$DASHBOARD" > /etc/xlx-aprs-dprs/install.env
chown root:root /etc/xlx-aprs-dprs/install.env
chmod 0600 /etc/xlx-aprs-dprs/install.env

ADMIN_CALL="$CLIENT_CALLSIGN"
CRED_PATH="/root/xlx-aprs-dprs-admin-${STAMP}.txt"

php "$ROOT/scripts/init-accounts.php" \
    /var/lib/xlx-aprs-dprs/accounts.sqlite \
    "$ADMIN_CALL" \
    "$CRED_PATH"

chown www-data:www-data /var/lib/xlx-aprs-dprs/accounts.sqlite
chmod 0640 /var/lib/xlx-aprs-dprs/accounts.sqlite
rm -f /var/lib/xlx-aprs-dprs/accounts.sqlite-wal /var/lib/xlx-aprs-dprs/accounts.sqlite-shm 2>/dev/null || true

systemctl daemon-reload

if [ "$ACTIVATE" -eq 1 ]; then
    systemctl enable --now xlx-aprs-dprs.service
    sleep 1
    systemctl is-active --quiet xlx-aprs-dprs.service \
        || fail "Servico nao permaneceu ativo."
    ok "Servico ativo."
else
    warn "Servico instalado, mas nao ativado."
fi

# Validação final de arquivos publicados.
php -l "$DASHBOARD/aprs-dprs/index.php" >/dev/null
php -l "$DASHBOARD/aprs-dprs/api/digital-lab.php" >/dev/null
php -l "$DASHBOARD/aprs-dprs/api/digital-lab-operator.php" >/dev/null
python3 /opt/xlx-aprs-dprs/xlx_aprs_dprs.py \
    --config /etc/xlx-aprs-dprs/config.json \
    --check-config

ok "XLX APRS/D-PRS instalado de forma isolada."
echo "Pagina            : ${DASHBOARD}/aprs-dprs/"
echo "Configuracao      : /etc/xlx-aprs-dprs/config.json"
echo "Estado            : /var/lib/xlx-aprs-dprs"
if [ -f "$CRED_PATH" ]; then
    echo "Credencial ADMIN  : $CRED_PATH"
    warn "A senha nao foi exibida. Leia o arquivo localmente como root e troque-a apos o primeiro acesso."
fi
echo "STATUS=INSTALL_OK"
