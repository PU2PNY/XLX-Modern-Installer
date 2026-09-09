#!/usr/bin/env bash
set -Eeuo pipefail
# XLX_ERROR_TRACE_V1 — never return silently to the shell on an unexpected failure.
_xlx_error_trace(){
  local rc=$?
  printf '\n[ERROR] file=%s line=%s rc=%s command=%q\n' \
    "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" \
    "${BASH_LINENO[0]:-$LINENO}" "$rc" "$BASH_COMMAND" >&2
  return "$rc"
}
trap _xlx_error_trace ERR
IFS=$'\n\t'; umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
MODE=install
UI_LANG="${XLX_UI_LANG:-pt-BR}"
say(){ [[ "$UI_LANG" == en ]] && printf '%s' "$2" || printf '%s' "$1"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }
for a in "$@"; do case "$a" in --check|--dry-run) MODE=check;; --dashboard-dir=*) DASHBOARD="${a#*=}";; *) fail "$(say "Opção desconhecida: $a" "Unknown option: $a")";; esac; done
[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
NATIVE="$ROOT/dashboard/native/aprs"
for f in "$NATIVE/xlx_aprs_dprs.py" "$NATIVE/init-accounts.php" "$NATIVE/xlx-aprs-dprs.service" "$ROOT/dashboard/api/digital-lab.php" "$ROOT/dashboard/api/digital-lab-operator.php" "$ROOT/dashboard/digital-lab-native.php"; do
  [[ -s "$f" ]] || fail "$(say "Arquivo APRS/D-PRS nativo ausente: $f" "Native APRS/D-PRS file missing: $f")"
done
python3 -m py_compile "$NATIVE/xlx_aprs_dprs.py"
php -l "$NATIVE/init-accounts.php" >/dev/null
php -l "$ROOT/dashboard/api/digital-lab.php" >/dev/null
php -l "$ROOT/dashboard/api/digital-lab-operator.php" >/dev/null
if [[ "$MODE" == check ]]; then
  ok "$(say 'APRS/D-PRS nativo validado; nenhuma alteração feita.' 'Native APRS/D-PRS validated; no changes made.')"
  exit 0
fi
SITE="$DASHBOARD/config/site.php"
[[ -f "$SITE" && -f "$DASHBOARD/digital-lab-native.php" ]] || fail "$(say 'Dashboard nativo APRS/D-PRS incompleto.' 'Native APRS/D-PRS dashboard is incomplete.')"
REF="$(php -r '$c=require $argv[1];echo (string)($c["reflector"]["name"]??"");' "$SITE")"
SYSOP="$(php -r '$c=require $argv[1];echo (string)($c["reflector"]["sysop_callsign"]??"");' "$SITE")"
APRS="$(php -r '$c=require $argv[1];echo (string)($c["radio"]["aprs_service_callsign"]??"");' "$SITE")"
[[ "$REF" =~ ^XLX[A-Z0-9]{3}$ ]] || fail "$(say 'Nome do refletor inválido no site.php.' 'Invalid reflector name in site.php.')"
[[ "$SYSOP" =~ ^[A-Z0-9]{3,8}$ ]] || fail "$(say 'Indicativo do sysop inválido no site.php.' 'Invalid sysop callsign in site.php.')"
[[ "$APRS" =~ ^[A-Z0-9]{3,8}-10$ ]] || fail "$(say 'Indicativo APRS de serviço inválido.' 'Invalid APRS service callsign.')"
install -d -o root -g root -m 0755 /opt/xlx-aprs-dprs
install -d -o root -g www-data -m 0750 /etc/xlx-aprs-dprs
install -d -o www-data -g www-data -m 0750 /var/lib/xlx-aprs-dprs
install -o root -g root -m 0755 "$NATIVE/xlx_aprs_dprs.py" /opt/xlx-aprs-dprs/xlx_aprs_dprs.py
install -o root -g root -m 0644 "$NATIVE/xlx-aprs-dprs.service" /etc/systemd/system/xlx-aprs-dprs.service
python3 - "$REF" "$SYSOP" "$APRS" > /etc/xlx-aprs-dprs/config.json <<'PY'
import json,sys
ref,sysop,aprs=sys.argv[1:]
cfg={
 "database":"/var/lib/xlx-aprs-dprs/digital-lab.sqlite",
 "public_snapshot":"/var/lib/xlx-aprs-dprs/public.json",
 "operator_socket":"/var/lib/xlx-aprs-dprs/operator.sock",
 "retention_days":7,"snapshot_interval":2,
 "reflector":{"enabled":True,"host":"127.0.0.1","port":30001,"module":"B","client_callsign":sysop,"client_module":"G"},
 "aprs":{"enabled":True,"host":"rotate.aprs2.net","port":14580,"login":aprs,"passcode":"auto","filter":"","tx_enabled":True},
 "site":{"title":f"{ref} APRS/D-PRS","reflector":ref,"module":"B"}
}
print(json.dumps(cfg,indent=2,ensure_ascii=False))
PY
chown root:www-data /etc/xlx-aprs-dprs/config.json; chmod 0640 /etc/xlx-aprs-dprs/config.json
/opt/xlx-aprs-dprs/xlx_aprs_dprs.py --config /etc/xlx-aprs-dprs/config.json --check-config >/dev/null
cred="/root/xlx-modern-aprs-admin.txt"
php "$NATIVE/init-accounts.php" /var/lib/xlx-aprs-dprs/accounts.sqlite "$SYSOP" "$cred"
chown www-data:www-data /var/lib/xlx-aprs-dprs/accounts.sqlite; chmod 0640 /var/lib/xlx-aprs-dprs/accounts.sqlite
rm -f /var/lib/xlx-aprs-dprs/accounts.sqlite-wal /var/lib/xlx-aprs-dprs/accounts.sqlite-shm 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now xlx-aprs-dprs.service >/dev/null
systemctl is-active --quiet xlx-aprs-dprs.service || fail "$(say 'Serviço APRS/D-PRS não ficou ativo.' 'APRS/D-PRS service did not become active.')"
runuser -u www-data -- php -r '$db=new PDO("sqlite:".$argv[1]); echo $db->query("PRAGMA integrity_check")->fetchColumn();' /var/lib/xlx-aprs-dprs/accounts.sqlite | grep -qx ok || fail "$(say 'Banco de contas APRS inválido.' 'Invalid APRS accounts database.')"
ok "$(say 'APRS/D-PRS nativo pronto, com cadastro, senha gerada e recuperação por aniversário.' 'Native APRS/D-PRS ready with registration, generated passwords, and birthday recovery.')"
printf 'APRS_SERVICE_CALLSIGN=%s\n' "$APRS"
printf 'APRS_ADMIN_CREDENTIAL=%s\n' "$cred"
