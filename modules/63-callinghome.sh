#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${INSTALL_DIR:-/var/www/html/xlxd}"
MODE="install"
UI_LANG="${XLX_UI_LANG:-pt-BR}"

for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) MODE="check" ;;
    --dashboard-dir=*) DASHBOARD_DIR="${arg#*=}" ;;
    *) echo "ERROR: unknown option: $arg" >&2; exit 2 ;;
  esac
done

say(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[%s] %s\n' "$(say 'ATENÇÃO' 'WARNING')" "$*" >&2; }
fail(){ printf '[%s] %s\n' "$(say 'ERRO' 'ERROR')" "$*" >&2; exit 1; }

SITE="$DASHBOARD_DIR/config/site.php"
CONFIG_DIR="/etc/xlx-modern"
CONFIG="$CONFIG_DIR/callinghome.php"
CLIENT="/usr/local/lib/xlx-modern/xlx-callinghome.php"
WRAPPER="/usr/local/sbin/xlx-modern-callinghome"
SERVICE="/etc/systemd/system/xlx-callinghome.service"
TIMER="/etc/systemd/system/xlx-callinghome.timer"
STATE_DIR="/var/lib/xlx-modern-callinghome"
LAST_SUCCESS="$STATE_DIR/last-success"
BACKUP_ROOT="/var/backups/xlx-reflector/callinghome"

SRC_CLIENT="$ROOT/dashboard/install/xlx-callinghome.php"
SRC_WRAPPER="$ROOT/dashboard/install/xlx-callinghome.sh"
SRC_SERVICE="$ROOT/dashboard/install/xlx-callinghome.service"
SRC_TIMER="$ROOT/dashboard/install/xlx-callinghome.timer"

for file in "$SRC_CLIENT" "$SRC_WRAPPER" "$SRC_SERVICE" "$SRC_TIMER"; do
  [[ -f "$file" ]] || fail "$(say "Componente CallingHome ausente: $file" "Missing CallingHome component: $file")"
done
bash -n "$SRC_WRAPPER"
php -l "$SRC_CLIENT" >/dev/null
[[ -f "$SITE" ]] || fail "$(say "Configuração do painel ausente: $SITE" "Dashboard configuration missing: $SITE")"

if [[ "$MODE" == check ]]; then
  grep -Fq 'CALLHOME_OK http=' "$SRC_CLIENT" || fail 'CallingHome success marker missing'
  grep -Fq 'XLX_UPTIME' "$SRC_WRAPPER" || fail 'CallingHome runtime wrapper is incomplete'
  grep -Fq 'ExecStart=/usr/local/sbin/xlx-modern-callinghome' "$SRC_SERVICE" || fail 'CallingHome service does not use the independent wrapper'
  grep -Fq 'OnUnitActiveSec=5min' "$SRC_TIMER" || fail 'CallingHome timer cadence is incorrect'
  ok "$(say 'CallingHome independente aprovado em modo de verificação.' 'Independent CallingHome passed check mode.')"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
for command_name in php runuser systemctl sha256sum pgrep ps flock; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$(say "Comando ausente: $command_name" "Missing command: $command_name")"
done
id www-data >/dev/null 2>&1 || fail 'www-data user is missing'
systemctl is-active --quiet xlxd.service || fail 'xlxd.service is not active'
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || fail 'unexpected xlxd process count'

read_site(){
  php -r '
    $c=require $argv[1];
    $key=explode(".",$argv[2]); $v=$c;
    foreach($key as $part){ if(!is_array($v)||!array_key_exists($part,$v)){exit;} $v=$v[$part]; }
    if(is_scalar($v)) echo (string)$v;
  ' "$SITE" "$1"
}

REFLECTOR_NAME="$(read_site reflector.name)"
DOMAIN="$(read_site reflector.domain)"
COUNTRY="$(read_site reflector.country)"
COMMENT="$(read_site reflector.description)"
[[ "$REFLECTOR_NAME" =~ ^XLX[0-9]{3}$ ]] || fail 'invalid reflector name in dashboard configuration'
[[ -n "$DOMAIN" ]] || fail 'dashboard domain is empty'
[[ -n "$COUNTRY" ]] || fail 'dashboard country is empty'
[[ -n "$COMMENT" ]] || COMMENT="$REFLECTOR_NAME"
DOMAIN="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/*$##')"

CALLINGHOME_HASH="$(php -r '
  $f=$argv[1];
  if(is_file($f)){
    $c=require $f;
    if(is_array($c)&&isset($c["hash"])) echo strtolower(trim((string)$c["hash"]));
  }
' "$CONFIG" 2>/dev/null || true)"

# Migration path: preserve the private hash from the traditional XLX file when
# an existing reflector is moved to the independent Modern CallingHome.
if [[ ! "$CALLINGHOME_HASH" =~ ^[a-f0-9]{32,128}$ && -f /xlxd/callinghome.php ]]; then
  CALLINGHOME_HASH="$(php -r '
    $Hash=""; include $argv[1];
    $v=strtolower(trim((string)$Hash));
    if(preg_match("/^[a-f0-9]{32,128}$/",$v)) echo $v;
  ' /xlxd/callinghome.php 2>/dev/null || true)"
fi
if [[ ! "$CALLINGHOME_HASH" =~ ^[a-f0-9]{32,128}$ ]]; then
  CALLINGHOME_HASH="$(php -r 'echo bin2hex(random_bytes(16));')"
fi
[[ "$CALLINGHOME_HASH" =~ ^[a-f0-9]{32,128}$ ]] || fail 'could not create a valid private CallingHome hash'

SCHEME=http
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  SCHEME=https
fi
DASHBOARD_URL="$SCHEME://$DOMAIN"
COMMENT="${COMMENT:0:100}"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
install -d -m 0700 "$BACKUP"
for item in "$CONFIG" "$CLIENT" "$WRAPPER" "$SERVICE" "$TIMER" "$LAST_SUCCESS"; do
  if [[ -f "$item" ]]; then
    name="$(printf '%s' "$item" | sed 's#^/##; s#/#__#g')"
    cp -a "$item" "$BACKUP/$name.before"
  fi
done

MUTATED=0
SUCCESS=0
rollback(){
  trap - EXIT
  set +e
  warn "$(say 'Falha; restaurando CallingHome anterior.' 'Failure detected; restoring previous CallingHome.')"
  for target in "$CONFIG" "$CLIENT" "$WRAPPER" "$SERVICE" "$TIMER" "$LAST_SUCCESS"; do
    name="$(printf '%s' "$target" | sed 's#^/##; s#/#__#g')"
    if [[ -f "$BACKUP/$name.before" ]]; then
      install -d -m 0755 "$(dirname "$target")"
      cp -a "$BACKUP/$name.before" "$target"
    elif [[ "$target" != "$LAST_SUCCESS" ]]; then
      rm -f "$target"
    fi
  done
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl try-restart xlx-callinghome.timer >/dev/null 2>&1 || true
  exit 90
}
trap 'rc=$?; if [[ $rc -ne 0 && $MUTATED -eq 1 && $SUCCESS -ne 1 ]]; then rollback; fi; exit $rc' EXIT

install -d -m 0750 -o root -g www-data "$CONFIG_DIR"
install -d -m 0755 -o root -g root /usr/local/lib/xlx-modern /usr/local/sbin "$STATE_DIR"
if [[ ! -f "$LAST_SUCCESS" ]]; then
  printf '0\n' > "$LAST_SUCCESS"
fi
chown root:root "$LAST_SUCCESS"
chmod 0644 "$LAST_SUCCESS"

cat > "$CONFIG" <<PHP
<?php
declare(strict_types=1);
return [
    'reflector_name' => '$(printf '%s' "$REFLECTOR_NAME" | sed "s/'/\\\\'/g")',
    'dashboard_url' => '$(printf '%s' "$DASHBOARD_URL" | sed "s/'/\\\\'/g")',
    'country' => '$(printf '%s' "$COUNTRY" | sed "s/'/\\\\'/g")',
    'comment' => '$(printf '%s' "$COMMENT" | sed "s/'/\\\\'/g")',
    'hash' => '$CALLINGHOME_HASH',
    'server_url' => 'http://xlxapi.rlx.lu/api.php',
    'xml_path' => '/var/log/xlxd.xml',
    'interlink_path' => '/xlxd/xlxd.interlink',
];
PHP
chown root:www-data "$CONFIG"
chmod 0640 "$CONFIG"
php -l "$CONFIG" >/dev/null

install -o root -g root -m 0644 "$SRC_CLIENT" "$CLIENT"
install -o root -g root -m 0750 "$SRC_WRAPPER" "$WRAPPER"
install -o root -g root -m 0644 "$SRC_SERVICE" "$SERVICE"
install -o root -g root -m 0644 "$SRC_TIMER" "$TIMER"
MUTATED=1

bash -n "$WRAPPER"
php -l "$CLIENT" >/dev/null
if grep -Fq '/var/www/html' "$WRAPPER" "$CLIENT"; then
  fail "$(say 'CallingHome ainda depende do webroot.' 'CallingHome still depends on the webroot.')"
fi

systemctl daemon-reload
systemctl enable --now xlx-callinghome.timer >/dev/null

INITIAL=accepted
if systemctl start xlx-callinghome.service; then
  LAST="$(tr -dc '0-9' < "$LAST_SUCCESS" || true)"
  [[ "$LAST" =~ ^[0-9]{10}$ ]] || fail 'CallingHome service succeeded without a valid last-success timestamp'
  AGE=$(( $(date +%s) - LAST ))
  [[ "$AGE" -ge 0 && "$AGE" -le 120 ]] || fail 'CallingHome last-success timestamp is not recent'
else
  INITIAL=retry-pending
  warn "$(say 'Diretório XLX não confirmou o registro agora; o timer tentará novamente a cada 5 minutos.' 'The XLX directory did not confirm registration now; the timer will retry every 5 minutes.')"
fi

# Disable only legacy per-reflector CallingHome timers after the independent
# service has been installed. Unit files are retained for rollback/history.
if [[ "$INITIAL" == accepted ]]; then
  while IFS= read -r legacy; do
    unit="$(basename "$legacy")"
    [[ "$unit" == xlx-callinghome.timer ]] && continue
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
  done < <(find /etc/systemd/system -maxdepth 1 -type f -name 'xlx[0-9][0-9][0-9]-callinghome.timer' -print 2>/dev/null)
fi

systemctl is-active --quiet xlx-callinghome.timer || fail 'xlx-callinghome.timer is not active'

SUCCESS=1
MUTATED=0
trap - EXIT
ok "$(say 'CallingHome independente instalado; timer ativo a cada 5 minutos.' 'Independent CallingHome installed; five-minute timer is active.')"
echo "CALLINGHOME_INITIAL=$INITIAL"
echo 'CALLINGHOME_DASHBOARD_DEPENDENCY=no'
echo 'CALLINGHOME_TIMER=active'
echo "CALLINGHOME_BACKUP=$BACKUP"
