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

readonly ECHO_REPOSITORY="https://github.com/narspt/XLXEcho.git"
readonly ECHO_COMMIT="8a54cce758cc81ce593822142a32429b07740193"
SOURCE_DIR="${XLXECHO_SOURCE_DIR:-/usr/src/XLXEcho}"
INSTALL_DIR="${XLX_INSTALL_DIR:-/xlxd}"
BACKUP_ROOT="${XLX_BACKUP_ROOT:-/var/backups/xlx-reflector/echo}"
ENABLE_ECHO="${ENABLE_ECHO:-yes}"
ECHO_MODULE="${ECHO_MODULE:-E}"
INTERLINK="$INSTALL_DIR/xlxd.interlink"

case "${ENABLE_ECHO,,}" in yes|y|sim|s|1|true) ENABLE_ECHO=yes ;; no|n|nao|não|0|false) ENABLE_ECHO=no ;; *) echo "ERROR: invalid ENABLE_ECHO=$ENABLE_ECHO" >&2; exit 2 ;; esac
[[ "$ECHO_MODULE" =~ ^[A-Z]$ ]] || { echo "ERROR: invalid ECHO_MODULE=$ECHO_MODULE" >&2; exit 2; }

if [[ "$MODE" != install ]]; then
  echo "mode=CHECK"
  echo "enabled=$ENABLE_ECHO"
  echo "repository=$ECHO_REPOSITORY"
  echo "commit=$ECHO_COMMIT"
  echo "module=$ECHO_MODULE"
  echo 'changes=NONE'
  echo 'status=CHECK_COMPLETE'
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || { echo 'ERROR: run as root' >&2; exit 1; }
[[ -x "$INSTALL_DIR/xlxd" ]] || { echo 'ERROR: XLXD core must be installed first' >&2; exit 3; }
[[ -f "$INTERLINK" ]] || { echo "ERROR: missing $INTERLINK" >&2; exit 3; }

if [[ "$ENABLE_ECHO" == no ]]; then
  if systemctl list-unit-files xlxecho.service --no-legend 2>/dev/null | grep -q .; then
    systemctl disable --now xlxecho.service >/dev/null 2>&1 || true
  fi
  python3 - "$INTERLINK" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); lines=p.read_text(encoding='utf-8').splitlines(); out=[]
for line in lines:
    stripped=line.strip()
    if stripped and not stripped.startswith('#'):
        parts=[x for x in re.split(r'[\s,]+',stripped) if x]
        if parts and parts[0].upper()=='ECHO':
            out.append('# '+line)
            continue
    out.append(line)
p.write_text('\n'.join(out).rstrip()+'\n',encoding='utf-8')
PY
  echo 'XLXECHO=disabled'
  echo 'status=OK'
  exit 0
fi

for command_name in git gcc python3 systemctl; do command -v "$command_name" >/dev/null 2>&1 || { echo "ERROR: missing command: $command_name" >&2; exit 4; }; done
[[ -f "$ROOT/runtime/xlxecho.service" ]] || { echo 'ERROR: missing runtime/xlxecho.service' >&2; exit 4; }

stamp="$(date +%Y%m%d_%H%M%S)"
backup="$BACKUP_ROOT/$stamp"
install -d -m 0700 "$backup"
cp -a "$INTERLINK" "$backup/xlxd.interlink.before"
[[ -f /etc/systemd/system/xlxecho.service ]] && cp -a /etc/systemd/system/xlxecho.service "$backup/xlxecho.service.before"
[[ -x "$INSTALL_DIR/xlxecho" ]] && cp -a "$INSTALL_DIR/xlxecho" "$backup/xlxecho.before"

if [[ -e "$SOURCE_DIR" ]]; then
  tar -C "$(dirname "$SOURCE_DIR")" -czpf "$backup/source.before.tar.gz" "$(basename "$SOURCE_DIR")"
  rm -rf "$SOURCE_DIR"
fi
install -d -m 0755 "$(dirname "$SOURCE_DIR")"
git init -q "$SOURCE_DIR"
git -C "$SOURCE_DIR" remote add origin "$ECHO_REPOSITORY"
git -C "$SOURCE_DIR" fetch -q --depth 1 origin "$ECHO_COMMIT"
git -C "$SOURCE_DIR" checkout -q --detach FETCH_HEAD
[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$ECHO_COMMIT" ]] || { echo 'ERROR: XLXEcho commit mismatch' >&2; exit 5; }

gcc -std=gnu99 -O2 -Wall -Wextra -o "$SOURCE_DIR/xlxecho" "$SOURCE_DIR/xlxecho.c"
[[ -x "$SOURCE_DIR/xlxecho" ]] || { echo 'ERROR: XLXEcho compilation failed' >&2; exit 5; }
install -o root -g root -m 0755 "$SOURCE_DIR/xlxecho" "$INSTALL_DIR/xlxecho"
install -o root -g root -m 0644 "$ROOT/runtime/xlxecho.service" /etc/systemd/system/xlxecho.service

python3 - "$INTERLINK" "$ECHO_MODULE" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); module=sys.argv[2]
lines=p.read_text(encoding='utf-8').splitlines(); out=[]; replaced=False
for line in lines:
    stripped=line.strip()
    if stripped and not stripped.startswith('#'):
        parts=[x for x in re.split(r'[\s,]+',stripped) if x]
        if parts and parts[0].upper()=='ECHO':
            if replaced:
                continue
            out.append(f'ECHO 127.0.0.1 {module}')
            replaced=True
            continue
    out.append(line)
if not replaced:
    out.append(f'ECHO 127.0.0.1 {module}')
p.write_text('\n'.join(out).rstrip()+'\n',encoding='utf-8')
PY

grep -Fxq "ECHO 127.0.0.1 $ECHO_MODULE" "$INTERLINK" || { cp -a "$backup/xlxd.interlink.before" "$INTERLINK"; echo 'ERROR: ECHO interlink validation failed' >&2; exit 6; }

systemctl daemon-reload
systemctl enable --now xlxecho.service
for _ in $(seq 1 15); do systemctl is-active --quiet xlxecho.service && break; sleep 1; done
systemctl is-active --quiet xlxecho.service || { cp -a "$backup/xlxd.interlink.before" "$INTERLINK"; echo 'ERROR: xlxecho.service did not become active' >&2; exit 7; }

echo "XLXECHO_SOURCE_REPOSITORY=$ECHO_REPOSITORY"
echo "XLXECHO_SOURCE_COMMIT=$ECHO_COMMIT"
echo "XLXECHO_MODULE=$ECHO_MODULE"
echo 'XLXECHO_SERVICE=active'
echo 'status=OK'
