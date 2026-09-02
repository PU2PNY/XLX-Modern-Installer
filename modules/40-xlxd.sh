#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-check}"
CONFIG="${2:-}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
case "$MODE" in check|dry-run|plan|install) ;; *) echo "ERROR: invalid mode: $MODE" >&2; exit 2;; esac
[[ -z "$CONFIG" || -f "$CONFIG" ]] || { echo "ERROR: configuration file not found: $CONFIG" >&2; exit 1; }
[[ -z "$CONFIG" ]] || source "$CONFIG"

readonly XLXD_REPOSITORY="https://github.com/LX3JL/xlxd.git"
readonly XLXD_COMMIT="bf5d0148dbdf2534af129ca3cc034c5051dcfc8d"
SOURCE_DIR="${XLX_SOURCE_DIR:-/usr/src/xlxd}"
INSTALL_DIR="${XLX_INSTALL_DIR:-/xlxd}"
BACKUP_ROOT="${XLX_BACKUP_ROOT:-/var/backups/xlx-reflector/core}"
REFLECTOR_NAME="${REFLECTOR_NAME:-XLX000}"
MODULE_COUNT="${MODULE_COUNT:-5}"
YSF_PORT="${YSF_PORT:-42000}"
YSF_FREQUENCY="${YSF_FREQUENCY:-433125000}"
YSF_AUTOLINK="${YSF_AUTOLINK:-0}"
YSF_AUTOLINK_MODULE="${YSF_AUTOLINK_MODULE:-C}"
LISTEN_IP="${LISTEN_IP:-127.0.0.1}"
PUBLIC_IP="${PUBLIC_IP:-}"
SERVICE_FILE="/etc/systemd/system/xlxd.service"

say(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
info(){ printf '[INFO] %s\n' "$*"; }
ok(){ printf '[OK] %s\n' "$*"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }

[[ "$REFLECTOR_NAME" =~ ^XLX[0-9]{3}$ ]] || fail "$(say "Identificação inválida: $REFLECTOR_NAME" "Invalid reflector identifier: $REFLECTOR_NAME")"
[[ "$MODULE_COUNT" =~ ^[0-9]+$ && "$MODULE_COUNT" -ge 1 && "$MODULE_COUNT" -le 26 ]] || fail "$(say "Quantidade de módulos inválida: $MODULE_COUNT" "Invalid module count: $MODULE_COUNT")"
[[ "$YSF_PORT" =~ ^[0-9]+$ && "$YSF_PORT" -ge 1 && "$YSF_PORT" -le 65535 ]] || fail "$(say "Porta YSF inválida: $YSF_PORT" "Invalid YSF port: $YSF_PORT")"
[[ "$YSF_FREQUENCY" =~ ^[0-9]{9}$ ]] || fail "$(say "Frequência YSF inválida: $YSF_FREQUENCY" "Invalid YSF frequency: $YSF_FREQUENCY")"
[[ "$YSF_AUTOLINK" == 0 || "$YSF_AUTOLINK" == 1 ]] || fail "$(say 'Flag de auto-link YSF inválida.' 'Invalid YSF auto-link flag.')"
[[ "$YSF_AUTOLINK_MODULE" =~ ^[A-Z]$ ]] || fail "$(say 'Módulo de auto-link YSF inválido.' 'Invalid YSF auto-link module.')"
[[ "$LISTEN_IP" =~ ^[0-9a-fA-F:.]+$ ]] || fail "$(say "IP de escuta inválido: $LISTEN_IP" "Invalid listen IP: $LISTEN_IP")"

module_index=$(( $(printf '%d' "'$YSF_AUTOLINK_MODULE") - 64 ))
if [[ "$YSF_AUTOLINK" == 1 && ( "$module_index" -lt 1 || "$module_index" -gt "$MODULE_COUNT" ) ]]; then
  fail "$(say "Módulo YSF $YSF_AUTOLINK_MODULE está fora da quantidade configurada." "YSF module $YSF_AUTOLINK_MODULE is outside the configured module range.")"
fi

if [[ "$MODE" != install ]]; then
  echo "mode=CHECK"
  echo "repository=$XLXD_REPOSITORY"
  echo "commit=$XLXD_COMMIT"
  echo "source_directory=$SOURCE_DIR"
  echo "install_directory=$INSTALL_DIR"
  echo "reflector=$REFLECTOR_NAME"
  echo "modules=$MODULE_COUNT"
  echo "ysf_port=$YSF_PORT"
  echo "ysf_frequency=$YSF_FREQUENCY"
  echo "ysf_autolink=$YSF_AUTOLINK"
  echo "ysf_autolink_module=$YSF_AUTOLINK_MODULE"
  echo "listen_ip=$LISTEN_IP"
  echo 'changes=NONE'
  echo 'status=CHECK_COMPLETE'
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
for command_name in git python3 make g++ systemctl install sha256sum ss pgrep tar; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$(say "Comando ausente: $command_name" "Missing command: $command_name")"
done
[[ -f "$ROOT/runtime/xlxd.service.in" ]] || fail "$(say 'Template runtime/xlxd.service.in ausente.' 'runtime/xlxd.service.in is missing.')"

stamp="$(date +%Y%m%d_%H%M%S)"
backup="$BACKUP_ROOT/$stamp"
work="$(mktemp -d /tmp/xlx-modern-core.XXXXXX)"
source_candidate="$work/source"
service_candidate="$work/xlxd.service"
PRE_SOURCE=0
PRE_RUNTIME=0
PRE_SERVICE=0
PRE_ACTIVE=0
MUTATED=0
SUCCESS=0

[[ -e "$SOURCE_DIR" ]] && PRE_SOURCE=1
[[ -e "$INSTALL_DIR" ]] && PRE_RUNTIME=1
[[ -f "$SERVICE_FILE" ]] && PRE_SERVICE=1
systemctl is-active --quiet xlxd.service 2>/dev/null && PRE_ACTIVE=1 || true

cleanup(){ rm -rf "$work"; }
rollback(){
  local rc="${1:-90}"
  trap - EXIT
  set +e
  printf '[ATENÇÃO] %s\n' "$(say 'Falha detectada; restaurando estado anterior do núcleo XLXD.' 'Failure detected; restoring the previous XLXD core state.')" >&2
  systemctl stop xlxd.service >/dev/null 2>&1 || true

  rm -rf "$INSTALL_DIR"
  if [[ "$PRE_RUNTIME" -eq 1 && -f "$backup/runtime.before.tar.gz" ]]; then
    tar -C "$(dirname "$INSTALL_DIR")" -xzpf "$backup/runtime.before.tar.gz"
  fi

  rm -rf "$SOURCE_DIR"
  if [[ "$PRE_SOURCE" -eq 1 && -f "$backup/source.before.tar.gz" ]]; then
    tar -C "$(dirname "$SOURCE_DIR")" -xzpf "$backup/source.before.tar.gz"
  fi

  if [[ "$PRE_SERVICE" -eq 1 && -f "$backup/xlxd.service.before" ]]; then
    cp -a "$backup/xlxd.service.before" "$SERVICE_FILE"
  else
    rm -f "$SERVICE_FILE"
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  if [[ "$PRE_ACTIVE" -eq 1 && "$PRE_SERVICE" -eq 1 ]]; then
    systemctl start xlxd.service >/dev/null 2>&1 || true
  fi
  cleanup
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "$rc"; else cleanup; fi' EXIT

install -d -m 0700 "$backup"
if [[ "$PRE_SOURCE" -eq 1 ]]; then
  tar -C "$(dirname "$SOURCE_DIR")" -czpf "$backup/source.before.tar.gz" "$(basename "$SOURCE_DIR")"
  sha256sum "$backup/source.before.tar.gz" > "$backup/source.before.tar.gz.sha256"
fi
if [[ "$PRE_RUNTIME" -eq 1 ]]; then
  tar -C "$(dirname "$INSTALL_DIR")" -czpf "$backup/runtime.before.tar.gz" "$(basename "$INSTALL_DIR")"
  sha256sum "$backup/runtime.before.tar.gz" > "$backup/runtime.before.tar.gz.sha256"
fi
[[ "$PRE_SERVICE" -eq 1 ]] && cp -a "$SERVICE_FILE" "$backup/xlxd.service.before"
info "$(say "Backup do núcleo: $backup" "Core backup: $backup")"

# Build completely outside production paths first.
git init -q "$source_candidate"
git -C "$source_candidate" remote add origin "$XLXD_REPOSITORY"
git -C "$source_candidate" fetch -q --depth 1 origin "$XLXD_COMMIT"
git -C "$source_candidate" checkout -q --detach FETCH_HEAD
actual_commit="$(git -C "$source_candidate" rev-parse HEAD)"
[[ "$actual_commit" == "$XLXD_COMMIT" ]] || fail "$(say "Commit XLXD divergente: $actual_commit" "XLXD commit mismatch: $actual_commit")"

python3 - "$source_candidate/src/main.h" "$MODULE_COUNT" "$YSF_PORT" "$YSF_FREQUENCY" "$YSF_AUTOLINK" "$YSF_AUTOLINK_MODULE" <<'PY'
from pathlib import Path
import re,sys
path=Path(sys.argv[1])
modules,port,freq,autolink,automodule=sys.argv[2:]
s=path.read_text(encoding='utf-8')
def sub(pattern,repl,label):
    global s
    s2,n=re.subn(pattern,repl,s,count=1,flags=re.M)
    if n != 1:
        raise SystemExit(f'cannot patch {label}: matches={n}')
    s=s2
sub(r'^#define RUN_AS_DAEMON\s*$', r'//#define RUN_AS_DAEMON', 'RUN_AS_DAEMON')
sub(r'^#define NB_OF_MODULES\s+\d+\s*$', f'#define NB_OF_MODULES                   {modules}', 'NB_OF_MODULES')
sub(r'^#define YSF_PORT\s+\d+.*$', f'#define YSF_PORT                        {port}                               // UDP port', 'YSF_PORT')
sub(r'^#define YSF_DEFAULT_NODE_TX_FREQ\s+\d+.*$', f'#define YSF_DEFAULT_NODE_TX_FREQ        {freq}                           // in Hz', 'YSF TX')
sub(r'^#define YSF_DEFAULT_NODE_RX_FREQ\s+\d+.*$', f'#define YSF_DEFAULT_NODE_RX_FREQ        {freq}                           // in Hz', 'YSF RX')
sub(r'^#define YSF_AUTOLINK_ENABLE\s+\d+.*$', f'#define YSF_AUTOLINK_ENABLE             {autolink}                                   // 1 = enable, 0 = disable auto-link', 'YSF AUTOLINK')
sub(r"^#define YSF_AUTOLINK_MODULE\s+'[A-Z]'.*$", f"#define YSF_AUTOLINK_MODULE             '{automodule}'                                 // module for client to auto-link to", 'YSF AUTOLINK MODULE')
path.write_text(s,encoding='utf-8')
PY

grep -Fqx '//#define RUN_AS_DAEMON' "$source_candidate/src/main.h" || fail "$(say 'Modo foreground para systemd não foi aplicado.' 'Foreground mode for systemd was not applied.')"
grep -Eq "^#define NB_OF_MODULES[[:space:]]+$MODULE_COUNT$" "$source_candidate/src/main.h" || fail "$(say 'Validação da quantidade de módulos falhou.' 'Module-count validation failed.')"
grep -Eq "^#define YSF_PORT[[:space:]]+$YSF_PORT[[:space:]]" "$source_candidate/src/main.h" || fail 'YSF_PORT validation failed'
grep -Eq "^#define YSF_DEFAULT_NODE_TX_FREQ[[:space:]]+$YSF_FREQUENCY[[:space:]]" "$source_candidate/src/main.h" || fail 'YSF TX frequency validation failed'
grep -Eq "^#define YSF_AUTOLINK_ENABLE[[:space:]]+$YSF_AUTOLINK[[:space:]]" "$source_candidate/src/main.h" || fail 'YSF auto-link validation failed'

make -C "$source_candidate/src" clean
make -C "$source_candidate/src" -j"$(nproc)"
[[ -x "$source_candidate/src/xlxd" ]] || fail "$(say 'Binário XLXD compilado não foi encontrado.' 'Compiled XLXD binary was not found.')"
sha256sum "$source_candidate/src/xlxd" > "$backup/xlxd.candidate.sha256"

python3 - "$ROOT/runtime/xlxd.service.in" "$service_candidate" "$REFLECTOR_NAME" "$LISTEN_IP" <<'PY'
from pathlib import Path
import sys
src,dst,name,ip=sys.argv[1:]
s=Path(src).read_text(encoding='utf-8')
s=s.replace('{{REFLECTOR_NAME}}',name).replace('{{LISTEN_IP}}',ip)
if '{{' in s or '}}' in s:
    raise SystemExit('unrendered service placeholder')
Path(dst).write_text(s,encoding='utf-8')
PY

grep -Fqx "ExecStart=/xlxd/xlxd $REFLECTOR_NAME $LISTEN_IP 127.0.0.1" "$service_candidate" || fail "$(say 'ExecStart candidato inválido.' 'Invalid candidate ExecStart.')"

# Production mutation starts only after source/build/service candidates pass.
MUTATED=1
systemctl stop xlxd.service >/dev/null 2>&1 || true
install -d -o root -g root -m 0755 "$INSTALL_DIR"

binary_tmp="$INSTALL_DIR/.xlxd.new.$$"
install -o root -g root -m 0755 "$source_candidate/src/xlxd" "$binary_tmp"
mv -f "$binary_tmp" "$INSTALL_DIR/xlxd"

for cfg in xlxd.blacklist xlxd.whitelist xlxd.interlink xlxd.terminal; do
  upstream="$source_candidate/config/$cfg"
  [[ -f "$upstream" ]] || fail "$(say "Configuração upstream ausente: $cfg" "Upstream configuration missing: $cfg")"
  if [[ -f "$INSTALL_DIR/$cfg" ]]; then
    install -o root -g root -m 0644 "$upstream" "$INSTALL_DIR/$cfg.sample"
  else
    install -o root -g root -m 0644 "$upstream" "$INSTALL_DIR/$cfg"
  fi
done

modules="$(python3 - "$MODULE_COUNT" <<'PY'
import sys
n=int(sys.argv[1]); print(''.join(chr(65+i) for i in range(n)))
PY
)"
terminal="$INSTALL_DIR/xlxd.terminal"
python3 - "$terminal" "$PUBLIC_IP" "$modules" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1]); public=sys.argv[2].strip(); modules=sys.argv[3]
lines=path.read_text(encoding='utf-8').splitlines()
out=[]
for line in lines:
    stripped=line.strip()
    if stripped.startswith('address ') or stripped.startswith('#address '):
        continue
    if stripped.startswith('modules ') or stripped.startswith('#modules '):
        continue
    out.append(line)
if public and public != '0.0.0.0':
    out.append(f'address {public}')
out.append(f'modules {modules}')
path.write_text('\n'.join(out).rstrip()+'\n',encoding='utf-8')
PY

grep -Fxq "modules $modules" "$terminal" || fail "$(say 'Lista de módulos não foi gravada em xlxd.terminal.' 'Module list was not written to xlxd.terminal.')"
if [[ -n "$PUBLIC_IP" && "$PUBLIC_IP" != '0.0.0.0' ]]; then
  grep -Fxq "address $PUBLIC_IP" "$terminal" || fail "$(say 'IP público não foi gravado em xlxd.terminal.' 'Public IP was not written to xlxd.terminal.')"
fi

service_tmp="$SERVICE_FILE.new.$$"
install -o root -g root -m 0644 "$service_candidate" "$service_tmp"
mv -f "$service_tmp" "$SERVICE_FILE"

# Publish the exact audited source tree only after the runtime candidate is ready.
rm -rf "$SOURCE_DIR"
install -d -m 0755 "$(dirname "$SOURCE_DIR")"
mv "$source_candidate" "$SOURCE_DIR"

[[ -e /var/log/xlxd.xml ]] || install -o root -g root -m 0644 /dev/null /var/log/xlxd.xml
chown root:root /var/log/xlxd.xml
chmod 0644 /var/log/xlxd.xml

systemctl daemon-reload
systemctl enable xlxd.service >/dev/null
systemctl start xlxd.service

for _ in $(seq 1 30); do
  if systemctl is-active --quiet xlxd.service && [[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]]; then
    break
  fi
  sleep 1
done
systemctl is-active --quiet xlxd.service || fail "$(say 'xlxd.service não ficou ativo.' 'xlxd.service did not become active.')"
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || fail "$(say 'Quantidade inesperada de processos XLXD.' 'Unexpected XLXD process count.')"

for port in 10001 10002 8880 62030 "$YSF_PORT"; do
  ss -H -lunp 2>/dev/null | grep -E "[:.]${port}[[:space:]].*xlxd" >/dev/null || fail "$(say "Listener UDP XLXD ausente: $port" "Missing XLXD UDP listener: $port")"
done

[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$XLXD_COMMIT" ]] || fail "$(say 'Fonte publicada não corresponde ao commit fixado.' 'Published source does not match the pinned commit.')"
sha256sum "$INSTALL_DIR/xlxd" > "$backup/xlxd.installed.sha256"

SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
ok "$(say 'Núcleo XLXD instalado e validado de forma independente.' 'XLXD core installed and validated independently.')"
echo "XLXD_SOURCE_REPOSITORY=$XLXD_REPOSITORY"
echo "XLXD_SOURCE_COMMIT=$XLXD_COMMIT"
echo "XLXD_BINARY_SHA256=$(sha256sum "$INSTALL_DIR/xlxd" | awk '{print $1}')"
echo "XLXD_MODULES=$modules"
echo 'XLXD_SERVICE=active'
echo 'status=OK'
