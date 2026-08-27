#!/usr/bin/env bash
set -Eeuo pipefail
CONFIG="${1:-}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

say() {
  if [ "$UI_LANG" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}

[ -n "$CONFIG" ] || { printf '%s\n' "$(say "[ERRO] Arquivo de configuração não informado." "[ERROR] Configuration file was not provided.")"; exit 1; }
[ -f "$CONFIG" ] || { printf '%s\n' "$(say "[ERRO] Arquivo de configuração não encontrado: $CONFIG" "[ERROR] Configuration file not found: $CONFIG")"; exit 1; }

# shellcheck disable=SC1090
source "$CONFIG"

for var in XLX_NUMBER XLX_CALLSIGN XLX_DOMAIN; do
  if [ -z "${!var:-}" ]; then
    printf '%s\n' "$(say "[ERRO] Campo obrigatório ausente: $var" "[ERROR] Required field is missing: $var")"
    exit 1
  fi
done

if ! [[ "$XLX_NUMBER" =~ ^[0-9]{3}$ ]]; then
  printf '%s\n' "$(say "[ERRO] XLX_NUMBER inválido: '$XLX_NUMBER'. Use exatamente 3 números, por exemplo 026." "[ERROR] Invalid XLX_NUMBER: '$XLX_NUMBER'. Use exactly 3 digits, for example 139.")"
  exit 1
fi

printf '%s\n' "$(say "[OK] Configuração válida. Nenhuma alteração foi feita." "[OK] Configuration is valid. No changes were made.")"
