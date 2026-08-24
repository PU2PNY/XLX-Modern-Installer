#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

SOURCE_REF="a69429391b40e65f0fdeb12644771abaf29ade0f"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_REF}"
TMP="$(mktemp -d /tmp/xlx026-agent-bootstrap.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

[[ "$(id -u)" -eq 0 ]] || { echo "[ERRO] execute como root" >&2; exit 1; }
for c in curl sha256sum install useradd systemctl visudo python3 flock; do
  command -v "$c" >/dev/null 2>&1 || { echo "[ERRO] comando ausente: $c" >&2; exit 2; }
done

fetch_verify(){
  local rel expected out got
  rel="$1"
  expected="$2"
  out="$TMP/$(basename "$rel")"

  curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 30 \
    "$RAW/$rel" -o "$out"

  got="$(sha256sum "$out" | awk '{print $1}')"
  [[ "$got" == "$expected" ]] || {
    echo "[ERRO] SHA-256 divergente em $rel" >&2
    echo "esperado=$expected" >&2
    echo "obtido=$got" >&2
    exit 3
  }
  echo "$out"
}

POLLER="$(fetch_verify ops/agent/xlx026-github-agent.sh d53a717718f238663cfb0000324ee0fea7d9c6452df22f209ab7c167026cf0d5)"
POLL_SERVICE="$(fetch_verify ops/agent/xlx026-github-agent.service 16c536e78e67c4aad1f86690f11927ee67f4d2d085437958c1e8810073338e9c)"
TIMER="$(fetch_verify ops/agent/xlx026-github-agent.timer 61f1a6971b6349570e02c60576ddf5507bf5183ab8a532ef1b40a6f656f3022e)"
EXECUTOR="$(fetch_verify ops/agent/xlx026-github-executor.sh ccf80b17e30f193ec8a5306a061a0fad0e3c0e71d7f44e0bf508137a4c5d53e7)"
EXEC_SERVICE="$(fetch_verify ops/agent/xlx026-github-executor.service 3fc5e6f199dcd210aa6ebcc496bd842c523485470003ebc7ae71626c9792580c)"
EXEC_PATH="$(fetch_verify ops/agent/xlx026-github-executor.path 2b9bf66ae8f43d12b46cf2830e1b8396e07e54234c00613541657c24b3b7e076)"
SMOKE="$(fetch_verify ops/readonly-smoke.sh 8202f4e6423f0afec815f7bcac307f295cd8c530d3a2ec424012bf907237db6d)"
BACKUP="$(fetch_verify ops/root/xlx026-safe-backup.sh 199400aae2aad209629fa40cf05313a24c0dae98b47db746ca72130c7a177ebb)"
GOLDEN="$(fetch_verify ops/root/xlx026-golden-lab-v2.sh 5bb49ee755ccd6401603c24cb178db9dd72eefe53c9354eef325468973450182)"

for s in "$POLLER" "$EXECUTOR" "$SMOKE" "$BACKUP" "$GOLDEN"; do
  bash -n "$s"
done

if [[ "${XLX026_BOOTSTRAP_VERIFY_ONLY:-0}" == "1" ]]; then
  echo "[OK] Bootstrap V3 verify-only: downloads, SHA-256 e sintaxe aprovados."
  exit 0
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="/root/backups-xlx026/AGENT_BOOTSTRAP_V3_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"

for p in \
  /usr/local/libexec/xlx026-github-agent \
  /usr/local/sbin/xlx026-safe-backup \
  /usr/local/sbin/xlx026-golden-lab-v2 \
  /etc/systemd/system/xlx026-github-agent.service \
  /etc/systemd/system/xlx026-github-agent.timer \
  /etc/systemd/system/xlx026-github-executor.service \
  /etc/systemd/system/xlx026-github-executor.path \
  /etc/sudoers.d/xlx026-github-agent; do
  [[ -e "$p" ]] && cp -a "$p" "$PRE/" || true
done

if ! id xlxagent >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/xlx026-github-agent --create-home --shell /usr/sbin/nologin xlxagent
fi

systemctl stop xlx026-github-agent.timer 2>/dev/null || true
systemctl stop xlx026-github-agent.service 2>/dev/null || true
systemctl stop xlx026-github-executor.path 2>/dev/null || true

install -d -o root -g xlxagent -m 0750 /usr/local/libexec/xlx026-github-agent
install -d -o xlxagent -g xlxagent -m 0700 /var/lib/xlx026-github-agent
install -d -o xlxagent -g xlxagent -m 0700 /var/lib/xlx026-github-agent/inbox
install -d -o root -g xlxagent -m 0750 /var/lib/xlx026-github-agent/results
install -d -o root -g root -m 0700 /root/backups-xlx026 /root/xlx026-lab

install -o root -g xlxagent -m 0750 "$POLLER" /usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh
install -o root -g root -m 0750 "$EXECUTOR" /usr/local/libexec/xlx026-github-agent/xlx026-github-executor.sh
install -o root -g root -m 0750 "$SMOKE" /usr/local/libexec/xlx026-github-agent/readonly-smoke.sh
install -o root -g root -m 0750 "$BACKUP" /usr/local/sbin/xlx026-safe-backup
install -o root -g root -m 0750 "$GOLDEN" /usr/local/sbin/xlx026-golden-lab-v2

install -o root -g root -m 0644 "$POLL_SERVICE" /etc/systemd/system/xlx026-github-agent.service
install -o root -g root -m 0644 "$TIMER" /etc/systemd/system/xlx026-github-agent.timer
install -o root -g root -m 0644 "$EXEC_SERVICE" /etc/systemd/system/xlx026-github-executor.service
install -o root -g root -m 0644 "$EXEC_PATH" /etc/systemd/system/xlx026-github-executor.path

rm -f /etc/sudoers.d/xlx026-github-agent

systemctl daemon-reload
systemctl enable --now xlx026-github-executor.path
systemctl enable --now xlx026-github-agent.timer
systemctl start xlx026-github-agent.service || true

systemctl is-enabled xlx026-github-agent.timer >/dev/null
systemctl is-active xlx026-github-agent.timer >/dev/null
systemctl is-enabled xlx026-github-executor.path >/dev/null
systemctl is-active xlx026-github-executor.path >/dev/null

cat <<OUT
[OK] XLX026 GitHub Maintenance Agent V3 instalado.
[OK] Poller Internet: xlxagent sem shell e sem privilégio.
[OK] Executor root: somente ações locais allowlist.
[OK] sudo removido do fluxo.
[OK] Nenhum token GitHub salvo na VPS.
[OK] Nenhum comando shell arbitrário aceito.
[OK] Timer e systemd.path ativos.
[OK] Backup pré-migração: $PRE
OUT
