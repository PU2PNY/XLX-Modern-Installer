#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="/opt/xlx-modern-installer"
VENV="${WORK_ROOT}/tui-venv"
SESSION="xlx-modern-installer"
LOG_ROOT="/var/log/xlx-reflector/installer"
LOG_FILE="${LOG_ROOT}/launcher.log"

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
info(){ printf '%s[INFO]%s %s\n' "$CYAN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

mkdir -p "$LOG_ROOT" 2>/dev/null || true
chmod 700 "$LOG_ROOT" 2>/dev/null || true

on_error(){
    local rc=$? line=${BASH_LINENO[0]:-$LINENO}
    printf '%s[ERRO]%s O inicializador encontrou uma falha na linha %s (código %s).\n' "$RED" "$RESET" "$line" "$rc" >&2
    printf 'Detalhes: %s\n' "$LOG_FILE" >&2
    exit "$rc"
}
trap on_error ERR

[ "$(id -u)" -eq 0 ] || fatal "Execute como root: sudo bash start.sh"
[ -r /etc/os-release ] || fatal "/etc/os-release não encontrado."
# shellcheck disable=SC1091
source /etc/os-release
[ "${ID:-}" = "debian" ] && [ "${VERSION_ID:-}" = "12" ] || fatal "Este instalador exige Debian 12 x86_64."
[ "$(uname -m)" = "x86_64" ] || fatal "Arquitetura não homologada. Use x86_64."
[ -s "$ROOT_DIR/install.sh" ] || fatal "Motor install.sh não encontrado."
[ -s "$ROOT_DIR/tui/simple_installer.py" ] || fatal "Interface simples não encontrada. Atualize o repositório."
[ -s "$ROOT_DIR/tui/requirements.txt" ] || fatal "Arquivo de dependências da interface não encontrado."

mem_mb="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
disk_mb="$(df -Pm / | awk 'NR==2 {print $4}')"
[ "$mem_mb" -ge 768 ] || fatal "RAM insuficiente. Mínimo: 768 MB."
[ "$disk_mb" -ge 4096 ] || fatal "Espaço insuficiente. Mínimo: 4 GB livres em /."

if [ -x /xlxd/xlxd ] || systemctl is-active --quiet xlxd 2>/dev/null || [ -e /var/www/html/xlxd ]; then
    fatal "Foi encontrada uma instalação XLX ativa. Nada será sobrescrito."
fi
if [ -d /xlxd ] || [ -d /usr/src/xlxd ]; then
    fatal "Foram encontrados vestígios de uma instalação anterior. Nada foi apagado. Faça a limpeza segura antes de recomeçar."
fi

if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
    ok "Encontrei o instalador já aberto. Reabrindo a mesma sessão."
    exec tmux attach-session -t "$SESSION"
fi

mkdir -p "$WORK_ROOT"
chmod 700 "$WORK_ROOT"

info "Preparando automaticamente a interface. Nenhuma resposta é necessária nesta etapa."
export DEBIAN_FRONTEND=noninteractive
if ! apt-get update >>"$LOG_FILE" 2>&1; then
    fatal "Não foi possível atualizar a lista de pacotes. Verifique a rede. Detalhes: $LOG_FILE"
fi
if ! apt-get install -y ca-certificates python3 python3-venv tmux >>"$LOG_FILE" 2>&1; then
    warn "Não consegui instalar todos os componentes visuais. Vou tentar o modo compatível."
    exec bash "$ROOT_DIR/install.sh" --classic
fi

if [ -d "$VENV" ] && { [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -m pip --version >/dev/null 2>&1; }; then
    warn "Ambiente visual incompleto encontrado. Corrigindo automaticamente."
    rm -rf "$VENV"
fi

if [ ! -x "$VENV/bin/python" ]; then
    if ! python3 -m venv "$VENV" >>"$LOG_FILE" 2>&1; then
        warn "Não foi possível criar a interface visual. Vou tentar o modo compatível."
        exec bash "$ROOT_DIR/install.sh" --classic
    fi
fi

if ! "$VENV/bin/python" -m pip install --disable-pip-version-check --no-cache-dir -r "$ROOT_DIR/tui/requirements.txt" >>"$LOG_FILE" 2>&1; then
    warn "Não foi possível preparar a interface visual. Vou tentar o modo compatível."
    exec bash "$ROOT_DIR/install.sh" --classic
fi

if ! "$VENV/bin/python" "$ROOT_DIR/tui/simple_installer.py" --self-test >>"$LOG_FILE" 2>&1; then
    warn "A interface visual não passou no autoteste. Vou abrir o modo compatível para não interromper a instalação."
    exec bash "$ROOT_DIR/install.sh" --classic
fi

ok "Pré-validação concluída."
info "O instalador ficará protegido contra queda do SSH. Se a conexão cair, execute novamente: bash start.sh"
sleep 1

if [ -n "${TMUX:-}" ]; then
    exec "$VENV/bin/python" "$ROOT_DIR/tui/simple_installer.py" --root "$ROOT_DIR"
fi

tmux new-session -d -s "$SESSION" \
    "cd '$ROOT_DIR' && exec '$VENV/bin/python' '$ROOT_DIR/tui/simple_installer.py' --root '$ROOT_DIR'"

exec tmux attach-session -t "$SESSION"
