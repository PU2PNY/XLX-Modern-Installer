#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
export LC_ALL=C
umask 027

LOCK="/run/lock/xlx-modern-callinghome.lock"
CLIENT="/usr/local/lib/xlx-modern/xlx-callinghome.php"
CONFIG="/etc/xlx-modern/callinghome.php"
STATE_DIR="/var/lib/xlx-modern-callinghome"
LAST_SUCCESS="$STATE_DIR/last-success"

fail(){ printf 'CALLHOME_ERROR %s\n' "$*" >&2; exit 1; }

[[ -x /usr/bin/php ]] || fail 'php CLI unavailable'
[[ -x /usr/sbin/runuser || -x /usr/bin/runuser ]] || fail 'runuser unavailable'
[[ -r "$CLIENT" ]] || fail "client unavailable: $CLIENT"
[[ -r "$CONFIG" ]] || fail "configuration unavailable: $CONFIG"
[[ -d "$STATE_DIR" ]] || fail "state directory unavailable: $STATE_DIR"

exec 9>"$LOCK"
flock -n 9 || exit 0

mapfile -t XLXD_PIDS < <(pgrep -x xlxd 2>/dev/null || true)
[[ "${#XLXD_PIDS[@]}" -eq 1 ]] || fail "unexpected xlxd process count=${#XLXD_PIDS[@]}"

UPTIME="$(ps -o etimes= -p "${XLXD_PIDS[0]}" 2>/dev/null | tr -d '[:space:]')"
[[ "$UPTIME" =~ ^[0-9]+$ && "$UPTIME" -gt 0 ]] || fail 'invalid xlxd uptime'

if ! OUTPUT="$(runuser -u www-data -- env \
    XLX_UPTIME="$UPTIME" \
    XLX_CALLINGHOME_CONFIG="$CONFIG" \
    /usr/bin/php "$CLIENT" 2>&1)"; then
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
printf '%s\n' "$OUTPUT"
printf '%s\n' "$OUTPUT" | grep -Fq 'CALLHOME_OK ' || fail 'client returned without CALLHOME_OK'

TMP="$(mktemp "$STATE_DIR/last-success.XXXXXX")"
printf '%s\n' "$(date +%s)" > "$TMP"
chown root:root "$TMP"
chmod 0644 "$TMP"
mv -f "$TMP" "$LAST_SUCCESS"

printf 'CALLHOME_STATE_OK last_success=%s\n' "$(cat "$LAST_SUCCESS")"
