#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# Conservative production backup utility.
# It never deletes source files and verifies the resulting archive with SHA-256.

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/xlx-reflector}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_ROOT/manual-$STAMP"
MANIFEST="$OUT/manifest.txt"
ARCHIVE="$OUT/xlx-production-$STAMP.tar.gz"
SHA="$ARCHIVE.sha256"

[ "$(id -u)" -eq 0 ] || {
    echo "Run as root / Execute como root." >&2
    exit 1
}

mkdir -p "$OUT"
chmod 700 "$OUT"
: > "$MANIFEST"

for path in \
    /xlxd \
    /etc/systemd/system/xlxd.service \
    /etc/systemd/system/xlxecho.service \
    /etc/apache2 \
    /etc/ufw \
    /etc/nftables.conf \
    /var/www/html; do
    [ ! -e "$path" ] || printf '%s\n' "$path" >> "$MANIFEST"
done

if [ ! -s "$MANIFEST" ]; then
    echo "ERROR / ERRO: no XLX-related paths found; backup not created." >&2
    exit 2
fi

echo "Backup manifest / Manifesto:"
cat "$MANIFEST"
echo

echo "Creating archive / Criando arquivo: $ARCHIVE"
tar --one-file-system --ignore-failed-read -czpf "$ARCHIVE" -T "$MANIFEST"

gzip -t "$ARCHIVE"
sha256sum "$ARCHIVE" > "$SHA"
(
    cd "$OUT"
    sha256sum -c "$(basename "$SHA")"
)

cat > "$OUT/restore-notes.txt" <<EOF
XLX Modern Installer - backup created at $STAMP
Archive: $ARCHIVE
SHA-256: $SHA

This backup is intentionally not restored automatically.
Restore only after diagnosis and after confirming the target paths.

Este backup não é restaurado automaticamente de propósito.
Restaure somente após diagnóstico e confirmação dos caminhos de destino.
EOF

chmod 600 "$MANIFEST" "$SHA" "$OUT/restore-notes.txt"

echo
echo "[OK] Verified backup / Backup verificado:"
echo "$ARCHIVE"
echo "$SHA"
