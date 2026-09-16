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

# Recovery/dashboard-only runs may arrive here with the final Nginx edge already
# active from an earlier partial pass. install-dashboard.sh intentionally uses
# Apache as its temporary provisioning edge, so both servers must never compete
# for port 80. Keep Nginx serving during runtime preparation, then hand the port
# to Apache immediately before the dashboard installer needs it. If any later
# step in this module fails, restore the previous Nginx edge automatically.
PREVIOUS_NGINX_ACTIVE=0
WEB_EDGE_HANDOFF=0
if systemctl is-active --quiet nginx.service 2>/dev/null; then
  PREVIOUS_NGINX_ACTIVE=1
fi

restore_previous_nginx_on_failure(){
  local rc=$?
  trap - EXIT
  if [[ "$rc" -ne 0 && "$WEB_EDGE_HANDOFF" -eq 1 && "$PREVIOUS_NGINX_ACTIVE" -eq 1 ]]; then
    systemctl stop apache2.service >/dev/null 2>&1 || true
    systemctl start php8.2-fpm.service >/dev/null 2>&1 || true
    if systemctl start nginx.service >/dev/null 2>&1; then
      printf '%s\n' "$(say '[ATENÇÃO] Falha durante a etapa do dashboard; Nginx anterior restaurado automaticamente.' '[WARNING] Dashboard stage failed; previous Nginx edge restored automatically.')" >&2
    else
      printf '%s\n' "$(say '[ERRO] Falha durante a etapa do dashboard e não foi possível restaurar o Nginx automaticamente.' '[ERROR] Dashboard stage failed and the previous Nginx edge could not be restored automatically.')" >&2
    fi
  fi
  exit "$rc"
}
trap restore_previous_nginx_on_failure EXIT

XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/64-runtime-data.sh"

if [[ "$PREVIOUS_NGINX_ACTIVE" -eq 1 ]]; then
  printf '%s\n' "$(say '[INFO] Transferindo temporariamente a porta web do Nginx para o Apache de instalação.' '[INFO] Temporarily handing the web port from Nginx to the provisioning Apache edge.')"
  systemctl stop nginx.service
  WEB_EDGE_HANDOFF=1
fi

XLX_UI_LANG="$UI_LANG" INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"
XLX_UI_LANG="$UI_LANG" INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/post-install.sh"

# Runtime parity is intentionally executed by the top-level installer only
# after the production web edge (Nginx + PHP-FPM), APRS/D-PRS and observability
# are provisioned. Running it here would validate an intermediate Apache state
# left by the upstream base installer rather than the final installation.

XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/65-callsign-directory.sh"
XLX_DASHBOARD_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/69-admin-page.sh" --dashboard-dir="$DASH_DEST"
XLX_DASHBOARD_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/70-production-parity.sh"

printf '%s\n' "$(say "[INFO] Provisionando Certificados nativos do painel." "[INFO] Provisioning native dashboard Certificates.")"
XLX_DASHBOARD_DIR="$DASH_DEST" XLX_UI_LANG="$UI_LANG" bash "$ROOT/modules/66-certificates.sh" "--dashboard-dir=$DASH_DEST"

# Success here intentionally leaves the temporary Apache edge active. The
# top-level installer/recovery immediately runs modules/70-nginx.sh, which
# disables Apache before enabling the final Nginx + PHP-FPM production edge.
WEB_EDGE_HANDOFF=0
trap - EXIT
