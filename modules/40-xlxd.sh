#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-check}"
CONFIG="${2:-}"
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

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
valid(){ [[ "$1" =~ $2 ]]; }

valid "$REFLECTOR_NAME" '^XLX[A-Z0-9]{3}$' || fail "invalid reflector name: $REFLECTOR_NAME"
[[ "$MODULE_COUNT" =~ ^[0-9]+$ && "$MODULE_COUNT" -ge 1 && "$MODULE_COUNT" -le 26 ]] || fail "invalid module count: $MODULE_COUNT"
[[ "$YSF_PORT" =~ ^[0-9]+$ && "$YSF_PORT" -ge 1 && "$YSF_PORT" -le 65535 ]] || fail "invalid YSF port: $YSF_PORT"
[[ "$YSF_FREQUENCY" =~ ^[0-9]{9}$ ]] || fail "invalid YSF frequency: $YSF_FREQUENCY"
[[ "$YSF_AUTOLINK" == 0 || "$YSF_AUTOLINK" == 1 ]] || fail "invalid YSF auto-link flag: $YSF_AUTOLINK"
[[ "$YSF_AUTOLINK_MODULE" =~ ^[A-Z]$ ]] || fail "invalid YSF auto-link module: $YSF_AUTOLINK_MODULE"
[[ "$LISTEN_IP" =~ ^[0-9a-fA-F:.]+$ ]] || fail "invalid listen IP: $LISTEN_IP"

module_index=$(( $(printf '%d' "'$YSF_AUTOLINK_MODULE") - 64 ))
if [[ "$YSF_AUTOLINK" == 1 && ( "$module_index" -lt 1 || "$module_index" -gt "$MODULE_COUNT" ) ]]; then
  fail "YSF auto-link module $YSF_AUTOLINK_MODULE is outside configured modules A-$(printf "\\$(printf '%03o' $((64+MODULE_COUNT)))")"
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

[[ "$(id -u)" -eq 0 ]] || fail 'run as root'
for command_name in git python3 make g++ systemctl install sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done
[[ -f "$ROOT/runtime/xlxd.service.in" ]] || fail 'missing runtime/xlxd.service.in'

stamp="$(date +%Y%m%d_%H%M%S)"
backup="$BACKUP_ROOT/$stamp"
work="$(mktemp -d /tmp/xlx-modern-core.XXXXXX)"
cleanup(){ rm -rf "$work"; }
trap cleanup EXIT
install -d -m 0700 "$backup"

if [[ -e "$SOURCE_DIR" ]]; then
  tar -C "$(dirname "$SOURCE_DIR")" -czpf "$backup/source.before.tar.gz" "$(basename "$SOURCE_DIR")"
  rm -rf "$SOURCE_DIR"
fi
if [[ -e "$INSTALL_DIR" ]]; then
  tar -C "$(dirname "$INSTALL_DIR")" -czpf "$backup/runtime.before.tar.gz" "$(basename "$INSTALL_DIR")"
fi
if [[ -f /etc/systemd/system/xlxd.service ]]; then
  cp -a /etc/systemd/system/xlxd.service "$backup/xlxd.service.before"
fi

install -d -m 0755 "$(dirname "$SOURCE_DIR")"
git init -q "$SOURCE_DIR"
git -C "$SOURCE_DIR" remote add origin "$XLXD_REPOSITORY"
git -C "$SOURCE_DIR" fetch -q --depth 1 origin "$XLXD_COMMIT"
git -C "$SOURCE_DIR" checkout -q --detach FETCH_HEAD
actual_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
[[ "$actual_commit" == "$XLXD_COMMIT" ]] || fail "XLXD commit mismatch: $actual_commit"

python3 - "$SOURCE_DIR/src/main.h" "$MODULE_COUNT" "$YSF_PORT" "$YSF_FREQUENCY" "$YSF_AUTOLINK" "$YSF_AUTOLINK_MODULE" <<'PY'
from pathlib import Path
import re,sys
path=Path(sys.argv[1])
modules,port,freq,autolink,automodule=sys.argv[2:]
s=path.read_text(encoding='utf-8')
def sub(pattern,repl,label):
    global s
    s2,n=re.subn(pattern,repl,s,count=1,flags=re.M)
    if n!=1:
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

grep -Fq '//#define RUN_AS_DAEMON' "$SOURCE_DIR/src/main.h" || fail 'foreground/systemd mode was not configured'
grep -Eq "^#define NB_OF_MODULES[[:space:]]+$MODULE_COUNT$" "$SOURCE_DIR/src/main.h" || fail 'module patch validation failed'

make -C "$SOURCE_DIR/src" clean
make -C "$SOURCE_DIR/src" -j"$(nproc)"
[[ -x "$SOURCE_DIR/src/xlxd" ]] || fail 'compiled xlxd binary missing'
sha256sum "$SOURCE_DIR/src/xlxd" > "$backup/xlxd.compiled.sha256"
make -C "$SOURCE_DIR/src" install
[[ -x "$INSTALL_DIR/xlxd" ]] || fail 'installed /xlxd/xlxd missing'

modules="$(python3 - "$MODULE_COUNT" <<'PY'
import sys
n=int(sys.argv[1]); print(''.join(chr(65+i) for i in range(n)))
PY
)"
terminal="$INSTALL_DIR/xlxd.terminal"
[[ -f "$terminal" ]] || fail 'xlxd.terminal missing after install'
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
if public and public!='0.0.0.0': out.append(f'address {public}')
out.append(f'modules {modules}')
path.write_text('\n'.join(out).rstrip()+'\n',encoding='utf-8')
PY

python3 - "$ROOT/runtime/xlxd.service.in" "$work/xlxd.service" "$REFLECTOR_NAME" "$LISTEN_IP" <<'PY'
from pathlib import Path
import sys
src,dst,name,ip=sys.argv[1:]
s=Path(src).read_text(encoding='utf-8')
s=s.replace('{{REFLECTOR_NAME}}',name).replace('{{LISTEN_IP}}',ip)
if '{{' in s: raise SystemExit('unrendered service placeholder')
Path(dst).write_text(s,encoding='utf-8')
PY
install -o root -g root -m 0644 "$work/xlxd.service" /etc/systemd/system/xlxd.service
install -o root -g root -m 0644 /dev/null /var/log/xlxd.xml
systemctl daemon-reload
systemctl enable --now xlxd.service

for _ in $(seq 1 30); do
  systemctl is-active --quiet xlxd.service && [[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] && break
  sleep 1
done
systemctl is-active --quiet xlxd.service || fail 'xlxd.service did not become active'
[[ "$(pgrep -x xlxd | wc -l)" -eq 1 ]] || fail 'unexpected XLXD process count'

for port in 10001 10002 8880 62030 "$YSF_PORT"; do
  ss -H -lunp 2>/dev/null | grep -E "[:.]${port}[[:space:]].*xlxd" >/dev/null || fail "XLXD UDP listener missing: $port"
done

sha256sum "$INSTALL_DIR/xlxd" > "$backup/xlxd.installed.sha256"
echo "XLXD_SOURCE_REPOSITORY=$XLXD_REPOSITORY"
echo "XLXD_SOURCE_COMMIT=$XLXD_COMMIT"
echo "XLXD_BINARY_SHA256=$(sha256sum "$INSTALL_DIR/xlxd" | awk '{print $1}')"
echo "XLXD_MODULES=$modules"
echo 'XLXD_SERVICE=active'
echo 'status=OK'
