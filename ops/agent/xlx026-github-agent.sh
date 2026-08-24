#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

CONTROL_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/feature/xlx026-maint-20260823/maintenance/control.json"
STATE_DIR="/var/lib/xlx026-github-agent"
INBOX="$STATE_DIR/inbox"
LAST_FILE="$STATE_DIR/last_job_id"
TMP="$(mktemp "$STATE_DIR/control.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

mkdir -p "$INBOX"

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
[[ ! -e "$INBOX/${JOB_ID}.json" ]] || exit 0

TMPJOB="$(mktemp "$INBOX/.job.XXXXXX")"
python3 - "$TMPJOB" "$JOB_ID" "$ACTION" <<'PY'
import json, sys
p,job,action=sys.argv[1:4]
with open(p,'w',encoding='utf-8') as f:
    json.dump({"schema":1,"job_id":job,"action":action}, f, separators=(',',':'))
    f.write('\n')
PY
chmod 600 "$TMPJOB"
mv -f "$TMPJOB" "$INBOX/${JOB_ID}.json"

echo "[OK] job enfileirado: $JOB_ID / $ACTION"
