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
expect_absent() {
    local description="$1" pattern="$2" file="$3"
    if grep -Fq -- "$pattern" "$file"; then
        printf 'FAIL | %s\n' "$description" >&2
        failures=$((failures + 1))
    else
        printf 'OK | %s\n' "$description"
    fi
}

if grep -Eq 'confirm_real_installation|readonly CONFIRMATION="INSTALL"|type INSTALL|digite INSTALL' "$INSTALLER"; then
    printf 'FAIL | obsolete second INSTALL confirmation still exists\n' >&2
    failures=$((failures + 1))
else
    printf 'OK | reflector review is the single installation confirmation\n'
fi
if grep -Fq 'collect_dashboard_inputs' "$INSTALLER"; then
    printf 'FAIL | additional dashboard questions still exist outside the main reflector questionnaire\n' >&2
    failures=$((failures + 1))
else
    printf 'OK | no additional question block exists after reflector review\n'
fi
expect 'unified questionnaire captures city in base flow' '17. City and state/region shown on the dashboard.' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect 'unified questionnaire captures YSF ID in base flow' '18. YSF reflector ID shown on the dashboard.' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect 'unified questionnaire captures Admin username in base flow' '19. Private Admin username.' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect 'unified questionnaire captures Admin URL in base flow' '20. Private Admin URL name.' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect 'unified questionnaire captures Admin password in base flow' '21. Private Admin password.' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect 'language is selected before installation checks' 'select_ui_language' "$INSTALLER"
expect 'dashboard language is selected before installation checks' 'select_dashboard_language' "$INSTALLER"
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
expect 'dashboard accepts XLX IDs with three alphanumeric characters' '^XLX([A-Z0-9]{3})$' "$DASHBOARD_INSTALLER"
expect 'dashboard only converts fully numeric reflector IDs to decimal short form' 'if [[ "$REFLECTOR_NUMBER" =~ ^[0-9]{3}$ ]]; then' "$DASHBOARD_INSTALLER"
expect 'dashboard keeps alphanumeric reflector IDs as short identifiers' 'REFLECTOR_SHORT_NUMBER="$REFLECTOR_NUMBER"' "$DASHBOARD_INSTALLER"
expect 'generic alphanumeric reflector example is documented' 'examples XLX123 or XLXPNY' "$DASHBOARD_INSTALLER"
expect 'callinghome client is installed automatically' 'xlx-callinghome.php' "$DASHBOARD_INSTALLER"
expect 'callinghome timer is enabled automatically' 'enable --now xlx-callinghome.timer' "$DASHBOARD_INSTALLER"
expect 'i18n builder protects technical identifiers from translation' 'protectTechnical' "$I18N_BUILDER"
expect 'i18n builder protects callable identifiers from translation' 'A-Za-z0-9_$]*(?=\\s*\\()' "$I18N_BUILDER"
expect 'live callsign observer avoids identical text rewrites' 'if (base && raw !== base) el.textContent = base;' "$ROOT/dashboard/assets/ao-vivo-authorized-sync-v1.js"
expect 'standby CSS does not force Portuguese text' 'content:none !important;' "$STANDBY_CSS"
expect 'Admin route defaults to admin and can be changed' 'Hidden administrative page name [admin]' "$ADMIN_MODULE"
expect 'Admin installation passes the selected language to its builder' 'XLX_UI_LANG="$UI_LANG"' "$ADMIN_MODULE"
expect 'Admin source is localized for English installations' 'usage: build-admin.py INDEX.php [pt-BR|en]' "$ROOT/control/build-admin.py"
expect 'Admin temporary route uses the safe admin default' '"$BASE_URL/admin/"' "$ADMIN_BUILDER"
expect 'Custom Admin slug removes the bootstrap admin route' 'BOOTSTRAP_DIR' "$ADMIN_MODULE"
expect 'base installer skips mandatory full OS upgrade' 'Full operating-system upgrade skipped by design' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect_absent 'base installer has no active apt full-upgrade' 'apt full-upgrade -y' "$ROOT/vendor/pp5pk-installer/installer.sh"
expect 'HTTPS failure keeps installation available over HTTP' 'installation will continue over HTTP' "$DASHBOARD_INSTALLER"
expect 'HTTPS recovery helper is installed' 'xlx-modern-https-retry' "$DASHBOARD_INSTALLER"
expect 'CallingHome follows actual HTTPS readiness' '[ "$HTTPS_READY" -eq 1 ] && CALLINGHOME_SCHEME="https"' "$DASHBOARD_INSTALLER"
expect 'final validation treats pending HTTPS as warning' 'certificate is still pending' "$INSTALLER"


check_native(){
    local label="$1"; shift
    if "$@"; then printf 'OK | %s\n' "$label"; else printf 'FAIL | %s\n' "$label" >&2; failures=$((failures + 1)); fi
}

if grep -Fq 'id="connectedCards"' "$ROOT/dashboard/index.php"; then
    printf 'FAIL | Connected page still contains summary cards from the merged layout\n' >&2
    failures=$((failures + 1))
else
    printf 'OK | Connected page is table-only like the production reference\n'
fi
python3 - "$ROOT/dashboard/index.php" <<'PYTEST'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
mi=s.index("<?php elseif ($page === 'modulos'): ?>")
ci=s.index("<?php elseif ($page === 'conectados'): ?>")
ri=s.index('id="moduleReferenceRows"',mi,ci)
oi=s.index('id="moduleOverview"',mi,ci)
if not ri < oi:
    raise SystemExit('Modules page order mismatch: access table must precede module cards')
PYTEST
if [ "$?" -eq 0 ]; then printf 'OK | Modules page matches production order: access table before module cards\n'; else failures=$((failures + 1)); fi

check_native 'Certificates are shipped inside dashboard' test -s "$ROOT/dashboard/api/certificado.php"
check_native 'Certificate view is native dashboard route' grep -Fq "require __DIR__.'/certificado-view.php';" "$ROOT/dashboard/index.php"
check_native 'Certificate QR library is native dashboard asset' test -s "$ROOT/dashboard/assets/vendor/qrcode.min.js"
check_native 'Certificate token is HMAC-signed' grep -Fq 'hash_hmac(' "$ROOT/dashboard/lib/certificate-signature.php"
check_native 'Certificate signature comparison is constant-time' grep -Fq 'hash_equals(' "$ROOT/dashboard/lib/certificate-signature.php"
check_native 'Certificate QR points to native dashboard validation route' grep -Fq '?page=certificado&validar=' "$ROOT/dashboard/api/certificado.php"
check_native 'Certificate module does not download external generator' bash -c "! grep -Eq 'github.com|XLX-Certificate-Generator|curl .*cert' '$ROOT/modules/66-certificates.sh'"
check_native 'APRS/D-PRS view is native dashboard route' grep -Fq "require __DIR__.'/digital-lab-native.php';" "$ROOT/dashboard/index.php"
check_native 'APRS account API ships in dashboard' test -s "$ROOT/dashboard/api/digital-lab-operator.php"
check_native 'APRS self-registration is present' grep -Fq "if (\$action === 'register')" "$ROOT/dashboard/api/digital-lab-operator.php"
check_native 'APRS registration requests birthday consent' grep -Fq 'birthday_consent_required' "$ROOT/dashboard/api/digital-lab-operator.php"
check_native 'APRS recovery checks birthday mismatch' grep -Fq 'birthday_mismatch' "$ROOT/dashboard/api/digital-lab-operator.php"
check_native 'APRS password generation is present' grep -Fq '$password = newPassword();' "$ROOT/dashboard/api/digital-lab-operator.php"
check_native 'APRS password storage is hashed' grep -Fq 'passwordHash($password)' "$ROOT/dashboard/api/digital-lab-operator.php"
check_native 'APRS backend ships inside dashboard tree' test -s "$ROOT/dashboard/native/aprs/xlx_aprs_dprs.py"
check_native 'Native backend sources are excluded from webroot' grep -Fq -- "--exclude='native/'" "$ROOT/dashboard/install/install-dashboard.sh"
check_native 'APRS module has no old vendor dependency' bash -c "! grep -Fq 'vendor/xlx-aprs-dprs' '$ROOT/modules/67-aprs-dprs.sh'"
check_native 'APRS/D-PRS cannot be disabled from installer' bash -c "! grep -Fq -- '--without-aprs-dprs' '$ROOT/install.sh'"


if grep -Eq 'REF026|XRF026|DCS026|YSF 72426' "$ROOT/dashboard/assets/app.js"; then
    printf 'FAIL | production reflector identifiers remain hard-coded in public Modules page\n' >&2
    failures=$((failures + 1))
else
    printf 'OK | Modules page identifiers are derived from installation data\n'
fi
expect 'public dashboard uses production 1240px content width' 'width:min(1240px,calc(100% - 32px))' "$ROOT/dashboard/assets/app.css"
expect 'Modules is a standalone navigation item' "'modulos' => 'Módulos'," "$ROOT/dashboard/index.php"
expect 'Connected is a standalone navigation item' "'conectados' => 'Conectados'," "$ROOT/dashboard/index.php"

expect 'live state ignores a single transient missing poll' 'XLXMODERN_LIVE_STABILITY_V1' "$ROOT/dashboard/assets/app.js"
expect 'live end grace prevents false end beep and photo flicker' 'XLXMODERN_LIVE_END_GRACE_MS=900' "$ROOT/dashboard/assets/app.js"
expect 'cached QRZ photo renders without returning to fallback GIF' 'data-qrz-state="photo"' "$ROOT/dashboard/assets/app.js"
expect 'recent mobile visual corrections are shipped' 'mobile-visual-v1.css' "$ROOT/dashboard/index.php"
expect 'legacy-browser fallback is shipped' 'safari9-test.html' "$ROOT/dashboard/index.php"
expect 'accessibility opener uses capture phase for reliable mobile clicks' '  true' "$ROOT/dashboard/assets/xlxmodern-accessibility.js"


check_native 'final validation probes native dashboard routes' grep -Fq "for page in 'ao-vivo' 'conectados' 'modulos' 'digital-lab' 'certificado'" "$ROOT/install.sh"
check_native 'final validation probes native APIs' grep -Fq "for api in 'api/status.php' 'api/live.php' 'api/digital-lab.php'" "$ROOT/install.sh"
check_native 'final validation requires APRS service active' grep -Fq 'xlx-aprs-dprs.service xlx-modern-health-monitor.service' "$ROOT/install.sh"
check_native 'final validation requires private Admin path' grep -Fq 'Private Admin installed at' "$ROOT/install.sh"

printf 'failures=%d\n' "$failures"
exit "$failures"
