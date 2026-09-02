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

readonly ECHO_REPOSITORY="https://github.com/narspt/XLXEcho.git"
readonly ECHO_COMMIT="8a54cce758cc81ce593822142a32429b07740193"
SOURCE_DIR="${XLXECHO_SOURCE_DIR:-/usr/src/XLXEcho}"
INSTALL_DIR="${XLX_INSTALL_DIR:-/xlxd}"
BACKUP_ROOT="${XLX_BACKUP_ROOT:-/var/backups/xlx-reflector/echo}"
ENABLE_ECHO="${ENABLE_ECHO:-yes}"
ECHO_MODULE="${ECHO_MODULE:-E}"
INTERLINK="$INSTALL_DIR/xlxd.interlink"
SERVICE_FILE="/etc/systemd/system/xlxecho.service"
BINARY="$INSTALL_DIR/xlxecho"

say(){ if [[ "$UI_LANG" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
info(){ printf '[INFO] %s\n' "$*"; }
ok(){ printf '[OK] %s\n' "$*"; }
fail(){ printf '[ERRO] %s\n' "$*" >&2; exit 1; }

case "${ENABLE_ECHO,,}" in
  yes|y|sim|s|1|true) ENABLE_ECHO=yes ;;
  no|n|nao|não|0|false) ENABLE_ECHO=no ;;
  *) fail "$(say "ENABLE_ECHO inválido: $ENABLE_ECHO" "Invalid ENABLE_ECHO: $ENABLE_ECHO")" ;;
esac
[[ "$ECHO_MODULE" =~ ^[A-Z]$ ]] || fail "$(say "Módulo Echo inválido: $ECHO_MODULE" "Invalid Echo module: $ECHO_MODULE")"

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

[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
[[ -x "$INSTALL_DIR/xlxd" ]] || fail "$(say 'Instale o núcleo XLXD antes do Echo.' 'Install the XLXD core before Echo.')"
[[ -f "$INTERLINK" ]] || fail "$(say "Arquivo ausente: $INTERLINK" "Missing file: $INTERLINK")"
for command_name in git gcc python3 systemctl install sha256sum tar; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$(say "Comando ausente: $command_name" "Missing command: $command_name")"
done
[[ -f "$ROOT/runtime/xlxecho.service" ]] || fail "$(say 'runtime/xlxecho.service ausente.' 'runtime/xlxecho.service is missing.')"

stamp="$(date +%Y%m%d_%H%M%S)"
backup="$BACKUP_ROOT/$stamp"
work="$(mktemp -d /tmp/xlx-modern-echo.XXXXXX)"
source_candidate="$work/source"
interlink_candidate="$work/xlxd.interlink"
PRE_SOURCE=0
PRE_BINARY=0
PRE_SERVICE=0
PRE_ACTIVE=0
PRE_ENABLED=0
MUTATED=0
SUCCESS=0

[[ -e "$SOURCE_DIR" ]] && PRE_SOURCE=1
[[ -x "$BINARY" ]] && PRE_BINARY=1
[[ -f "$SERVICE_FILE" ]] && PRE_SERVICE=1
systemctl is-active --quiet xlxecho.service 2>/dev/null && PRE_ACTIVE=1 || true
systemctl is-enabled --quiet xlxecho.service 2>/dev/null && PRE_ENABLED=1 || true

cleanup(){ rm -rf "$work"; }
rollback(){
  local rc="${1:-90}"
  trap - EXIT
  set +e
  printf '[ATENÇÃO] %s\n' "$(say 'Falha detectada; restaurando Echo e Interlink anteriores.' 'Failure detected; restoring the previous Echo and Interlink state.')" >&2
  systemctl stop xlxecho.service >/dev/null 2>&1 || true
  cp -a "$backup/xlxd.interlink.before" "$INTERLINK" 2>/dev/null || true

  if [[ "$PRE_BINARY" -eq 1 && -f "$backup/xlxecho.before" ]]; then
    cp -a "$backup/xlxecho.before" "$BINARY"
  else
    rm -f "$BINARY"
  fi

  rm -rf "$SOURCE_DIR"
  if [[ "$PRE_SOURCE" -eq 1 && -f "$backup/source.before.tar.gz" ]]; then
    tar -C "$(dirname "$SOURCE_DIR")" -xzpf "$backup/source.before.tar.gz"
  fi

  if [[ "$PRE_SERVICE" -eq 1 && -f "$backup/xlxecho.service.before" ]]; then
    cp -a "$backup/xlxecho.service.before" "$SERVICE_FILE"
  else
    rm -f "$SERVICE_FILE"
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  if [[ "$PRE_ENABLED" -eq 1 ]]; then
    systemctl enable xlxecho.service >/dev/null 2>&1 || true
  else
    systemctl disable xlxecho.service >/dev/null 2>&1 || true
  fi
  if [[ "$PRE_ACTIVE" -eq 1 && "$PRE_SERVICE" -eq 1 ]]; then
    systemctl start xlxecho.service >/dev/null 2>&1 || true
  fi
  cleanup
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 && $SUCCESS -ne 1 && $MUTATED -eq 1 ]]; then rollback "$rc"; else cleanup; fi' EXIT

install -d -m 0700 "$backup"
cp -a "$INTERLINK" "$backup/xlxd.interlink.before"
sha256sum "$backup/xlxd.interlink.before" > "$backup/xlxd.interlink.before.sha256"
[[ "$PRE_SERVICE" -eq 1 ]] && cp -a "$SERVICE_FILE" "$backup/xlxecho.service.before"
[[ "$PRE_BINARY" -eq 1 ]] && cp -a "$BINARY" "$backup/xlxecho.before"
if [[ "$PRE_SOURCE" -eq 1 ]]; then
  tar -C "$(dirname "$SOURCE_DIR")" -czpf "$backup/source.before.tar.gz" "$(basename "$SOURCE_DIR")"
  sha256sum "$backup/source.before.tar.gz" > "$backup/source.before.tar.gz.sha256"
fi
info "$(say "Backup Echo/Interlink: $backup" "Echo/Interlink backup: $backup")"

cp -a "$INTERLINK" "$interlink_candidate"

if [[ "$ENABLE_ECHO" == no ]]; then
  python3 - "$interlink_candidate" <<'PY'
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

  MUTATED=1
  systemctl disable --now xlxecho.service >/dev/null 2>&1 || true
  interlink_tmp="$INTERLINK.new.$$"
  install -o root -g root -m 0644 "$interlink_candidate" "$interlink_tmp"
  mv -f "$interlink_tmp" "$INTERLINK"
  SUCCESS=1
  MUTATED=0
  trap - EXIT
  cleanup
  ok "$(say 'Echo desativado; Interlink preservado e validado.' 'Echo disabled; Interlink preserved and validated.')"
  echo 'XLXECHO=disabled'
  echo 'status=OK'
  exit 0
fi

# Build outside production first.
git init -q "$source_candidate"
git -C "$source_candidate" remote add origin "$ECHO_REPOSITORY"
git -C "$source_candidate" fetch -q --depth 1 origin "$ECHO_COMMIT"
git -C "$source_candidate" checkout -q --detach FETCH_HEAD
[[ "$(git -C "$source_candidate" rev-parse HEAD)" == "$ECHO_COMMIT" ]] || fail "$(say 'Commit XLXEcho divergente.' 'XLXEcho commit mismatch.')"

gcc -std=gnu99 -O2 -Wall -Wextra -o "$source_candidate/xlxecho" "$source_candidate/xlxecho.c"
[[ -x "$source_candidate/xlxecho" ]] || fail "$(say 'Compilação do XLXEcho falhou.' 'XLXEcho compilation failed.')"
sha256sum "$source_candidate/xlxecho" > "$backup/xlxecho.candidate.sha256"

python3 - "$interlink_candidate" "$ECHO_MODULE" <<'PY'
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

grep -Fxq "ECHO 127.0.0.1 $ECHO_MODULE" "$interlink_candidate" || fail "$(say 'Candidato Interlink do Echo inválido.' 'Invalid Echo Interlink candidate.')"

MUTATED=1
binary_tmp="$BINARY.new.$$"
install -o root -g root -m 0755 "$source_candidate/xlxecho" "$binary_tmp"
mv -f "$binary_tmp" "$BINARY"

interlink_tmp="$INTERLINK.new.$$"
install -o root -g root -m 0644 "$interlink_candidate" "$interlink_tmp"
mv -f "$interlink_tmp" "$INTERLINK"

service_tmp="$SERVICE_FILE.new.$$"
install -o root -g root -m 0644 "$ROOT/runtime/xlxecho.service" "$service_tmp"
mv -f "$service_tmp" "$SERVICE_FILE"

rm -rf "$SOURCE_DIR"
install -d -m 0755 "$(dirname "$SOURCE_DIR")"
mv "$source_candidate" "$SOURCE_DIR"

systemctl daemon-reload
systemctl enable xlxecho.service >/dev/null
systemctl start xlxecho.service
for _ in $(seq 1 15); do
  systemctl is-active --quiet xlxecho.service && break
  sleep 1
done
systemctl is-active --quiet xlxecho.service || fail "$(say 'xlxecho.service não ficou ativo.' 'xlxecho.service did not become active.')"
grep -Fxq "ECHO 127.0.0.1 $ECHO_MODULE" "$INTERLINK" || fail "$(say 'Entrada Echo não permaneceu válida no Interlink.' 'Echo entry did not remain valid in Interlink.')"
[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$ECHO_COMMIT" ]] || fail "$(say 'Fonte Echo publicada não corresponde ao commit fixado.' 'Published Echo source does not match the pinned commit.')"

SUCCESS=1
MUTATED=0
trap - EXIT
cleanup
ok "$(say 'Echo/Parrot instalado de forma independente.' 'Echo/Parrot installed independently.')"
echo "XLXECHO_SOURCE_REPOSITORY=$ECHO_REPOSITORY"
echo "XLXECHO_SOURCE_COMMIT=$ECHO_COMMIT"
echo "XLXECHO_MODULE=$ECHO_MODULE"
echo 'XLXECHO_SERVICE=active'
echo 'status=OK'
