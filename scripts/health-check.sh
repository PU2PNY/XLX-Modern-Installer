#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Read-only XLX health check.
# This script does not restart services, edit configuration or open ports.

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO/WARN]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail(){ printf '%s[ERRO/ERROR]%s %s\n' "$RED" "$RESET" "$*"; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$*"; }

check_service(){
    local service="$1"
    if ! systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q .; then
        warn "$service.service não encontrado / not installed"
        return 0
    fi
    if systemctl is-active --quiet "$service"; then
        ok "$service ativo / active"
    else
        fail "$service inativo / inactive"
        systemctl status "${service}.service" --no-pager -l 2>/dev/null | tail -n 12 || true
    fi
}

section "XLX MODERN INSTALLER — HEALTH CHECK"
info "Data / Date: $(date --iso-8601=seconds 2>/dev/null || date)"
info "Host: $(hostname -f 2>/dev/null || hostname)"
info "Kernel: $(uname -srmo)"

section "SISTEMA / SYSTEM"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    info "OS: ${PRETTY_NAME:-unknown}"
fi
info "Arquitetura / Architecture: $(uname -m)"
info "Memória / Memory: $(awk '/MemTotal:/ {printf "%.0f MB", $2/1024}' /proc/meminfo)"
info "Disco livre / Free disk: $(df -hP / | awk 'NR==2 {print $4}')"

section "SERVIÇOS / SERVICES"
check_service xlxd
check_service apache2
check_service xlxecho

section "ARQUIVOS PRINCIPAIS / MAIN FILES"
for path in \
    /xlxd/xlxd \
    /xlxd/users_db \
    /xlxd/callinghome.php \
    /xlxd/xlxd.whitelist \
    /xlxd/xlxd.blacklist \
    /xlxd/xlxd.interlink \
    /etc/systemd/system/xlxd.service \
    /var/www/html/xlxd; do
    if [ -e "$path" ]; then ok "$path"; else warn "ausente / missing: $path"; fi
done

section "APACHE"
if command -v apache2ctl >/dev/null 2>&1; then
    apache2ctl configtest || true
else
    warn "apache2ctl não encontrado / not found"
fi

section "PORTAS EM ESCUTA / LISTENING PORTS"
if command -v ss >/dev/null 2>&1; then
    ss -lntup 2>/dev/null || true
else
    warn "ss não encontrado / not found"
fi

section "PROCESSO XLXD / XLXD PROCESS"
ps aux | grep '[x]lxd' || warn "processo xlxd não encontrado / process not found"

section "LOGS RECENTES / RECENT LOGS"
if systemctl list-unit-files xlxd.service --no-legend 2>/dev/null | grep -q .; then
    journalctl -u xlxd.service -n 30 --no-pager 2>/dev/null || true
fi

section "RESULTADO / RESULT"
info "Diagnóstico somente leitura concluído."
info "Read-only health check completed."
info "Nenhuma configuração foi alterada / No configuration was changed."
