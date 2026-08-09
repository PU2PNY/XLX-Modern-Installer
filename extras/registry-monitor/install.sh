#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="/etc/xlx-registry-monitor"
DATA_DIR="/var/lib/xlx-registry-monitor"
LIB_DIR="/usr/local/lib/xlx-registry-monitor"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_USER="xlxmonitor"
MODE="install"
LANG_CODE=""
DOMAIN=""
YSF_ID=""
SLUG=""
YSF_PORT="42000"

for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) MODE="check" ;;
    --lang=*) LANG_CODE="${arg#*=}" ;;
    --domain=*) DOMAIN="${arg#*=}" ;;
    --ysf-id=*) YSF_ID="${arg#*=}" ;;
    --slug=*) SLUG="${arg#*=}" ;;
    --port=*) YSF_PORT="${arg#*=}" ;;
    -h|--help)
      cat <<'HELP'
XLX Registry Monitor installer

Usage:
  sudo bash install.sh --check
  sudo bash install.sh
  sudo bash install.sh --lang=en --domain=xlx.example.net --ysf-id=12345 --slug=ysf-12345-example

Languages: pt-BR en es fr de it
HELP
      exit 0
      ;;
    *) printf 'ERROR: unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

normalize_lang() {
  local raw="${LANG_CODE:-${LANG:-en}}"
  case "$raw" in
    pt*|PT*) LANG_CODE="pt-BR" ;;
    es*|ES*) LANG_CODE="es" ;;
    fr*|FR*) LANG_CODE="fr" ;;
    de*|DE*) LANG_CODE="de" ;;
    it*|IT*) LANG_CODE="it" ;;
    *) LANG_CODE="en" ;;
  esac
}

msg() {
  local key="$1"
  case "${LANG_CODE}:${key}" in
    pt-BR:title) echo "XLX REGISTRY MONITOR — INSTALAÇÃO" ;;
    pt-BR:readonly) echo "Monitor somente leitura: não altera XLXD, firewall, DNS ou registros externos." ;;
    pt-BR:root) echo "Execute este instalador como root." ;;
    pt-BR:check_ok) echo "Pré-validação concluída. Nenhuma alteração foi realizada." ;;
    pt-BR:domain) echo "Domínio/FQDN do refletor" ;;
    pt-BR:ysf) echo "Designador YSF de 5 dígitos" ;;
    pt-BR:slug) echo "Slug YSF no DVRef" ;;
    pt-BR:token) echo "Token DVRef (opcional; ENTER para configurar depois)" ;;
    pt-BR:done) echo "Instalação concluída. O monitor executará a cada 15 minutos." ;;
    pt-BR:status) echo "Status JSON" ;;
    pt-BR:service) echo "Serviço" ;;
    pt-BR:timer) echo "Timer" ;;

    es:title) echo "XLX REGISTRY MONITOR — INSTALACIÓN" ;;
    es:readonly) echo "Monitor de solo lectura: no modifica XLXD, firewall, DNS ni registros externos." ;;
    es:root) echo "Ejecute este instalador como root." ;;
    es:check_ok) echo "Prevalidación completada. No se realizaron cambios." ;;
    es:domain) echo "Dominio/FQDN del reflector" ;;
    es:ysf) echo "Designador YSF de 5 dígitos" ;;
    es:slug) echo "Slug YSF en DVRef" ;;
    es:token) echo "Token DVRef (opcional; ENTER para configurarlo después)" ;;
    es:done) echo "Instalación completada. El monitor se ejecutará cada 15 minutos." ;;
    es:status) echo "JSON de estado" ;;
    es:service) echo "Servicio" ;;
    es:timer) echo "Temporizador" ;;

    fr:title) echo "XLX REGISTRY MONITOR — INSTALLATION" ;;
    fr:readonly) echo "Moniteur en lecture seule : ne modifie ni XLXD, ni pare-feu, ni DNS, ni registre externe." ;;
    fr:root) echo "Exécutez cet installateur en root." ;;
    fr:check_ok) echo "Prévalidation terminée. Aucune modification effectuée." ;;
    fr:domain) echo "Domaine/FQDN du réflecteur" ;;
    fr:ysf) echo "Identifiant YSF à 5 chiffres" ;;
    fr:slug) echo "Slug YSF dans DVRef" ;;
    fr:token) echo "Jeton DVRef (facultatif ; ENTER pour configurer plus tard)" ;;
    fr:done) echo "Installation terminée. Le moniteur s'exécutera toutes les 15 minutes." ;;
    fr:status) echo "JSON d'état" ;;
    fr:service) echo "Service" ;;
    fr:timer) echo "Minuterie" ;;

    de:title) echo "XLX REGISTRY MONITOR — INSTALLATION" ;;
    de:readonly) echo "Nur-Lese-Monitor: ändert weder XLXD noch Firewall, DNS oder externe Register." ;;
    de:root) echo "Führen Sie dieses Installationsprogramm als root aus." ;;
    de:check_ok) echo "Vorprüfung abgeschlossen. Es wurden keine Änderungen vorgenommen." ;;
    de:domain) echo "Domain/FQDN des Reflektors" ;;
    de:ysf) echo "5-stellige YSF-Kennung" ;;
    de:slug) echo "YSF-Slug in DVRef" ;;
    de:token) echo "DVRef-Token (optional; ENTER für spätere Konfiguration)" ;;
    de:done) echo "Installation abgeschlossen. Der Monitor läuft alle 15 Minuten." ;;
    de:status) echo "Status-JSON" ;;
    de:service) echo "Dienst" ;;
    de:timer) echo "Timer" ;;

    it:title) echo "XLX REGISTRY MONITOR — INSTALLAZIONE" ;;
    it:readonly) echo "Monitor di sola lettura: non modifica XLXD, firewall, DNS o registri esterni." ;;
    it:root) echo "Eseguire questo programma di installazione come root." ;;
    it:check_ok) echo "Prevalidazione completata. Nessuna modifica eseguita." ;;
    it:domain) echo "Dominio/FQDN del riflettore" ;;
    it:ysf) echo "Designatore YSF a 5 cifre" ;;
    it:slug) echo "Slug YSF in DVRef" ;;
    it:token) echo "Token DVRef (facoltativo; ENTER per configurarlo in seguito)" ;;
    it:done) echo "Installazione completata. Il monitor verrà eseguito ogni 15 minuti." ;;
    it:status) echo "JSON di stato" ;;
    it:service) echo "Servizio" ;;
    it:timer) echo "Timer" ;;

    *:title) echo "XLX REGISTRY MONITOR — INSTALLATION" ;;
    *:readonly) echo "Read-only monitor: it does not modify XLXD, firewall, DNS, or external registry records." ;;
    *:root) echo "Run this installer as root." ;;
    *:check_ok) echo "Pre-validation completed. No changes were made." ;;
    *:domain) echo "Reflector domain/FQDN" ;;
    *:ysf) echo "5-digit YSF designator" ;;
    *:slug) echo "YSF slug in DVRef" ;;
    *:token) echo "DVRef token (optional; press ENTER to configure later)" ;;
    *:done) echo "Installation completed. The monitor will run every 15 minutes." ;;
    *:status) echo "Status JSON" ;;
    *:service) echo "Service" ;;
    *:timer) echo "Timer" ;;
  esac
}

section() { printf '\n============================================================\n%s\n============================================================\n' "$1"; }
fail() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }
ok() { printf '[OK] %s\n' "$1"; }

validate() {
  [ "$(id -u)" -eq 0 ] || fail "$(msg root)"
  [ -r /etc/os-release ] || fail "/etc/os-release not found"
  # shellcheck disable=SC1091
  source /etc/os-release
  [ "${ID:-}" = "debian" ] || fail "Debian is required"
  command -v python3 >/dev/null 2>&1 || fail "python3 not found"
  command -v systemctl >/dev/null 2>&1 || fail "systemctl not found"
  [ -f "$ROOT/xlx_registry_monitor.py" ] || fail "xlx_registry_monitor.py not found"
  [ -f "$ROOT/systemd/xlx-registry-monitor.service" ] || fail "systemd service not found"
  [ -f "$ROOT/systemd/xlx-registry-monitor.timer" ] || fail "systemd timer not found"
  python3 -m py_compile "$ROOT/xlx_registry_monitor.py"
  bash -n "$0"
  ok "Debian + Python + systemd"
}

prompt_value() {
  local variable="$1" label="$2" value
  if [ -n "${!variable}" ]; then return; fi
  printf '%s: ' "$label"
  read -r value
  printf -v "$variable" '%s' "$value"
}

validate_values() {
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fail "invalid domain"
  [[ "$YSF_ID" =~ ^[0-9]{5}$ ]] || fail "invalid YSF designator"
  [[ "$YSF_PORT" =~ ^[0-9]+$ ]] && [ "$YSF_PORT" -ge 1 ] && [ "$YSF_PORT" -le 65535 ] || fail "invalid UDP port"
  [[ "$SLUG" =~ ^ysf-[a-z0-9-]+$ ]] || fail "invalid DVRef slug"
}

install_files() {
  local token=""
  if ! getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin "$SERVICE_USER"
  fi

  install -d -m 0750 -o root -g "$SERVICE_USER" "$CONF_DIR"
  install -d -m 0750 -o "$SERVICE_USER" -g "$SERVICE_USER" "$DATA_DIR"
  install -d -m 0755 -o root -g root "$LIB_DIR"
  install -m 0755 -o root -g root "$ROOT/xlx_registry_monitor.py" "$LIB_DIR/xlx_registry_monitor.py"

  cat > "$CONF_DIR/config.ini" <<EOF
[reflector]
domain = $DOMAIN
ysf_designator = $YSF_ID
ysf_port = $YSF_PORT
dvref_slug = $SLUG
xlxd_service = xlxd.service

[monitor]
network_timeout_seconds = 5
status_file = $DATA_DIR/status.json
credentials_file = $CONF_DIR/credentials

[dvref]
base_url = https://dvref.com
EOF
  chown root:"$SERVICE_USER" "$CONF_DIR/config.ini"
  chmod 0640 "$CONF_DIR/config.ini"

  printf '%s: ' "$(msg token)"
  read -rs token
  printf '\n'
  if [ -n "$token" ]; then
    printf 'DVREF_TOKEN=%s\n' "$token" > "$CONF_DIR/credentials"
    chown root:"$SERVICE_USER" "$CONF_DIR/credentials"
    chmod 0640 "$CONF_DIR/credentials"
  else
    : > "$CONF_DIR/credentials"
    chown root:"$SERVICE_USER" "$CONF_DIR/credentials"
    chmod 0640 "$CONF_DIR/credentials"
  fi
  token=""

  install -m 0644 "$ROOT/systemd/xlx-registry-monitor.service" "$SYSTEMD_DIR/xlx-registry-monitor.service"
  install -m 0644 "$ROOT/systemd/xlx-registry-monitor.timer" "$SYSTEMD_DIR/xlx-registry-monitor.timer"
  systemctl daemon-reload
  systemctl enable --now xlx-registry-monitor.timer

  set +e
  systemctl start xlx-registry-monitor.service
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    journalctl -u xlx-registry-monitor.service -n 30 --no-pager || true
    fail "initial monitor run failed"
  fi
}

main() {
  normalize_lang
  section "$(msg title)"
  echo "$(msg readonly)"
  validate
  if [ "$MODE" = "check" ]; then
    echo "$(msg check_ok)"
    exit 0
  fi

  prompt_value DOMAIN "$(msg domain)"
  prompt_value YSF_ID "$(msg ysf)"
  prompt_value SLUG "$(msg slug)"
  validate_values
  install_files

  section "$(msg done)"
  printf '%s: %s\n' "$(msg service)" "xlx-registry-monitor.service"
  printf '%s: %s\n' "$(msg timer)" "xlx-registry-monitor.timer"
  printf '%s: %s\n' "$(msg status)" "$DATA_DIR/status.json"
}

main "$@"
