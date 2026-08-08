#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/dashboard/install/install-dashboard.sh" "$@"
bash "$ROOT/dashboard/install/post-install.sh"
