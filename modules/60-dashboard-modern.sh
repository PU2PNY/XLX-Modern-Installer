#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
CERT_MODE="${XLX_CERTIFICATES_MODE:-ask}"

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
      printf '\n'
      read -r -p "Instalar também o módulo opcional de Certificados? / Install the optional Certificates module too? [s/y/N]: " answer || answer=""
      case "${answer,,}" in
        s|sim|y|yes) CERT_MODE="yes" ;;
        *) CERT_MODE="no" ;;
      esac
    else
      CERT_MODE="no"
    fi
    ;;
  *)
    echo "[ERRO] XLX_CERTIFICATES_MODE inválido: $CERT_MODE (use ask|yes|no)." >&2
    exit 2
    ;;
esac

if [ "$CERT_MODE" = "yes" ]; then
  echo "[INFO] Instalando XLX Certificate Generator opcional."
  XLX_DASHBOARD_DIR="$DASH_DEST" bash "$ROOT/modules/66-certificates.sh" "--dashboard-dir=$DASH_DEST"
else
  echo "[INFO] Certificados não instalados nesta execução. Instalação individual permanece disponível posteriormente."
fi
