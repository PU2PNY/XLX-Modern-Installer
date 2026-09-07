#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; BLUE=$'\033[1;34m'; RESET=$'\033[0m'
ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
info(){ printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$*"; }
warn(){ printf '%b[ATENCAO]%b %s\n' "$YELLOW" "$RESET" "$*"; }
fail(){ printf '%b[ERRO]%b %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[ "$(id -u)" -eq 0 ] || fail "Execute como root."

ETC="/etc/xlx-aprs-dprs"
OPT="/opt/xlx-aprs-dprs"
UNIT="/etc/systemd/system/xlx-aprs-dprs.service"
MARKER="$ETC/install.env"

[ -f "$MARKER" ] || fail "Instalacao existente nao localizada."
# shellcheck disable=SC1090
source "$MARKER"
DASHBOARD="${DASHBOARD_DIR:-}"
[ -n "$DASHBOARD" ] || fail "DASHBOARD_DIR ausente no marcador."
[ -d "$DASHBOARD/aprs-dprs" ] || fail "Modulo web instalado nao localizado."

for f in \
    "$ROOT/gateway/xlx_aprs_dprs.py" \
    "$ROOT/web/index.php" \
    "$ROOT/web/api/digital-lab.php" \
    "$ROOT/web/api/digital-lab-operator.php" \
    "$ROOT/systemd/xlx-aprs-dprs.service"
do
    [ -f "$f" ] || fail "Arquivo candidato ausente: $f"
done

info "Pre-validando candidato..."
php -l "$ROOT/web/index.php" >/dev/null
php -l "$ROOT/web/digital-lab-native.php" >/dev/null
php -l "$ROOT/web/api/digital-lab.php" >/dev/null
php -l "$ROOT/web/api/digital-lab-operator.php" >/dev/null

python3 - "$ROOT/gateway/xlx_aprs_dprs.py" <<'PY'
import pathlib, sys
src = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
compile(src, sys.argv[1], "exec")
PY

if command -v node >/dev/null 2>&1; then
    node --check "$ROOT/web/assets/digital-lab.js" >/dev/null
    node --check "$ROOT/web/assets/digital-lab-operator.js" >/dev/null
fi

python3 "$ROOT/gateway/xlx_aprs_dprs.py" \
    --config "$ETC/config.json" \
    --check-config

BACKUP_TOOL="$OPT/backup.sh"
[ -x "$BACKUP_TOOL" ] || fail "backup.sh instalado ausente."
BACKUP_ROOT="/root/backups-xlx-aprs-dprs/ANTES_UPDATE_$(date +%Y%m%d_%H%M%S)"
"$BACKUP_TOOL" "$BACKUP_ROOT"
[ -s "$BACKUP_ROOT/xlx-aprs-dprs-backup.tar.gz" ] || fail "Backup previo invalido."

WAS_ACTIVE=0
systemctl is-active --quiet xlx-aprs-dprs.service && WAS_ACTIVE=1 || true

STAGE="$(mktemp -d /root/xlx-aprs-dprs-update.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/web"

cp -a "$ROOT/web/." "$STAGE/web/"
cp -a "$ROOT/gateway/xlx_aprs_dprs.py" "$STAGE/"
cp -a "$ROOT/systemd/xlx-aprs-dprs.service" "$STAGE/"
cp -a "$ROOT/backup.sh" "$STAGE/"

info "Publicando somente codigo; config e bancos serao preservados."

install -o root -g root -m 0755 \
    "$STAGE/xlx_aprs_dprs.py" \
    "$OPT/xlx_aprs_dprs.py"

install -o root -g root -m 0755 \
    "$STAGE/backup.sh" \
    "$OPT/backup.sh"

rsync -a --delete \
    --chown=root:www-data \
    "$STAGE/web/" \
    "$DASHBOARD/aprs-dprs/"

find "$DASHBOARD/aprs-dprs" -type d -exec chmod 0755 {} +
find "$DASHBOARD/aprs-dprs" -type f -name '*.php' -exec chmod 0640 {} +
find "$DASHBOARD/aprs-dprs" -type f ! -name '*.php' -exec chmod 0644 {} +

install -o root -g root -m 0644 \
    "$STAGE/xlx-aprs-dprs.service" \
    "$UNIT"

systemctl daemon-reload

if [ "$WAS_ACTIVE" -eq 1 ]; then
    systemctl restart xlx-aprs-dprs.service
    sleep 1
    systemctl is-active --quiet xlx-aprs-dprs.service \
        || fail "Servico falhou depois da atualizacao. Backup: $BACKUP_ROOT"
fi

php -l "$DASHBOARD/aprs-dprs/index.php" >/dev/null
python3 "$OPT/xlx_aprs_dprs.py" \
    --config "$ETC/config.json" \
    --check-config

ok "Atualizacao concluida."
echo "Backup: $BACKUP_ROOT"
echo "Config e bancos: PRESERVADOS"
echo "STATUS=UPDATE_OK"
