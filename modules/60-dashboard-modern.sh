#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
CERT_MODE="${XLX_CERTIFICATES_MODE:-ask}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

say() {
  if [ "$UI_LANG" = "en" ]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}

# Runtime data is intentionally independent from the legacy dashboard.
# This repairs/installs the callsign database, its daily timer and the
# TX/RX journal bridge before publishing the dashboard itself.
bash "$ROOT/modules/64-runtime-data.sh"

bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"
INSTALL_DIR="$DASH_DEST" bash "$ROOT/dashboard/install/post-install.sh"
bash "$ROOT/modules/65-callsign-directory.sh"

case "${CERT_MODE,,}" in
  yes|sim|s|y|1|true)
    CERT_MODE="yes"
    ;;
  no|nao|não|n|0|false)
    CERT_MODE="no"
    ;;
  ask)
    if [ -t 0 ]; then
      printf '\n%s' "$(say "Instalar também o módulo opcional de Certificados? [s/N]: " "Install the optional Certificate module too? [y/N]: ")"
      read -r answer || answer=""
      case "${answer,,}" in
        s|sim|y|yes) CERT_MODE="yes" ;;
        *) CERT_MODE="no" ;;
      esac
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
  printf '%s\n' "$(say "[INFO] Certificados não serão instalados agora. O módulo pode ser instalado separadamente depois." "[INFO] Certificates will not be installed now. The module can be installed separately later.")"
fi
