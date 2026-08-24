#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

STATE_DIR="/var/lib/xlx026-github-agent"
INBOX="$STATE_DIR/inbox"
RESULT_DIR="$STATE_DIR/results"
LAST_FILE="$STATE_DIR/last_job_id"
LATEST="$STATE_DIR/latest.status"
LOCK="/run/xlx026-github-executor.lock"

[[ "$(id -u)" -eq 0 ]] || { echo "[ERRO] executor precisa ser root" >&2; exit 1; }

mkdir -p "$INBOX" "$RESULT_DIR"
exec 9>"$LOCK"
flock -n 9 || exit 0

run_action() {
  local action="$1"
  case "$action" in
    readonly_smoke)
      /usr/local/libexec/xlx026-github-agent/readonly-smoke.sh
      ;;
    backup_only)
      /usr/local/sbin/xlx026-safe-backup
      ;;
    golden_lab)
      /usr/local/sbin/xlx026-golden-lab-v2
      ;;
    candidate_build)
      /usr/local/sbin/xlx026-core-260-candidate-v1
      ;;
    *)
      echo "[ERRO] ação não permitida: $action" >&2
      return 64
      ;;
  esac
}

shopt -s nullglob
for JOBFILE in "$INBOX"/*.json; do
  PARSED="$(python3 - "$JOBFILE" <<'PY'
import json,re,sys
with open(sys.argv[1],encoding='utf-8') as f:
    d=json.load(f)
if d.get('schema') != 1:
    raise SystemExit('invalid schema')
job=d.get('job_id','')
action=d.get('action','')
if not re.fullmatch(r'[A-Za-z0-9._-]{1,80}', job):
    raise SystemExit('invalid job_id')
if action not in {'readonly_smoke','backup_only','golden_lab','candidate_build'}:
    raise SystemExit('action not allowed')
print(job)
print(action)
PY
)" || {
    echo "[ERRO] job inválido: $JOBFILE" >&2
    rm -f "$JOBFILE"
    continue
  }

  mapfile -t FIELDS <<< "$PARSED"
  JOB_ID="${FIELDS[0]}"
  ACTION="${FIELDS[1]}"

  LAST=""
  [[ -f "$LAST_FILE" ]] && LAST="$(cat "$LAST_FILE" 2>/dev/null || true)"
  if [[ "$JOB_ID" == "$LAST" ]]; then
    rm -f "$JOBFILE"
    continue
  fi

  if [[ "$ACTION" == "backup_only" || "$ACTION" == "golden_lab" || "$ACTION" == "candidate_build" ]]; then
    AVAIL_KB="$(df -Pk /root | awk 'NR==2 {print $4}')"
    if [[ "${AVAIL_KB:-0}" -lt 1048576 ]]; then
      echo "[ERRO] menos de 1 GiB livre; ação $ACTION bloqueada" >&2
      RC=70
      START="$(date --iso-8601=seconds)"
      END="$START"
      LOG="$RESULT_DIR/${JOB_ID}.log"
      STATUS="$RESULT_DIR/${JOB_ID}.status"
      echo "[ERRO] espaço insuficiente" > "$LOG"
      {
        echo "job_id=$JOB_ID"
        echo "action=$ACTION"
        echo "start=$START"
        echo "end=$END"
        echo "exit_code=$RC"
        echo "result=ERROR"
      } > "$STATUS"
      cp -f "$STATUS" "$LATEST"
      printf '%s\n' "$JOB_ID" > "$LAST_FILE"
      chmod 640 "$LOG" "$STATUS" "$LATEST" "$LAST_FILE"
      chown root:xlxagent "$LOG" "$STATUS" "$LATEST" "$LAST_FILE"
      rm -f "$JOBFILE"
      continue
    fi
  fi

  LOG="$RESULT_DIR/${JOB_ID}.log"
  STATUS="$RESULT_DIR/${JOB_ID}.status"
  START="$(date --iso-8601=seconds)"

  {
    echo "job_id=$JOB_ID"
    echo "action=$ACTION"
    echo "start=$START"
  } > "$STATUS"

  set +e
  run_action "$ACTION" > >(tee "$LOG") 2>&1
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
  chmod 640 "$LOG" "$STATUS" "$LATEST" "$LAST_FILE"
  chown root:xlxagent "$LOG" "$STATUS" "$LATEST" "$LAST_FILE"
  rm -f "$JOBFILE"
done
