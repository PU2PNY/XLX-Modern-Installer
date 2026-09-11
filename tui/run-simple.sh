#!/usr/bin/env bash
set -u
umask 077

PYTHON_BIN="${1:?python path required}"
ROOT_DIR="${2:?root path required}"
UI_LOG="${3:?ui log path required}"
STATE_DIR="/opt/xlx-modern-installer/runtime"
STATE_FILE="$STATE_DIR/ui-state-$$"

cd "$ROOT_DIR" || exit 1
mkdir -p "$(dirname "$UI_LOG")" "$STATE_DIR" 2>/dev/null || true
chmod 700 "$(dirname "$UI_LOG")" "$STATE_DIR" 2>/dev/null || true
rm -f "$STATE_FILE"
export XLX_UI_STATE_FILE="$STATE_FILE"

echo "[$(date -Is)] starting beginner UI" >>"$UI_LOG"
"$PYTHON_BIN" "$ROOT_DIR/tui/simple_installer.py" --root "$ROOT_DIR" 2>>"$UI_LOG"
rc=$?
state="$(cat "$STATE_FILE" 2>/dev/null || true)"
rm -f "$STATE_FILE"

if [ "$rc" -eq 0 ] && [ "$state" = "USER_CLOSED" ]; then
    echo "[$(date -Is)] beginner UI closed by user" >>"$UI_LOG"
    exit 0
fi

if [ "$rc" -eq 0 ]; then
    echo "[$(date -Is)] beginner UI ended unexpectedly with rc=0 state=${state:-NONE}; opening compatibility mode" >>"$UI_LOG"
else
    echo "[$(date -Is)] beginner UI exited with rc=$rc state=${state:-NONE}; opening compatibility mode" >>"$UI_LOG"
fi

printf '\n[ERRO] A interface visual encerrou antes do esperado.\n'
printf '[ATENÇÃO] O erro foi registrado em: %s\n' "$UI_LOG"
printf '[ATENÇÃO] O instalador abrirá automaticamente o modo compatível para não deixar você parado.\n\n'
sleep 2
exec bash "$ROOT_DIR/install.sh" --classic
