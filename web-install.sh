#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="/opt/xlx-modern-installer"
VENV="${WORK_ROOT}/webui-venv"
UNIT="xlx-modern-web-installer.service"
PORT="${XLX_WEB_PORT:-8765}"
TOKEN_FILE="${WORK_ROOT}/webui-token"

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal "Execute como root: sudo bash web-install.sh"
[ -r /etc/os-release ] || fatal "/etc/os-release não encontrado."
# shellcheck disable=SC1091
source /etc/os-release
[ "${ID:-}" = "debian" ] && [ "${VERSION_ID:-}" = "12" ] || fatal "Use Debian 12 x86_64."
[ "$(uname -m)" = "x86_64" ] || fatal "Arquitetura não homologada. Use x86_64."
[ -s "$ROOT_DIR/install.sh" ] || fatal "install.sh não encontrado em $ROOT_DIR"
[ -s "$ROOT_DIR/webui/server.py" ] || fatal "Interface web não encontrada. Atualize o repositório."
[ -s "$ROOT_DIR/webui/requirements.txt" ] || fatal "Dependências da interface web não encontradas."

if [ -x /xlxd/xlxd ] || systemctl is-active --quiet xlxd 2>/dev/null; then
    fatal "Já existe uma instalação XLXD ativa. O instalador web não sobrescreve uma instalação em produção."
fi
if [ -d /xlxd ] || [ -d /usr/src/xlxd ]; then
    fatal "Foram encontrados vestígios de uma instalação XLXD anterior. Por segurança, nada foi apagado. Faça a limpeza segura antes de iniciar novamente."
fi

mkdir -p "$WORK_ROOT"
chmod 700 "$WORK_ROOT"

needed=()
if command -v python3 >/dev/null 2>&1; then
    # Debian pode fornecer python3 sem ensurepip/venv. O teste anterior com
    # `python3 -m venv --help` não detectava esse caso. Valide o pacote real.
    if ! dpkg-query -W -f='${Status}\n' python3-venv 2>/dev/null | grep -q '^install ok installed$'; then
        needed+=(python3-venv)
    fi
else
    needed+=(python3 python3-venv)
fi
command -v curl >/dev/null 2>&1 || needed+=(curl)
command -v ss >/dev/null 2>&1 || needed+=(iproute2)
command -v systemd-run >/dev/null 2>&1 || needed+=(systemd)

if [ "${#needed[@]}" -gt 0 ]; then
    printf '%sPreparando a interface gráfica...%s\n' "$CYAN" "$RESET"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${needed[@]}"
fi

command -v python3 >/dev/null 2>&1 || fatal "python3 não ficou disponível após preparar o sistema."
command -v ss >/dev/null 2>&1 || fatal "ss/iproute2 não ficou disponível após preparar o sistema."
command -v systemd-run >/dev/null 2>&1 || fatal "systemd-run não ficou disponível após preparar o sistema."

# Uma tentativa interrompida pode deixar um venv parcial com bin/python mas
# sem pip/ensurepip. Nunca reutilize esse estado incompleto.
if [ -d "$VENV" ]; then
    if [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -m pip --version >/dev/null 2>&1; then
        warn "Ambiente virtual incompleto encontrado. Recriando automaticamente."
        rm -rf "$VENV"
    fi
fi

if [ ! -x "$VENV/bin/python" ]; then
    rm -rf "$VENV"
    if ! python3 -m venv "$VENV"; then
        warn "Falha ao criar o ambiente virtual. Reinstalando python3-venv e tentando novamente."
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall python3-venv
        rm -rf "$VENV"
        python3 -m venv "$VENV" || fatal "Não foi possível criar o ambiente virtual Python."
    fi
fi

"$VENV/bin/python" -m pip --version >/dev/null 2>&1 || fatal "pip/ensurepip não está disponível dentro do ambiente virtual."
"$VENV/bin/python" -m pip install --disable-pip-version-check --no-cache-dir -r "$ROOT_DIR/webui/requirements.txt" >/dev/null
"$VENV/bin/python" "$ROOT_DIR/webui/server.py"
ok "Backend do instalador validado."

while ss -H -ltn "sport = :$PORT" 2>/dev/null | grep -q .; do
    PORT=$((PORT + 1))
    [ "$PORT" -le 8799 ] || fatal "Não encontrei uma porta livre entre 8765 e 8799."
done

TOKEN="$($VENV/bin/python - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
)"
printf '%s\n' "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

if systemctl is-active --quiet "$UNIT" 2>/dev/null; then
    systemctl stop "$UNIT"
fi
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true

systemd-run \
    --quiet \
    --unit="${UNIT%.service}" \
    --collect \
    --property="WorkingDirectory=$ROOT_DIR" \
    --property="RuntimeMaxSec=4h" \
    --property="KillMode=mixed" \
    --setenv="XLX_REPO_ROOT=$ROOT_DIR" \
    --setenv="XLX_WEB_TOKEN=$TOKEN" \
    "$VENV/bin/python" -m uvicorn webui.server:app \
        --host 127.0.0.1 \
        --port "$PORT" \
        --no-access-log \
        --log-level warning

for _ in $(seq 1 40); do
    if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then break; fi
    sleep .25
done
curl -fsS --max-time 2 "http://127.0.0.1:$PORT/api/health" >/dev/null || fatal "A interface web não iniciou. Veja: journalctl -u $UNIT -n 80 --no-pager"

SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$SERVER_IP" ] || SERVER_IP="IP_DA_VPS"

printf '\n%s============================================================%s\n' "$CYAN" "$RESET"
printf '%s XLX MODERN INSTALLER — INTERFACE WEB%s\n' "$CYAN" "$RESET"
printf '%s============================================================%s\n\n' "$CYAN" "$RESET"
ok "Interface iniciada com segurança somente dentro da VPS."
printf '\nNo seu computador, abra OUTRO terminal e execute:\n\n'
printf '  %sssh -L %s:127.0.0.1:%s root@%s%s\n\n' "$GREEN" "$PORT" "$PORT" "$SERVER_IP" "$RESET"
printf 'Mantenha essa segunda conexão aberta e, no navegador, abra:\n\n'
printf '  %shttp://127.0.0.1:%s/#token=%s%s\n\n' "$GREEN" "$PORT" "$TOKEN" "$RESET"
printf 'A interface NÃO fica exposta diretamente à Internet.\n'
printf 'O token é temporário e o serviço expira automaticamente em até 4 horas.\n'
printf 'Para encerrar manualmente: systemctl stop %s\n\n' "$UNIT"
