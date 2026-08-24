#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

[[ "$(id -u)" -eq 0 ]] || { echo "[ERRO] execute como root" >&2; exit 1; }

ROOT="/root/backups-xlx026"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/AGENT_BACKUP_${STAMP}"
mkdir -p "$OUT"
chmod 700 "$OUT"

MAN="$OUT/manifest.txt"
: > "$MAN"
for p in \
  /xlxd \
  /usr/src/xlxd \
  /var/www/html/xlxd-novo \
  /etc/systemd/system/xlxd.service \
  /etc/apache2 \
  /etc/nginx \
  /etc/letsencrypt \
  /etc/ufw \
  /etc/fail2ban; do
  [[ -e "$p" ]] && printf '%s\n' "$p" >> "$MAN"
done

[[ -s "$MAN" ]] || { echo "[ERRO] nenhum alvo encontrado" >&2; exit 2; }
ARCH="$OUT/xlx026-backup-${STAMP}.tar.gz"
tar --one-file-system --ignore-failed-read -czpf "$ARCH" -T "$MAN"
gzip -t "$ARCH"
sha256sum "$ARCH" > "$ARCH.sha256"
(cd "$OUT" && sha256sum -c "$(basename "$ARCH.sha256")")
{
  echo "created=$(date --iso-8601=seconds)"
  echo "archive=$ARCH"
  echo "status=OK"
} > "$OUT/COMPLETE"
chmod 600 "$OUT"/*
echo "[OK] backup verificado: $ARCH"
echo "[OK] sha256: $(awk '{print $1}' "$ARCH.sha256")"
