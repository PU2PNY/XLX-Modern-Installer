#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

SOURCE_REF="9d5cf66992714f48772ae9ac70e6886b015624f5"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_REF}"
EXPECTED_PROD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"

POLL_BLOB="450bab2ffef7a15855db55e2a4c7103006bc678d"
EXEC_BLOB="b740829e445f96c9be878ba10a83b873a56282c2"
FINAL_BLOB="aa707756b6af9ac30ff0a2fefbd62243b3e5f671"

TMP="$(mktemp -d /tmp/xlx026-agent-v6.XXXXXX)"
MUTATED=0
PRE=""
trap 'rc=$?; if [[ $rc -ne 0 && $MUTATED -eq 1 && -n "$PRE" && -f "$PRE/agent-pre-v6.tar.gz" ]]; then echo "[ATENÇÃO] Falha após início da migração; restaurando agente anterior..." >&2; tar -C / -xzf "$PRE/agent-pre-v6.tar.gz" || true; rm -f /usr/local/sbin/xlx026-core-260-candidate-finalize-v1; systemctl daemon-reload || true; systemctl enable --now xlx026-github-executor.path || true; systemctl enable --now xlx026-github-agent.timer || true; fi; rm -rf "$TMP"; exit $rc' EXIT

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }

for c in curl git install systemctl tar sha256sum pgrep bash; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

fetch_verify_blob(){
  local rel expected out got
  rel="$1"
  expected="$2"
  out="$TMP/$(basename "$rel")"

  curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 45 \
    "$RAW/$rel" -o "$out"

  got="$(git hash-object "$out")"
  [[ "$got" == "$expected" ]] || {
    fail "Git blob divergente em $rel"
    echo "esperado=$expected" >&2
    echo "obtido=$got" >&2
    exit 3
  }

  echo "$out"
}

POLLER="$(fetch_verify_blob ops/agent/xlx026-github-agent.sh "$POLL_BLOB")"
EXECUTOR="$(fetch_verify_blob ops/agent/xlx026-github-executor.sh "$EXEC_BLOB")"
FINALIZER="$(fetch_verify_blob ops/root/xlx026-core-260-candidate-finalize-v1.sh "$FINAL_BLOB")"

bash -n "$POLLER"
bash -n "$EXECUTOR"
bash -n "$FINALIZER"

if [[ "${XLX026_UPGRADE_V6_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "Upgrade V6 verify-only: Git blobs e sintaxe aprovados."
  exit 0
fi

[[ -x /xlxd/xlxd ]] || { fail "/xlxd/xlxd ausente"; exit 10; }
CURRENT_PROD_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA" == "$EXPECTED_PROD_SHA" ]] || {
  fail "SHA do XLXD de produção mudou; V6 abortada"
  echo "esperado=$EXPECTED_PROD_SHA" >&2
  echo "obtido=$CURRENT_PROD_SHA" >&2
  exit 11
}
pgrep -x xlxd >/dev/null 2>&1 || { fail "XLXD de produção não está ativo"; exit 12; }

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="/root/backups-xlx026/AGENT_V6_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"

TAR_ITEMS=(
  usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh
  usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh
  etc/systemd/system/xlx026-github-agent.service
  etc/systemd/system/xlx026-github-agent.timer
  etc/systemd/system/xlx026-github-executor.service
  etc/systemd/system/xlx026-github-executor.path
)

tar -C / -czf "$PRE/agent-pre-v6.tar.gz" "${TAR_ITEMS[@]}"
sha256sum "$PRE/agent-pre-v6.tar.gz" > "$PRE/agent-pre-v6.tar.gz.sha256"
(
  cd "$PRE"
  sha256sum -c agent-pre-v6.tar.gz.sha256
)

systemctl stop xlx026-github-agent.timer 2>/dev/null || true
systemctl stop xlx026-github-agent.service 2>/dev/null || true
systemctl stop xlx026-github-executor.path 2>/dev/null || true
MUTATED=1

install -o root -g xlxagent -m 0750 \
  "$POLLER" \
  /usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh

install -o root -g root -m 0750 \
  "$EXECUTOR" \
  /usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh

install -o root -g root -m 0750 \
  "$FINALIZER" \
  /usr/local/sbin/xlx026-core-260-candidate-finalize-v1

[[ "$(git hash-object /usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh)" == "$POLL_BLOB" ]]
[[ "$(git hash-object /usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh)" == "$EXEC_BLOB" ]]
[[ "$(git hash-object /usr/local/sbin/xlx026-core-260-candidate-finalize-v1)" == "$FINAL_BLOB" ]]

systemctl daemon-reload
systemctl enable --now xlx026-github-executor.path
systemctl enable --now xlx026-github-agent.timer

systemctl is-active --quiet xlx026-github-executor.path
systemctl is-active --quiet xlx026-github-agent.timer

CURRENT_PROD_SHA_AFTER="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA_AFTER" == "$EXPECTED_PROD_SHA" ]] || {
  fail "produção mudou durante V6"
  exit 20
}
pgrep -x xlxd >/dev/null 2>&1 || { fail "XLXD deixou de estar ativo"; exit 21; }

MUTATED=0

cat <<OUT
[OK] AGENTE V6 instalado.
[OK] Validação interna por Git blob SHA.
[OK] candidate_finalize liberado.
[OK] Poller blob: $POLL_BLOB
[OK] Executor blob: $EXEC_BLOB
[OK] Finalizador blob: $FINAL_BLOB
[OK] Backup pré-V6: $PRE
[OK] XLXD produção permaneceu ativo.
[OK] SHA produção: $CURRENT_PROD_SHA_AFTER
[OK] Nenhuma publicação/restart do XLXD ocorreu.
OUT
