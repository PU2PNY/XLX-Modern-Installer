#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="/opt/xlx-modern-installer"
VENV="${WORK_ROOT}/tui-venv"
SESSION="installer"
TMUX_SOCKET="xlxmodern"
TMUX_CONF="${WORK_ROOT}/tmux.conf"
LOG_ROOT="/var/log/xlx-reflector/installer"
LOG_FILE="${LOG_ROOT}/launcher.log"
UI_LOG="${LOG_ROOT}/ui.log"

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
[ -s "$ROOT_DIR/tui/run-simple.sh" ] || fatal "Inicializador da interface não encontrado. Atualize o repositório."
[ -s "$ROOT_DIR/tui/requirements.txt" ] || fatal "Arquivo de dependências da interface não encontrado."

# Recuperação vem antes dos bloqueios de instalação nova. Assim, se o SSH cair
# depois que /xlxd já tiver sido criado, a mesma sessão continua recuperável.
if command -v tmux >/dev/null 2>&1 && tmux -L "$TMUX_SOCKET" has-session -t "$SESSION" 2>/dev/null; then
    pane_dead="$(tmux -L "$TMUX_SOCKET" list-panes -t "$SESSION" -F '#{pane_dead}' 2>/dev/null | head -1 || true)"
    if [ "$pane_dead" = "0" ]; then
        ok "Encontrei o instalador já aberto. Reabrindo a mesma sessão."
        exec tmux -L "$TMUX_SOCKET" -2 attach-session -t "$SESSION"
    fi
    warn "A sessão anterior terminou. Limpando somente a sessão visual antiga."
    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION" 2>/dev/null || true
fi

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

mkdir -p "$WORK_ROOT"
chmod 700 "$WORK_ROOT"

info "Preparando automaticamente a interface. Nenhuma resposta é necessária nesta etapa."
export DEBIAN_FRONTEND=noninteractive
if ! apt-get update >>"$LOG_FILE" 2>&1; then
    fatal "Não foi possível atualizar a lista de pacotes. Verifique a rede. Detalhes: $LOG_FILE"
fi
if ! apt-get install -y ca-certificates python3 python3-venv tmux ncurses-term >>"$LOG_FILE" 2>&1; then
    warn "Não consegui instalar todos os componentes visuais. Vou abrir automaticamente o modo compatível."
    exec bash "$ROOT_DIR/install.sh" --classic
fi

if [ -d "$VENV" ] && { [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -m pip --version >/dev/null 2>&1; }; then
    warn "Ambiente visual incompleto encontrado. Corrigindo automaticamente."
    rm -rf "$VENV"
fi

if [ ! -x "$VENV/bin/python" ]; then
    if ! python3 -m venv "$VENV" >>"$LOG_FILE" 2>&1; then
        warn "Não foi possível criar a interface visual. Vou abrir automaticamente o modo compatível."
        exec bash "$ROOT_DIR/install.sh" --classic
    fi
fi

if ! "$VENV/bin/python" -m pip install --disable-pip-version-check --no-cache-dir -r "$ROOT_DIR/tui/requirements.txt" >>"$LOG_FILE" 2>&1; then
    warn "Não foi possível preparar a interface visual. Vou abrir automaticamente o modo compatível."
    exec bash "$ROOT_DIR/install.sh" --classic
fi

if ! "$VENV/bin/python" "$ROOT_DIR/tui/simple_installer.py" --self-test >>"$LOG_FILE" 2>&1; then
    warn "A interface visual não passou no autoteste. Vou abrir automaticamente o modo compatível."
    exec bash "$ROOT_DIR/install.sh" --classic
fi

cat >"$TMUX_CONF" <<'EOF'
set -g default-terminal "screen-256color"
set -g status on
set -g status-style "bg=green,fg=black"
set -g mouse on
set -g remain-on-exit on
EOF
chmod 600 "$TMUX_CONF"

ok "Pré-validação concluída."
info "Abrindo o instalador guiado. Se o SSH cair, execute novamente: bash start.sh"
sleep 1

# Inicia anexado, em vez de criar uma sessão destacada e anexar depois.
# Isso elimina a janela de corrida que podia resultar em apenas "[exited]".
exec tmux -L "$TMUX_SOCKET" -f "$TMUX_CONF" -2 new-session -A -s "$SESSION" \
    "bash '$ROOT_DIR/tui/run-simple.sh' '$VENV/bin/python' '$ROOT_DIR' '$UI_LOG'"
