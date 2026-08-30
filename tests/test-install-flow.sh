#!/usr/bin/env bash
# Guardrails for failures reported during clean-server installations.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
DASHBOARD_INSTALLER="$ROOT/dashboard/install/install-dashboard.sh"
I18N_BUILDER="$ROOT/dashboard/i18n/build.php"
STANDBY_CSS="$ROOT/dashboard/assets/ao-vivo-boxes-v31-radar.css"
ADMIN_MODULE="$ROOT/modules/69-admin-page.sh"
ADMIN_BUILDER="$ROOT/modules/68-control-panel.sh"

failures=0
expect() {
    local description="$1" pattern="$2" file="$3"
    if grep -Fq -- "$pattern" "$file"; then
        printf 'OK | %s\n' "$description"
    else
        printf 'FAIL | %s\n' "$description" >&2
        failures=$((failures + 1))
    fi
}

expect 'language is selected before installation checks' 'select_ui_language' "$INSTALLER"
expect 'dashboard language is selected before installation checks' 'select_dashboard_language' "$INSTALLER"
expect 'clear final confirmation uses INSTALL' 'readonly CONFIRMATION="INSTALL"' "$INSTALLER"
expect 'confirmation accepts upper or lower case' '[ "${typed^^}" = "$CONFIRMATION" ]' "$INSTALLER"
expect 'invalid confirmation returns to the same safe prompt' 'tente novamente ou pressione Ctrl+C' "$INSTALLER"
expect 'invalid language selection is retried instead of silently changing language' 'Digite 1 para Português ou 2 para English' "$INSTALLER"
expect 'legacy dashboard section is disabled in runtime copy' 'XLX_MODERN_SKIPPED' "$INSTALLER"
expect 'modern dashboard runs after base XLXD installation' 'modules/60-dashboard-modern.sh' "$INSTALLER"
expect 'dashboard-only mode is documented' '--dashboard-only' "$INSTALLER"
expect 'dashboard-only mode preserves the existing XLXD core' 'Existing XLXD confirmed. Dashboard-only mode will preserve the reflector core.' "$INSTALLER"
expect 'dashboard-only mode validates required panel files' 'Required dashboard file missing after update' "$INSTALLER"
expect 'full installation passes the selected UI language to dashboard modules' 'XLX_INSTALL_STATE_FILE="$state_file" XLX_UI_LANG="$UI_LANG"' "$INSTALLER"
expect 'base inputs are passed to the modern dashboard once' 'XLX_INSTALL_STATE_FILE="$state_file"' "$INSTALLER"
expect 'dashboard lowercases domain before validation' "tr '[:upper:]' '[:lower:]'" "$DASHBOARD_INSTALLER"
expect 'existing dashboard domain is normalized before certificate detection' 'Normalize legacy values before checking for an existing certificate.' "$DASHBOARD_INSTALLER"
expect 'callinghome client is installed automatically' 'xlx-callinghome.php' "$DASHBOARD_INSTALLER"
expect 'callinghome timer is enabled automatically' 'enable --now xlx-callinghome.timer' "$DASHBOARD_INSTALLER"
expect 'i18n builder processes CSS too' "'css'" "$I18N_BUILDER"
expect 'standby CSS does not force Portuguese text' 'content:none !important;' "$STANDBY_CSS"
expect 'Admin route defaults to admin and can be changed' 'Hidden administrative page name [admin]' "$ADMIN_MODULE"
expect 'Admin installation passes the selected language to its builder' 'XLX_UI_LANG="$UI_LANG"' "$ADMIN_MODULE"
expect 'Admin source is localized for English installations' 'genericize-xlx-control.py INDEX.php [locale]' "$ROOT/control/genericize-xlx-control.py"
expect 'Admin temporary route uses the safe admin default' '"$BASE_URL/admin/"' "$ADMIN_BUILDER"
expect 'Custom Admin slug removes the bootstrap admin route' 'BOOTSTRAP_DIR' "$ADMIN_MODULE"

printf 'failures=%d\n' "$failures"
exit "$failures"
