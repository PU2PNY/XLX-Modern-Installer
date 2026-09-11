#!/usr/bin/env bash
set -u
umask 077

PYTHON_BIN="${1:?python path required}"
ROOT_DIR="${2:?root path required}"
UI_LOG="${3:?ui log path required}"

cd "$ROOT_DIR" || exit 1
mkdir -p "$(dirname "$UI_LOG")" 2>/dev/null || true
chmod 700 "$(dirname "$UI_LOG")" 2>/dev/null || true

echo "[$(date -Is)] starting beginner UI" >>"$UI_LOG"
"$PYTHON_BIN" "$ROOT_DIR/tui/simple_installer.py" --root "$ROOT_DIR" 2>>"$UI_LOG"
rc=$?

if [ "$rc" -eq 0 ]; then
    echo "[$(date -Is)] beginner UI closed normally" >>"$UI_LOG"
    exit 0
fi

echo "[$(date -Is)] beginner UI exited with rc=$rc; opening compatibility mode" >>"$UI_LOG"
printf '\n[ERRO] A interface visual encontrou uma falha inesperada.\n'
printf '[ATENÇÃO] O erro foi registrado em: %s\n' "$UI_LOG"
printf '[ATENÇÃO] O instalador abrirá automaticamente o modo compatível para não deixar você parado.\n\n'
sleep 2
exec bash "$ROOT_DIR/install.sh" --classic
