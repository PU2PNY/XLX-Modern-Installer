#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

SOURCE_REF="9d5cf66992714f48772ae9ac70e6886b015624f5"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_REF}"
EXPECTED_PROD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"

TMP="$(mktemp -d /tmp/xlx026-agent-v5.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }

for c in curl sha256sum install systemctl tar bash pgrep; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

fetch_verify(){
  local rel expected out got
  rel="$1"
  expected="$2"
  out="$TMP/$(basename "$rel")"

  curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 45 \
    "$RAW/$rel" -o "$out"

  got="$(sha256sum "$out" | awk '{print $1}')"
  [[ "$got" == "$expected" ]] || {
    fail "SHA-256 divergente em $rel"
    echo "esperado=$expected" >&2
    echo "obtido=$got" >&2
    exit 3
  }
  echo "$out"
}

POLLER="$(fetch_verify ops/agent/xlx026-github-agent.sh e37cf662240a5893203cda7c371a36aa056b0f5c2d484360e9632c1ad9334459)"
EXECUTOR="$(fetch_verify ops/agent/xlx026-github-executor.sh 02e0d382718e5d97a4f52e538d01da034a1fbb277f873f63e2fce53fa26157bc)"
FINALIZER="$(fetch_verify ops/root/xlx026-core-260-candidate-finalize-v1.sh f0bdb7362cdb327991fea6a53846ea1093bb5054bc1916aa6fd8374766f018b2)"

bash -n "$POLLER"
bash -n "$EXECUTOR"
bash -n "$FINALIZER"

if [[ "${XLX026_UPGRADE_V5_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "Upgrade V5 verify-only: downloads, hashes e sintaxe aprovados."
  exit 0
fi

[[ -x /xlxd/xlxd ]] || { fail "/xlxd/xlxd ausente"; exit 10; }
CURRENT_PROD_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA" == "$EXPECTED_PROD_SHA" ]] || {
  fail "SHA do XLXD de produção mudou; V5 abortada"
  echo "esperado=$EXPECTED_PROD_SHA" >&2
  echo "obtido=$CURRENT_PROD_SHA" >&2
  exit 11
}
pgrep -x xlxd >/dev/null 2>&1 || { fail "XLXD de produção não está ativo"; exit 12; }

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="/root/backups-xlx026/AGENT_V5_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"

tar -C / -czf "$PRE/agent-pre-v5.tar.gz" \
  usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh \
  usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh \
  etc/systemd/system/xlx026-github-agent.service \
  etc/systemd/system/xlx026-github-agent.timer \
  etc/systemd/system/xlx026-github-executor.service \
  etc/systemd/system/xlx026-github-executor.path \
  2>/dev/null || true

sha256sum "$PRE/agent-pre-v5.tar.gz" > "$PRE/agent-pre-v5.tar.gz.sha256"
(
  cd "$PRE"
  sha256sum -c agent-pre-v5.tar.gz.sha256
)

systemctl stop xlx026-github-agent.timer 2>/dev/null || true
systemctl stop xlx026-github-agent.service 2>/dev/null || true
systemctl stop xlx026-github-executor.path 2>/dev/null || true

install -o root -g xlxagent -m 0750 \
  "$POLLER" \
  /usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh

install -o root -g root -m 0750 \
  "$EXECUTOR" \
  /usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh

install -o root -g root -m 0750 \
  "$FINALIZER" \
  /usr/local/sbin/xlx026-core-260-candidate-finalize-v1

test "$(sha256sum /usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh | awk '{print $1}')" \
  = "e37cf662240a5893203cda7c371a36aa056b0f5c2d484360e9632c1ad9334459"
test "$(sha256sum /usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh | awk '{print $1}')" \
  = "02e0d382718e5d97a4f52e538d01da034a1fbb277f873f63e2fce53fa26157bc"
test "$(sha256sum /usr/local/sbin/xlx026-core-260-candidate-finalize-v1 | awk '{print $1}')" \
  = "f0bdb7362cdb327991fea6a53846ea1093bb5054bc1916aa6fd8374766f018b2"

systemctl daemon-reload
systemctl enable --now xlx026-github-executor.path
systemctl enable --now xlx026-github-agent.timer

systemctl is-active --quiet xlx026-github-executor.path
systemctl is-active --quiet xlx026-github-agent.timer

CURRENT_PROD_SHA_AFTER="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA_AFTER" == "$EXPECTED_PROD_SHA" ]] || {
  fail "produção mudou durante V5"
  exit 20
}
pgrep -x xlxd >/dev/null 2>&1 || { fail "XLXD deixou de estar ativo"; exit 21; }

cat <<OUT
[OK] AGENTE V5 instalado.
[OK] candidate_finalize liberado.
[OK] Finalizador SHA256: f0bdb7362cdb327991fea6a53846ea1093bb5054bc1916aa6fd8374766f018b2
[OK] Backup pré-V5: $PRE
[OK] XLXD produção permaneceu ativo.
[OK] SHA produção: $CURRENT_PROD_SHA_AFTER
[OK] Nenhuma publicação/restart do XLXD ocorreu.
OUT
