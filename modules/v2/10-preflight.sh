#!/usr/bin/env bash

require_root(){ [ "$(id -u)" -eq 0 ] || { ui_error 'Execute como root.'; exit 1; }; }

run_preflight(){
  ui_section 'Pré-verificação / Preflight'
  [ -r /etc/os-release ] || { ui_error '/etc/os-release ausente.'; exit 1; }
  # shellcheck disable=SC1091
  source /etc/os-release
  [ "${ID:-}" = 'debian' ] && [ "${VERSION_ID:-}" = '12' ] || { ui_error 'Use Debian 12.'; exit 1; }
  [ "$(uname -m)" = 'x86_64' ] || { ui_error 'Arquitetura suportada: x86_64.'; exit 1; }

  local mem_mb disk_mb
  mem_mb="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
  disk_mb="$(df -Pm / | awk 'NR==2 {print $4}')"
  [ "$mem_mb" -ge 768 ] || { ui_error 'RAM insuficiente: mínimo 768 MB.'; exit 1; }
  [ "$disk_mb" -ge 4096 ] || { ui_error 'Disco insuficiente: mínimo 4 GB livres.'; exit 1; }

  getent hosts github.com >/dev/null 2>&1 || { ui_error 'Falha de DNS.'; exit 1; }
  timedatectl show -p Timezone --value >/dev/null 2>&1 || { ui_error 'Não foi possível detectar o fuso horário.'; exit 1; }

  if [ -x /xlxd/xlxd ] || systemctl is-active --quiet xlxd 2>/dev/null; then
    ui_error 'Instalação XLX ativa detectada. A instalação completa não sobrescreve produção.'
    exit 1
  fi

  ui_success "Debian 12 x86_64"
  ui_success "RAM: ${mem_mb} MB"
  ui_success "Disco livre: ${disk_mb} MB"
  ui_success 'DNS e horário disponíveis'
}
