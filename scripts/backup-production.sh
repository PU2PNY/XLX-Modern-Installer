#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${BACKUP_ROOT:-/var/backups/xlx-reflector}/recovery-$(date +%Y%m%d_%H%M%S).tar.gz"
exec python3 "$ROOT/scripts/backup-production.py" --output "$OUT" "$@"
