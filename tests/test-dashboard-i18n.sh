#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALES=(pt-BR en es fr de it)
REQUIRED_KEYS=(
  live.no_recent_transmission history.empty standby.dmr_advice standby.app_audio_advice footer.developed_by footer.community
  common.country_unidentified common.flag_of common.operator_unidentified common.awaiting_gateway_identification
  common.not_informed_masc common.not_informed_fem common.country_not_informed common.location_not_informed
  live.awaiting_transmission connected.by_protocol_module connected.module
  ui.server_access ui.open_accessibility ui.accessibility ui.close_accessibility ui.close_menu ui.live_summary
  ui.weather_aria ui.connected_filters ui.all ui.accessibility_audio ui.accessibility_audio_note
  ui.panel_sound ui.connected_voice ui.tx_beeps ui.test_beep ui.visual_navigation ui.text_size
  ui.high_contrast ui.highlight_links ui.larger_controls ui.reduce_motion ui.keyboard_focus ui.reset_accessibility
  ui.menu ui.close ui.disable_sound_alerts ui.enable_sound_alerts ui.beep_enabled ui.beep_disabled
  ui.quick_access ui.install ui.install_title ui.install_ios_description ui.show_install_steps ui.got_it
  ui.browser_install_description ui.browser_install_steps ui.loading_weather ui.loading_statistics
  ui.longest_connection ui.today ui.days_7 ui.this_month ui.total_talk_time ui.participating_callsigns
  ui.most_transmissions ui.most_talk_time ui.talk_time_comparison ui.busiest ui.most_used ui.connected_protocols
  ui.no_data ui.no_connected_station ui.full_coverage ui.partial_coverage ui.statistics_updated
  ui.temporary_statistics_failure ui.day ui.days ui.modules_prefix ui.logo
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

# These are visitor-facing Portuguese phrases. They may exist in source and
# in the Portuguese catalog, but must not remain in any non-Portuguese build.
PROHIBITED_PT=(
  'Sem transmissão recente' 'Nenhuma transmissão registrada nas últimas 24 horas.' 'Áudio do aplicativo'
  'Desenvolvido por' 'para a comunidade radioamadora.' 'País não identificado' 'Bandeira de'
  'Operador não identificado' 'Aguardando identificação pelo gateway' 'Não informado' 'Não informada'
  'País não informado' 'Localização não informada' 'Aguardando transmissão' 'Conectou por'
  'Servidor em espera' 'Transmitindo agora' 'Acessos do servidor' 'Abrir acessibilidade'
  'Fechar acessibilidade' 'Resumo do monitor ao vivo' 'Filtros das estações conectadas'
  'Áudio do painel' 'Som do painel' 'Fala da quantidade de conectados' 'Bips de transmissão'
  'Visual e navegação' 'Tamanho do texto' 'Alto contraste' 'Destacar links' 'Controles maiores'
  'Reduzir animações' 'Foco de teclado' 'Restaurar acessibilidade' 'Desativar avisos sonoros'
  'Ativar avisos sonoros' 'Acesso rápido' 'Ver como instalar' 'Carregando clima e propagação...'
  'Carregando cobertura estatística...' 'MAIS TEMPO CONECTADO' 'ESTE MÊS' 'Tempo total falando'
  'Indicativos participantes' 'Mais tempo falando' 'Comparativo de tempo falando' 'Maior movimento'
  'Mais utilizados' 'Protocolos conectados' 'Sem dados.' 'Nenhuma estação conectada'
  'Cobertura integral disponível para este período.' 'Cobertura parcial para este período.'
  'Falha temporária ao atualizar estatísticas.'
)

for locale in en es fr de it; do
  target="$tmp/$locale"
  mkdir -p "$target"
  cp -a "$ROOT/dashboard/." "$target/"
  mkdir -p "$target/config"
  printf '%s\n' '<?php return []; ' > "$target/config/site.php"
  php "$ROOT/dashboard/i18n/build.php" "$target" "$locale" >/dev/null

  for source in "${PROHIBITED_PT[@]}"; do
    if rg -F --glob '!i18n/**' "$source" "$target" >/dev/null; then
      fail "Portuguese UI string remained in $locale build: $source"
    fi
  done
done
ok 'all five non-Portuguese dashboard builds contain no audited Portuguese UI leaks'
