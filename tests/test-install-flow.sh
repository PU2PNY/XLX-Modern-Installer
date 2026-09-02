#!/usr/bin/env bash
# Guardrails for failures reported during clean-server installations.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
CORE_MODULE="$ROOT/modules/40-xlxd.sh"
ECHO_MODULE="$ROOT/modules/50-echo.sh"
PACKAGES_MODULE="$ROOT/modules/30-packages.sh"
DASHBOARD_INSTALLER="$ROOT/dashboard/install/install-dashboard.sh"
I18N_BUILDER="$ROOT/dashboard/i18n/build.php"
STANDBY_CSS="$ROOT/dashboard/assets/ao-vivo-boxes-v31-radar.css"
ADMIN_MODULE="$ROOT/modules/69-admin-page.sh"
ADMIN_BUILDER="$ROOT/modules/68-control-panel.sh"
ACCESS_HELPER="$ROOT/control/xlx-modern-access-helper"
CONTROL_HELPER="$ROOT/control/xlx-modern-control-helper"

failures=0
expect(){
  local description="$1" pattern="$2" file="$3"
  if grep -Fq -- "$pattern" "$file"; then
    printf 'OK | %s\n' "$description"
  else
    printf 'FAIL | %s\n' "$description" >&2
    failures=$((failures+1))
  fi
}

expect 'installer language is selected before installation checks' 'select_ui_language' "$INSTALLER"
expect 'dashboard language is selected independently' 'select_dashboard_language' "$INSTALLER"
expect 'clear final confirmation uses INSTALL' 'readonly CONFIRMATION="INSTALL"' "$INSTALLER"
expect 'confirmation accepts upper or lower case' '[[ "${typed^^}" == "$CONFIRMATION" ]]' "$INSTALLER"
expect 'full install collects reflector data itself' 'collect_configuration' "$INSTALLER"
expect 'full install writes its own state file' 'write_install_state' "$INSTALLER"
expect 'independent package module is executed' 'modules/30-packages.sh" install' "$INSTALLER"
expect 'independent XLXD module is executed' 'modules/40-xlxd.sh" install' "$INSTALLER"
expect 'independent Echo module is executed' 'modules/50-echo.sh" install' "$INSTALLER"
expect 'modern dashboard runs after XLXD core install' 'modules/60-dashboard-modern.sh' "$INSTALLER"
expect 'dashboard-only mode exists' '--dashboard-only' "$INSTALLER"
expect 'dashboard-only explicitly preserves existing core' 'Painel atualizado; núcleo XLXD preservado.' "$INSTALLER"
expect 'pre-check verifies independence' 'tests/test-no-pp5pk-runtime.sh' "$INSTALLER"
expect 'final validation checks XLXD UDP listeners' 'for port in 8880 10001 10002 12345 12346 20001 21110 30001 30051 40000 "$YSF_PORT" 62030' "$INSTALLER"
expect 'final validation checks users database integrity' 'PRAGMA integrity_check;' "$INSTALLER"
expect 'final validation checks hidden Admin route' '/etc/xlx-modern-control/route' "$INSTALLER"
expect 'core comes from official LX3JL repository' 'https://github.com/LX3JL/xlxd.git' "$CORE_MODULE"
expect 'core is pinned to a reviewed commit' 'bf5d0148dbdf2534af129ca3cc034c5051dcfc8d' "$CORE_MODULE"
expect 'core is compiled in foreground for native systemd supervision' '//#define RUN_AS_DAEMON' "$CORE_MODULE"
expect 'core installs its own systemd unit' 'runtime/xlxd.service.in' "$CORE_MODULE"
expect 'core validates one XLXD process' 'pgrep -x xlxd' "$CORE_MODULE"
expect 'Echo uses independent narspt source' 'https://github.com/narspt/XLXEcho.git' "$ECHO_MODULE"
expect 'Echo source is pinned' '8a54cce758cc81ce593822142a32429b07740193' "$ECHO_MODULE"
expect 'Echo preserves native Interlink file' 'xlxd.interlink.before' "$ECHO_MODULE"
expect 'Echo writes native peer format' 'ECHO 127.0.0.1' "$ECHO_MODULE"
expect 'packages module can perform real installation' 'apt-get install -y --no-install-recommends' "$PACKAGES_MODULE"
expect 'dashboard lowercases domain before validation' "tr '[:upper:]' '[:lower:]'" "$DASHBOARD_INSTALLER"
expect 'existing dashboard domain is normalized before certificate detection' 'Normalize legacy values before checking for an existing certificate.' "$DASHBOARD_INSTALLER"
expect 'callinghome client is installed automatically' 'xlx-callinghome.php' "$DASHBOARD_INSTALLER"
expect 'callinghome timer is enabled automatically' 'enable --now xlx-callinghome.timer' "$DASHBOARD_INSTALLER"
expect 'i18n builder processes CSS too' "'css'" "$I18N_BUILDER"
expect 'standby CSS does not force Portuguese text' 'content:none !important;' "$STANDBY_CSS"
expect 'Admin route defaults to admin and can be changed' 'Hidden administrative page name [admin]' "$ADMIN_MODULE"
expect 'Admin defaults to canonical dashboard path' '/var/www/html/xlxd' "$ADMIN_MODULE"
expect 'Admin bootstrap defaults to canonical dashboard path' '/var/www/html/xlxd' "$ADMIN_BUILDER"
expect 'Admin applies peer-based Interlink patch' 'patch-admin-interlink-v2.py' "$ADMIN_MODULE"
expect 'custom Admin slug removes bootstrap route' 'BOOTSTRAP_DIR' "$ADMIN_MODULE"
expect 'Admin sudoers permits Interlink save only through helper' '$HELPER interlink-save *' "$ADMIN_MODULE"
expect 'Admin sudoers permits Interlink delete only through helper' '$HELPER interlink-delete *' "$ADMIN_MODULE"
expect 'Admin no longer depends on xlxd.terminal' '/xlxd/xlxd.interlink' "$ADMIN_BUILDER"
expect 'Access helper preserves peer/address/modules native format' 'peer,address,modules=parts[:3]' "$ACCESS_HELPER"
expect 'Control helper dispatches Interlink save arguments' 'save-interlink "$2" "$3" "$4"' "$CONTROL_HELPER"
expect 'Control helper dispatches Interlink deletion by peer' 'delete-interlink "$2"' "$CONTROL_HELPER"

printf 'failures=%d\n' "$failures"
exit "$failures"
