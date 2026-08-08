#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-dry-run}"
case "$MODE" in dry-run|plan) ;; *) echo "ERROR: package installation is blocked in this development build." >&2; exit 20;; esac
PACKAGES=(apache2 build-essential ca-certificates certbot curl git libapache2-mod-php libjson-c-dev libsqlite3-dev libssl-dev nftables php php-cli php-curl php-mbstring php-sqlite3 pv unzip wget zip)
echo "mode=DRY_RUN"
echo "package_installation=BLOCKED"
missing=0; installed=0
for package in "${PACKAGES[@]}"; do
  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
    version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"; echo "INSTALLED | $package | ${version:-unknown}"; installed=$((installed+1))
  else
    candidate="$(apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"; echo "MISSING | $package | candidate=${candidate:-unknown}"; missing=$((missing+1))
  fi
done
echo "installed=$installed"
echo "missing=$missing"
echo "changes=NONE"
echo "status=PLAN_VALIDATED"
