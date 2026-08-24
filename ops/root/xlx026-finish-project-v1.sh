#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

BACKUP_ROOT="/root/backups-xlx026"
CORE_RELEASE="/usr/local/sbin/xlx026-core-260-release-v1"
PANEL_RELEASE="/usr/local/sbin/xlx026-panel-footer-v1"
BASE_URL="https://xlx026.net"
EXPECTED_CORE_VERSION="2.6.0"
EXPECTED_PANEL_VERSION="1.1.0"
PANEL_MARKER="Painel XLX026 v1.1.0"
PANEL_SOURCE_URL="https://github.com/PU2PNY/XLX-Modern-Installer/tree/main/dashboard"
INSTALLER_URL="https://github.com/PU2PNY/XLX-Modern-Installer"

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }
get_kv(){ awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1"; }
xml_version(){ sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' /var/log/xlxd.xml 2>/dev/null | head -1; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in awk curl date find grep head pgrep sed sha256sum sort systemctl tee wc; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done
[[ -x "$CORE_RELEASE" ]] || { fail "$CORE_RELEASE ausente"; exit 3; }
[[ -x "$PANEL_RELEASE" ]] || { fail "$PANEL_RELEASE ausente"; exit 4; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/XLX026_PROJECT_COMPLETE_${STAMP}"
mkdir -p "$OUT"
chmod 700 "$OUT"
exec > >(tee "$OUT/execution.log") 2>&1

section "1/5 — PAUSAR CONTROLE REMOTO TEMPORÁRIO"
systemctl stop xlx026-github-agent.timer 2>/dev/null || true
systemctl stop xlx026-github-agent.service 2>/dev/null || true
systemctl stop xlx026-github-executor.path 2>/dev/null || true
systemctl stop xlx026-github-executor.service 2>/dev/null || true
ok "Agente de manutenção pausado para evitar concorrência"

section "2/5 — FINALIZAR E PUBLICAR CORE"
"$CORE_RELEASE"
CORE_MARK="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name RELEASE_COMPLETE -path '*XLX026_CORE_260_RELEASE_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$CORE_MARK" && -f "$CORE_MARK" ]] || { fail "RELEASE_COMPLETE não localizado"; exit 20; }
[[ "$(get_kv "$CORE_MARK" status)" == "RELEASE_OK" ]] || { fail "core não terminou em RELEASE_OK"; exit 21; }
CORE_SHA="$(get_kv "$CORE_MARK" new_binary_sha)"
[[ -n "$CORE_SHA" && "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "SHA do core final diverge"; exit 22; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "versão XML final do core não é 2.6.0"; exit 23; }
ok "Core XLX026 2.6.0 aprovado"

section "3/5 — PUBLICAR RODAPÉ/VERSÃO DO PAINEL"
"$PANEL_RELEASE"
PANEL_COMPLETE="$(find "$BACKUP_ROOT" -maxdepth 2 -type f -name PANEL_RELEASE_COMPLETE -path '*XLX026_PANEL_FOOTER_*/*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$PANEL_COMPLETE" && -f "$PANEL_COMPLETE" ]] || { fail "PANEL_RELEASE_COMPLETE não localizado"; exit 30; }
[[ "$(get_kv "$PANEL_COMPLETE" status)" == "PANEL_RELEASE_OK" ]] || { fail "painel não terminou em PANEL_RELEASE_OK"; exit 31; }
[[ "$(get_kv "$PANEL_COMPLETE" panel_version)" == "$EXPECTED_PANEL_VERSION" ]] || { fail "versão do painel inesperada"; exit 32; }
ok "Painel XLX026 v1.1.0 aprovado"

section "4/5 — VALIDAÇÃO EXTERNA FINAL"
systemctl is-active --quiet xlxd.service || { fail "xlxd.service não está ativo"; exit 40; }
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || { fail "quantidade final de processos xlxd inválida"; exit 41; }
[[ "$(sha256sum /xlxd/xlxd | awk '{print $1}')" == "$CORE_SHA" ]] || { fail "SHA final mudou"; exit 42; }
[[ "$(xml_version)" == "$EXPECTED_CORE_VERSION" ]] || { fail "XML final mudou"; exit 43; }

PAGES=("/ao-vivo" "/conectados" "/suporte" "/aprs-dprs" "/ranking" "/certificado" "/simulado-anatel/" "/refletores" "/noticias")
for path in "${PAGES[@]}"; do
  body="$OUT/page$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g').html"
  code="$(curl --fail-with-body --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$body" -w '%{http_code}' "$BASE_URL$path")" || { fail "HTTP final falhou em $path"; exit 44; }
  [[ "$code" == "200" ]] || { fail "HTTP final $code em $path"; exit 45; }
  grep -Fq "$PANEL_MARKER" "$body" || { fail "versão do painel ausente em $path"; exit 46; }
  grep -Fq "href=\"$PANEL_SOURCE_URL\"" "$body" || { fail "Código do Painel ausente em $path"; exit 47; }
  grep -Fq "href=\"$INSTALLER_URL\"" "$body" || { fail "Instalador ausente em $path"; exit 48; }
done
ok "9 páginas confirmadas externamente"

section "5/5 — ENCERRAR AGENTE TEMPORÁRIO E MARCAR PROJETO"
systemctl disable xlx026-github-agent.timer 2>/dev/null || true
systemctl disable xlx026-github-executor.path 2>/dev/null || true
systemctl stop xlx026-github-agent.timer xlx026-github-agent.service xlx026-github-executor.path xlx026-github-executor.service 2>/dev/null || true

AGENT_TIMER_ACTIVE="$(systemctl is-active xlx026-github-agent.timer 2>/dev/null || true)"
EXEC_PATH_ACTIVE="$(systemctl is-active xlx026-github-executor.path 2>/dev/null || true)"
[[ "$AGENT_TIMER_ACTIVE" != "active" && "$EXEC_PATH_ACTIVE" != "active" ]] || { fail "agente temporário ainda está ativo"; exit 50; }

cat > "$OUT/PROJECT_COMPLETE" <<EOF
status=PROJECT_COMPLETE
core_version=$EXPECTED_CORE_VERSION
core_sha=$CORE_SHA
panel_version=$EXPECTED_PANEL_VERSION
panel_marker=$PANEL_MARKER
panel_source_url=$PANEL_SOURCE_URL
installer_url=$INSTALLER_URL
pages_validated=9
xlxd_service=ACTIVE
maintenance_agent_timer=$AGENT_TIMER_ACTIVE
maintenance_executor_path=$EXEC_PATH_ACTIVE
core_release_marker=$CORE_MARK
panel_release_marker=$PANEL_COMPLETE
EOF
chmod 600 "$OUT/PROJECT_COMPLETE"
cat "$OUT/PROJECT_COMPLETE"
ok "XLX026 FINALIZADO: CORE 2.6.0 + PAINEL v1.1.0 + AGENTE TEMPORÁRIO DESATIVADO"
