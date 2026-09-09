#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'; umask 027
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
MODE=install
for a in "$@";do case "$a" in --check|--dry-run)MODE=check;;--dashboard-dir=*)DASH="${a#*=}";;*)echo "[ERROR] unknown option: $a" >&2;exit 2;;esac;done
say(){ [[ "$UI_LANG" == en ]]&&printf '%s' "$2"||printf '%s' "$1"; }
ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2;exit 1; }
[[ "$(id -u)" -eq 0 ]]||fail "$(say 'Execute como root.' 'Run as root.')"
for c in python3 php install systemctl sha256sum timeout;do command -v "$c" >/dev/null||fail "$(say "Comando ausente: $c" "Missing command: $c")";done
for f in observability/health/health_monitor.py observability/dmr-data/monitor.py observability/dmr-data/dmr_bptc_decode observability/dmr-meta/monitor.py observability/ysf-data/monitor.py observability/ysf-data/ysf_decode observability/history/history-collector.php observability/self-test/regression-self-test;do [[ -f "$ROOT/$f" ]]||fail "$(say "Arquivo ausente: $f" "Missing file: $f")";done
python3 -m py_compile "$ROOT/observability/health/health_monitor.py" "$ROOT/observability/dmr-data/monitor.py" "$ROOT/observability/dmr-meta/monitor.py" "$ROOT/observability/ysf-data/monitor.py"
php -l "$ROOT/observability/history/history-collector.php" >/dev/null
bash -n "$ROOT/observability/self-test/regression-self-test"
file "$ROOT/observability/dmr-data/dmr_bptc_decode" "$ROOT/observability/ysf-data/ysf_decode" | grep -q 'x86-64' || fail "$(say 'Helpers de protocolo incompatíveis; requer Debian 12 x86_64.' 'Protocol helpers incompatible; Debian 12 x86_64 required.')"
[[ "$MODE" == check ]]&&{ ok "$(say 'Observabilidade validada; nenhuma alteração feita.' 'Observability validated; no changes made.')";exit 0; }
[[ -f "$DASH/config/site.php" ]]||fail "$(say 'Configuração do painel ausente.' 'Dashboard configuration missing.')"
DOMAIN="$(php -r '$c=require $argv[1];echo strtolower((string)($c["reflector"]["domain"]??""));' "$DASH/config/site.php")"
TIMEZONE="$(php -r '$c=require $argv[1];echo (string)($c["timezone"]??"UTC");' "$DASH/config/site.php")"
MODULE_COUNT="$(php -r '$c=require $argv[1];echo (int)($c["radio"]["module_count"]??5);' "$DASH/config/site.php")"
[[ -f "/usr/share/zoneinfo/$TIMEZONE" || "$TIMEZONE" == UTC ]] || TIMEZONE=UTC
[[ "$MODULE_COUNT" =~ ^[0-9]+$ && "$MODULE_COUNT" -ge 1 && "$MODULE_COUNT" -le 26 ]] || MODULE_COUNT=5
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]]||fail "$(say 'Domínio do painel inválido.' 'Invalid dashboard domain.')"

# Health must follow the protocol that is actually available now. A requested
# HTTPS certificate can legitimately be pending because of ACME/rate limits.
HEALTH_SCHEME=http
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  HEALTH_SCHEME=https
fi
HEALTH_BASE_URL="$HEALTH_SCHEME://$DOMAIN"

# Install versioned application files.
install -d -m 0755 /opt/xlx-modern-health-monitor /opt/xlx-modern-dmr-data-monitor /opt/xlx-modern-dmr-meta-monitor /opt/xlx-modern-ysf-data-monitor /usr/local/lib/xlx-modern
install -m 0755 "$ROOT/observability/health/health_monitor.py" /opt/xlx-modern-health-monitor/health_monitor.py
install -m 0755 "$ROOT/observability/dmr-data/monitor.py" /opt/xlx-modern-dmr-data-monitor/monitor.py
install -m 0755 "$ROOT/observability/dmr-data/dmr_bptc_decode" /opt/xlx-modern-dmr-data-monitor/dmr_bptc_decode
install -m 0755 "$ROOT/observability/dmr-meta/monitor.py" /opt/xlx-modern-dmr-meta-monitor/monitor.py
install -m 0755 "$ROOT/observability/ysf-data/monitor.py" /opt/xlx-modern-ysf-data-monitor/monitor.py
install -m 0755 "$ROOT/observability/ysf-data/ysf_decode" /opt/xlx-modern-ysf-data-monitor/ysf_decode
install -m 0644 "$ROOT/observability/history/history-collector.php" /usr/local/lib/xlx-modern/history-collector.php
install -m 0755 "$ROOT/observability/self-test/regression-self-test" /usr/local/sbin/xlx-modern-regression-self-test

install -d -o www-data -g www-data -m 0750 /var/lib/xlx-modern-dmr-data /var/lib/xlx-modern-dmr-meta /var/lib/xlx-modern-history
install -d -o root -g www-data -m 0750 /var/lib/xlx-modern-health-monitor /var/lib/xlx-modern-self-test
install -d -o root -g root -m 0750 /etc/xlx-modern-health
python3 - "$DOMAIN" "$DASH" "$TIMEZONE" "$MODULE_COUNT" "$HEALTH_BASE_URL" > /etc/xlx-modern-health/config.json <<'PY'
import json,sys
print(json.dumps({'domain':sys.argv[1],'base_url':sys.argv[5],'dashboard_dir':sys.argv[2],'timezone':sys.argv[3],'module_count':int(sys.argv[4])},indent=2))
PY
chmod 0644 /etc/xlx-modern-health/config.json

cat >/etc/systemd/system/xlx-modern-dmr-data-monitor.service <<'UNIT'
[Unit]
Description=XLX Modern DMR GPS/Talker Alias/Data Passive Monitor
After=network-online.target xlxd.service xlx-aprs-dprs.service
Wants=network-online.target
[Service]
Type=simple
User=www-data
Group=www-data
ExecStart=/usr/bin/python3 /opt/xlx-modern-dmr-data-monitor/monitor.py
Restart=on-failure
RestartSec=3
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=-/xlxd/dmrid.dat
ReadWritePaths=/var/lib/xlx-modern-dmr-data /var/lib/xlx-aprs-dprs
MemoryMax=128M
[Install]
WantedBy=multi-user.target
UNIT
cat >/etc/systemd/system/xlx-modern-dmr-meta-monitor.service <<'UNIT'
[Unit]
Description=XLX Modern MMDVM RPTC Metadata Passive Monitor
After=network-online.target xlxd.service
Wants=network-online.target
[Service]
Type=simple
User=www-data
Group=www-data
ExecStart=/usr/bin/python3 /opt/xlx-modern-dmr-meta-monitor/monitor.py
Restart=on-failure
RestartSec=3
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/xlx-modern-dmr-meta
MemoryMax=64M
[Install]
WantedBy=multi-user.target
UNIT
cat >/etc/systemd/system/xlx-modern-ysf-data-monitor.service <<'UNIT'
[Unit]
Description=XLX Modern YSF GPS/Data Passive Monitor
After=network-online.target xlxd.service xlx-aprs-dprs.service
Wants=network-online.target
[Service]
Type=simple
User=www-data
Group=www-data
ExecStart=/usr/bin/python3 /opt/xlx-modern-ysf-data-monitor/monitor.py
Restart=on-failure
RestartSec=3
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/xlx-aprs-dprs
MemoryMax=96M
[Install]
WantedBy=multi-user.target
UNIT
cat >/etc/systemd/system/xlx-modern-history-collector.service <<EOF2
[Unit]
Description=XLX Modern history collector
After=xlxd.service
[Service]
Type=oneshot
User=www-data
Group=www-data
Environment=XLX_DASHBOARD_DIR=$DASH
ExecStart=/usr/bin/php /usr/local/lib/xlx-modern/history-collector.php
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/xlx-modern-history
ReadOnlyPaths=/var/log /xlxd $DASH
EOF2
cat >/etc/systemd/system/xlx-modern-history-collector.timer <<'UNIT'
[Unit]
Description=Collect XLX Modern history every 5 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
RandomizedDelaySec=15s
Persistent=true
Unit=xlx-modern-history-collector.service
[Install]
WantedBy=timers.target
UNIT
cat >/etc/systemd/system/xlx-modern-regression-self-test.service <<'UNIT'
[Unit]
Description=XLX Modern Regression Self-Test
After=network-online.target apache2.service xlxd.service
Wants=network-online.target
[Service]
Type=oneshot
User=root
Group=root
ExecStart=/usr/local/sbin/xlx-modern-regression-self-test
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/xlx-modern-self-test
ReadOnlyPaths=/etc/xlx-modern-health
TimeoutStartSec=90
UNIT
cat >/etc/systemd/system/xlx-modern-regression-self-test.timer <<'UNIT'
[Unit]
Description=Run XLX Modern Regression Self-Test every 15 minutes
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
AccuracySec=30s
RandomizedDelaySec=20s
Persistent=true
Unit=xlx-modern-regression-self-test.service
[Install]
WantedBy=timers.target
UNIT
cat >/etc/systemd/system/xlx-modern-health-monitor.service <<'UNIT'
[Unit]
Description=XLX Modern Operational Health Monitor
After=network-online.target xlxd.service
Wants=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/xlx-modern-health-monitor/health_monitor.py
Restart=always
RestartSec=10
User=root
Group=root
SupplementaryGroups=www-data
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
CapabilityBoundingSet=
ReadOnlyPaths=/etc/xlx-modern-health /xlxd /var/log /var/lib/xlx-modern-dmr-meta /var/lib/xlx-modern-dmr-data /var/lib/xlx-aprs-dprs /var/lib/xlx-modern-history
ReadWritePaths=/var/lib/xlx-modern-health-monitor
MemoryHigh=80M
MemoryMax=120M
CPUQuota=20%
TasksMax=30
[Install]
WantedBy=multi-user.target
UNIT
systemd-analyze verify /etc/systemd/system/xlx-modern-*.service /etc/systemd/system/xlx-modern-*.timer >/dev/null
systemctl daemon-reload

# Start dependencies first. The Health snapshot is produced synchronously below
# so installation readiness does not depend on a race with a background cycle.
systemctl enable --now xlx-modern-dmr-data-monitor.service xlx-modern-dmr-meta-monitor.service xlx-modern-ysf-data-monitor.service xlx-modern-history-collector.timer xlx-modern-regression-self-test.timer >/dev/null
systemctl start xlx-modern-history-collector.service || true
for u in xlx-modern-dmr-data-monitor.service xlx-modern-dmr-meta-monitor.service xlx-modern-ysf-data-monitor.service xlx-modern-history-collector.timer xlx-modern-regression-self-test.timer;do systemctl is-active --quiet "$u"||fail "$(say "Serviço/timer inativo: $u" "Inactive service/timer: $u")";done

rm -f /var/lib/xlx-modern-health-monitor/operational.json.tmp
if ! timeout 90 /usr/bin/python3 /opt/xlx-modern-health-monitor/health_monitor.py --test; then
  fail "$(say 'Health bootstrap síncrono falhou.' 'Synchronous Health bootstrap failed.')"
fi
[[ -s /var/lib/xlx-modern-health-monitor/operational.json ]]||fail "$(say 'Health snapshot não foi criado no bootstrap síncrono.' 'Health snapshot was not created by the synchronous bootstrap.')"

systemctl enable --now xlx-modern-health-monitor.service >/dev/null
systemctl is-active --quiet xlx-modern-health-monitor.service||fail "$(say 'Serviço Health inativo após bootstrap.' 'Health service inactive after bootstrap.')"
ok "$(say "Health, DMR, YSF, histórico e Self-Test instalados; Health usando $HEALTH_BASE_URL." "Health, DMR, YSF, history and Self-Test installed; Health using $HEALTH_BASE_URL.")"
