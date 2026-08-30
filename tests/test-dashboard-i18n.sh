#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALES=(pt-BR en es fr de it)
REQUIRED_KEYS=(
  live.no_recent_transmission history.empty standby.dmr_advice standby.app_audio_advice footer.developed_by footer.community
  common.country_unidentified common.flag_of common.operator_unidentified common.awaiting_gateway_identification
  common.not_informed_masc common.not_informed_fem common.country_not_informed common.location_not_informed
  live.awaiting_transmission connected.by_protocol_module connected.module
)

fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

for locale in "${LOCALES[@]}"; do
  file="$ROOT/dashboard/i18n/locales/$locale.php"
  [[ -f "$file" ]] || fail "missing locale file: $locale"
  for key in "${REQUIRED_KEYS[@]}"; do
    grep -Fq "'$key'" "$file" || fail "missing $key in $locale"
  done
done
ok 'required user-visible strings exist in all six locales'

if ! command -v php >/dev/null 2>&1; then
  printf '[SKIP] PHP unavailable; build translation check will run in CI.\n'
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a "$ROOT/dashboard/." "$tmp/"
mkdir -p "$tmp/config"
printf '%s\n' '<?php return []; ' > "$tmp/config/site.php"
php "$ROOT/dashboard/i18n/build.php" "$tmp" en >/dev/null

for source in 'Sem transmissão recente' 'Nenhuma transmissão registrada nas últimas 24 horas.' 'Áudio do aplicativo' 'Desenvolvido por' 'para a comunidade radioamadora.' 'País não identificado' 'Bandeira de' 'Operador não identificado' 'Aguardando identificação pelo gateway' 'Não informado' 'Não informada' 'País não informado' 'Localização não informada' 'Aguardando transmissão' 'Conectou por' 'Servidor em espera' 'Transmitindo agora'; do
  if rg -F --glob '!i18n/**' "$source" "$tmp" >/dev/null; then
    fail "Portuguese string remained in English build: $source"
  fi
done
ok 'English dashboard build contains no known Portuguese UI leaks'
