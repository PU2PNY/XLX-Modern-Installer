#!/usr/bin/env bash

select_language() {
  if [ -n "${LANGUAGE:-}" ]; then return 0; fi
  printf '\nXLX MODERN INSTALLER\n\n'
  printf '[1] Português\n[2] English\n\n'
  while true; do
    read -r -p 'Escolha / Select: ' choice
    case "$choice" in
      1) LANGUAGE='pt-BR'; break ;;
      2) LANGUAGE='en'; break ;;
      *) printf 'Opção inválida / Invalid option.\n' ;;
    esac
  done
}

tr_text() {
  local key="$1"
  if [ "$LANGUAGE" = 'en' ]; then
    case "$key" in
      check_complete) echo 'Pre-installation verification completed.' ;;
      panel_only_development) echo 'Panel-only mode is still under development.' ;;
      repair_development) echo 'Repair mode is still under development.' ;;
      development_stop) echo 'Development safety stop: no installation was executed.' ;;
      config_saved) echo 'Configuration saved' ;;
      no_changes_applied) echo 'No package, service, firewall rule or production file was changed.' ;;
      *) echo "$key" ;;
    esac
  else
    case "$key" in
      check_complete) echo 'Verificação pré-instalação concluída.' ;;
      panel_only_development) echo 'O modo somente painel ainda está em desenvolvimento.' ;;
      repair_development) echo 'O modo de reparo ainda está em desenvolvimento.' ;;
      development_stop) echo 'Parada de segurança da versão de desenvolvimento: nenhuma instalação foi executada.' ;;
      config_saved) echo 'Configuração salva' ;;
      no_changes_applied) echo 'Nenhum pacote, serviço, firewall ou arquivo de produção foi alterado.' ;;
      *) echo "$key" ;;
    esac
  fi
}
