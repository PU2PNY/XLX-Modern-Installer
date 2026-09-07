#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; BLUE=$'\033[1;34m'; RESET=$'\033[0m'
ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
info(){ printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$*"; }
warn(){ printf '%b[ATENCAO]%b %s\n' "$YELLOW" "$RESET" "$*"; }
fail(){ printf '%b[ERRO]%b %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

YES=0
PURGE=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --yes) YES=1; shift ;;
        --purge-data) PURGE=1; shift ;;
        *) fail "Opcao desconhecida: $1" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fail "Execute como root."

ETC="/etc/xlx-aprs-dprs"
OPT="/opt/xlx-aprs-dprs"
STATE="/var/lib/xlx-aprs-dprs"
UNIT="/etc/systemd/system/xlx-aprs-dprs.service"
MARKER="$ETC/install.env"

DASHBOARD=""
if [ -r "$MARKER" ]; then
    # shellcheck disable=SC1090
    source "$MARKER"
    DASHBOARD="${DASHBOARD_DIR:-}"
fi

if [ "$YES" -ne 1 ]; then
    echo "Esta acao remove o codigo e o servico APRS/D-PRS."
    echo "Config e bancos serao PRESERVADOS, salvo com --purge-data."
    read -r -p 'Digite REMOVER_APRS_DPRS para continuar: ' ANSWER
    [ "$ANSWER" = "REMOVER_APRS_DPRS" ] || fail "Cancelado."
fi

[ -x "$OPT/backup.sh" ] || fail "backup.sh instalado ausente; remocao abortada."
BACKUP_ROOT="/root/backups-xlx-aprs-dprs/ANTES_UNINSTALL_$(date +%Y%m%d_%H%M%S)"
"$OPT/backup.sh" "$BACKUP_ROOT"
[ -s "$BACKUP_ROOT/xlx-aprs-dprs-backup.tar.gz" ] || fail "Backup previo falhou."

info "Parando e desabilitando somente xlx-aprs-dprs.service..."
systemctl disable --now xlx-aprs-dprs.service 2>/dev/null || true

rm -f "$UNIT"
systemctl daemon-reload

[ -z "$DASHBOARD" ] || rm -rf -- "$DASHBOARD/aprs-dprs"
rm -rf -- "$OPT"

if [ "$PURGE" -eq 1 ]; then
    if [ "$YES" -ne 1 ]; then
        read -r -p 'Digite PURGAR_DADOS_APRS_DPRS para apagar config e bancos: ' PURGE_ANSWER
        [ "$PURGE_ANSWER" = "PURGAR_DADOS_APRS_DPRS" ] || fail "Purge cancelado; codigo ja removido, dados preservados."
    fi
    rm -rf -- "$ETC" "$STATE"
    warn "Config e bancos foram removidos apos backup."
else
    warn "Config e bancos preservados em $ETC e $STATE."
fi

ok "Remocao concluida."
echo "Backup: $BACKUP_ROOT"
echo "STATUS=UNINSTALL_OK"
