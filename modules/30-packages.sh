#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MODE="${1:-check}"
case "$MODE" in check|dry-run|plan|install) ;; *) echo "ERROR: invalid mode: $MODE" >&2; exit 2;; esac

PACKAGES=(
  apache2
  build-essential
  ca-certificates
  certbot
  curl
  git
  libapache2-mod-php
  php
  php-cli
  php-curl
  php-mbstring
  php-sqlite3
  php-xml
  pv
  rsync
  sqlite3
  sudo
  unzip
  wget
)

if [[ "$MODE" != install ]]; then
  missing=0
  for package in "${PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
      version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
      printf 'INSTALLED | %s | %s\n' "$package" "${version:-unknown}"
    else
      candidate="$(apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
      printf 'MISSING | %s | candidate=%s\n' "$package" "${candidate:-unknown}"
      missing=$((missing+1))
    fi
  done
  echo "missing=$missing"
  echo 'changes=NONE'
  echo 'status=CHECK_COMPLETE'
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || { echo 'ERROR: run as root' >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends "${PACKAGES[@]}"

for command_name in apache2ctl bash curl git make gcc g++ php rsync sqlite3 sudo visudo; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "ERROR: required command missing after package install: $command_name" >&2; exit 3; }
done

echo 'package_installation=OK'
echo 'status=OK'
