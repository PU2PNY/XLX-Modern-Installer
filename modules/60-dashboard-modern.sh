#!/usr/bin/env bash
set -Eeuo pipefail
# XLX_ERROR_TRACE_V1 — never return silently to the shell on an unexpected failure.
_xlx_error_trace(){
  local rc=$?
  printf '\n[ERROR] file=%s line=%s rc=%s command=%q\n' \
    "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" \
    "${BASH_LINENO[0]:-$LINENO}" "$rc" "$BASH_COMMAND" >&2
  return "$rc"
}
trap _xlx_error_trace ERR
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DASH_DEST="/var/www/html/xlxd"
DASH_DEST="${INSTALL_DIR:-$DEFAULT_DASH_DEST}"
CERT_MODE="${XLX_CERTIFICATES_MODE:-yes}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

say() {
  if [ "$UI_LANG" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}

# When updating an existing installation, preserve the active Apache webroot.
# The standard default remains /var/www/html/xlxd for new installations.
# No alternate historical webroot is assumed or required.
if [ "$DASH_DEST" = "$DEFAULT_DASH_DEST" ] && [ ! -d "$DASH_DEST" ] && [ -d /etc/apache2/sites-enabled ]; then
  detected=""
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate="${candidate%/}"
    if [ -f "$candidate/index.php" ] && { [ -f "$candidate/api/status.php" ] || [ -d "$candidate/api" ]; }; then
      if [ -n "$detected" ] && [ "$detected" != "$candidate" ]; then
        detected=""
        break
      fi
      detected="$candidate"
    fi
  done < <(awk 'tolower($1)=="documentroot" {gsub(/"/,"",$2); print $2}' /etc/apache2/sites-enabled/*.conf 2>/dev/null | sort -u)

  if [ -n "$detected" ]; then
    DASH_DEST="$detected"
    printf '%s\n' "$(say "[INFO] Webroot existente detectado pelo Apache: $DASH_DEST" "[INFO] Existing Apache webroot detected: $DASH_DEST")"
  fi
fi

XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/64-runtime-data.sh"
XLX_UI_LANG="$UI_LANG" INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"
XLX_UI_LANG="$UI_LANG" INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/post-install.sh"
XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/65-callsign-directory.sh"
XLX_DASHBOARD_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/69-admin-page.sh" --dashboard-dir="$DASH_DEST"
XLX_DASHBOARD_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/70-production-parity.sh"

printf '%s\n' "$(say "[INFO] Provisionando Certificados nativos do painel." "[INFO] Provisioning native dashboard Certificates.")"
XLX_DASHBOARD_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/66-certificates.sh" "--dashboard-dir=$DASH_DEST"
