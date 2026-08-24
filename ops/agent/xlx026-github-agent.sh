#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

CONTROL_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/feature/xlx026-maint-20260823/maintenance/control.json"
STATE_DIR="/var/lib/xlx026-github-agent"
RESULT_DIR="$STATE_DIR/results"
LAST_FILE="$STATE_DIR/last_job_id"
TMP="$(mktemp "$STATE_DIR/control.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

mkdir -p "$RESULT_DIR"

curl --fail --silent --show-error --location \
  --connect-timeout 10 --max-time 30 \
  -H 'Accept: application/json' \
  "$CONTROL_URL" -o "$TMP"

PARSED="$(python3 - "$TMP" <<'PY'
import json, re, sys
p=sys.argv[1]
with open(p,'r',encoding='utf-8') as f:
    d=json.load(f)
if d.get('schema') != 1:
    raise SystemExit('invalid schema')
if not isinstance(d.get('enabled'), bool):
    raise SystemExit('enabled must be boolean')
job=d.get('job_id','')
action=d.get('action','')
if not re.fullmatch(r'[A-Za-z0-9._-]{1,80}', job):
    raise SystemExit('invalid job_id')
allowed={'idle','readonly_smoke','backup_only','golden_lab'}
if action not in allowed:
    raise SystemExit('action not allowed')
print('1' if d['enabled'] else '0')
print(job)
print(action)
PY
)" || { echo "[ERRO] control.json inválido" >&2; exit 65; }
mapfile -t FIELDS <<< "$PARSED"
[[ ${#FIELDS[@]} -eq 3 ]] || { echo "[ERRO] resposta de controle inválida" >&2; exit 65; }

ENABLED="${FIELDS[0]}"
JOB_ID="${FIELDS[1]}"
ACTION="${FIELDS[2]}"

[[ "$ENABLED" == "1" ]] || exit 0
[[ "$ACTION" != "idle" ]] || exit 0

LAST=""
[[ -f "$LAST_FILE" ]] && LAST="$(cat "$LAST_FILE" 2>/dev/null || true)"
[[ "$JOB_ID" != "$LAST" ]] || exit 0

LOG="$RESULT_DIR/${JOB_ID}.log"
STATUS="$RESULT_DIR/${JOB_ID}.status"
LATEST="$STATE_DIR/latest.status"
START="$(date --iso-8601=seconds)"

{
  echo "job_id=$JOB_ID"
  echo "action=$ACTION"
  echo "start=$START"
} > "$STATUS"

run_action() {
  case "$ACTION" in
    readonly_smoke)
      /usr/local/libexec/xlx026-github-agent/readonly-smoke.sh
      ;;
    backup_only)
      sudo -n /usr/local/sbin/xlx026-safe-backup
      ;;
    golden_lab)
      sudo -n /usr/local/sbin/xlx026-golden-lab-v2
      ;;
    *)
      echo "[ERRO] ação não permitida: $ACTION" >&2
      return 64
      ;;
  esac
}

set +e
run_action > >(tee "$LOG") 2>&1
RC=$?
set -e

END="$(date --iso-8601=seconds)"
{
  echo "end=$END"
  echo "exit_code=$RC"
  if [[ $RC -eq 0 ]]; then
    echo "result=OK"
  else
    echo "result=ERROR"
  fi
} >> "$STATUS"
cp -f "$STATUS" "$LATEST"
printf '%s\n' "$JOB_ID" > "$LAST_FILE"
chmod 600 "$LOG" "$STATUS" "$LATEST" "$LAST_FILE"

exit "$RC"
