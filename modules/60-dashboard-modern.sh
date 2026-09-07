#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DASH_DEST="/var/www/html/xlxd"
DASH_DEST="${INSTALL_DIR:-$DEFAULT_DASH_DEST}"
CERT_MODE="${XLX_CERTIFICATES_MODE:-no}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

say() {
  if [ "$UI_LANG" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}

# When updating an existing installation, preserve the active Apache webroot.
# The standard default remains /var/www/html/xlxd for new installations.
# No legacy xlxd-novo path is assumed or required.
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

# Runtime data is intentionally independent from the legacy dashboard.
bash "$ROOT/modules/64-runtime-data.sh"

INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"
INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/post-install.sh"
bash "$ROOT/modules/65-callsign-directory.sh"

XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/modules/69-admin-page.sh" --dashboard-dir="$DASH_DEST"

case "${CERT_MODE,,}" in
  yes|sim|s|y|1|true) CERT_MODE="yes" ;;
  no|nao|não|n|0|false|"") CERT_MODE="no" ;;
  ask)
    if [ -t 0 ]; then
      printf '\n%s' "$(say "Instalar também o módulo opcional de Certificados? [s/N]: " "Install the optional Certificate module too? [y/N]: ")"
      read -r answer || answer=""
      case "${answer,,}" in s|sim|y|yes) CERT_MODE="yes" ;; *) CERT_MODE="no" ;; esac
    else
      CERT_MODE="no"
    fi
    ;;
  *)
    printf '%s\n' "$(say "[ERRO] XLX_CERTIFICATES_MODE inválido: $CERT_MODE. Use ask, yes ou no." "[ERROR] Invalid XLX_CERTIFICATES_MODE: $CERT_MODE. Use ask, yes, or no.")" >&2
    exit 2
    ;;
esac

if [ "$CERT_MODE" = "yes" ]; then
  printf '%s\n' "$(say "[INFO] Instalando o módulo opcional XLX Certificate Generator." "[INFO] Installing the optional XLX Certificate Generator module.")"
  XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/modules/66-certificates.sh" "--dashboard-dir=$DASH_DEST"
else
  printf '%s\n' "$(say "[INFO] Certificados não fazem parte da instalação pública padrão." "[INFO] Certificates are not part of the standard public installation.")"
fi
