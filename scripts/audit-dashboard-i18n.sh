#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$ROOT/dashboard"

printf '\nXLX Modern Dashboard — i18n audit\n'
printf 'Dashboard: %s\n\n' "$DASHBOARD"

[ -d "$DASHBOARD" ] || { echo "Dashboard directory not found." >&2; exit 1; }

printf '=== PHP/HTML strings likely requiring translation ===\n'
grep -RInE --include='*.php' \
  '(Ao vivo|Conectados|Suporte|Módulos|Últimas|Transmiss|Servidor|Carregando|Pesquisar|País|Horário|Indicativo|Operador|Protocolo|Duração|Status|Notícias|Clima|Propagação|Aguardando|Conectando|Ranking)' \
  "$DASHBOARD" || true

printf '\n=== JavaScript strings likely requiring translation ===\n'
grep -RInE --include='*.js' \
  '(Ao vivo|Conectados|Suporte|Módulos|Últimas|Transmiss|Servidor|Carregando|Pesquisar|País|Horário|Indicativo|Operador|Protocolo|Duração|Status|Notícias|Clima|Propagação|Aguardando|Conectando|Online|Offline)' \
  "$DASHBOARD/assets" "$DASHBOARD" 2>/dev/null || true

printf '\n=== Locale files ===\n'
find "$DASHBOARD/i18n/locales" -maxdepth 1 -type f -name '*.php' -printf '%f\n' 2>/dev/null | sort || true

printf '\nAudit finished. No files were modified.\n'
