#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

BRANCH="feature/xlx026-maint-20260823"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${BRANCH}"
TMP="$(mktemp -d /tmp/xlx026-agent-bootstrap.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

[[ "$(id -u)" -eq 0 ]] || { echo "[ERRO] execute como root" >&2; exit 1; }
for c in curl sha256sum install useradd systemctl visudo sudo python3; do
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

AGENT="$(fetch_verify ops/agent/xlx026-github-agent.sh 3a2212f75e7ae7355662986ff70543c61739c8a7cad42719076efe8915cbdaee)"
SERVICE="$(fetch_verify ops/agent/xlx026-github-agent.service edb052b52813d7456ffa2f242b09a8b80c16b795e4d624cd5f34309e81f31387)"
TIMER="$(fetch_verify ops/agent/xlx026-github-agent.timer 61f1a6971b6349570e02c60576ddf5507bf5183ab8a532ef1b40a6f656f3022e)"
SMOKE="$(fetch_verify ops/readonly-smoke.sh 8202f4e6423f0afec815f7bcac307f295cd8c530d3a2ec424012bf907237db6d)"
BACKUP="$(fetch_verify ops/root/xlx026-safe-backup.sh 199400aae2aad209629fa40cf05313a24c0dae98b47db746ca72130c7a177ebb)"
GOLDEN="$(fetch_verify ops/root/xlx026-golden-lab-v2.sh 5bb49ee755ccd6401603c24cb178db9dd72eefe53c9354eef325468973450182)"

bash -n "$AGENT"
bash -n "$SMOKE"
bash -n "$BACKUP"
bash -n "$GOLDEN"

if [[ "${XLX026_BOOTSTRAP_VERIFY_ONLY:-0}" == "1" ]]; then
  echo "[OK] Bootstrap verify-only: downloads, SHA-256 e sintaxe aprovados."
  exit 0
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="/root/backups-xlx026/AGENT_BOOTSTRAP_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"
for p in \
  /usr/local/libexec/xlx026-github-agent \
  /usr/local/sbin/xlx026-safe-backup \
  /usr/local/sbin/xlx026-golden-lab-v2 \
  /etc/systemd/system/xlx026-github-agent.service \
  /etc/systemd/system/xlx026-github-agent.timer \
  /etc/sudoers.d/xlx026-github-agent; do
  [[ -e "$p" ]] && cp -a "$p" "$PRE/" || true
done

if ! id xlxagent >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/xlx026-github-agent --create-home --shell /usr/sbin/nologin xlxagent
fi

install -d -o root -g xlxagent -m 0750 /usr/local/libexec/xlx026-github-agent
install -d -o xlxagent -g xlxagent -m 0700 /var/lib/xlx026-github-agent
install -d -o root -g root -m 0700 /root/backups-xlx026 /root/xlx026-lab

install -o root -g xlxagent -m 0750 "$AGENT" /usr/local/libexec/xlx026-github-agent/xlx026-github-agent.sh
install -o root -g xlxagent -m 0750 "$SMOKE" /usr/local/libexec/xlx026-github-agent/readonly-smoke.sh
install -o root -g root -m 0750 "$BACKUP" /usr/local/sbin/xlx026-safe-backup
install -o root -g root -m 0750 "$GOLDEN" /usr/local/sbin/xlx026-golden-lab-v2
install -o root -g root -m 0644 "$SERVICE" /etc/systemd/system/xlx026-github-agent.service
install -o root -g root -m 0644 "$TIMER" /etc/systemd/system/xlx026-github-agent.timer

cat > /etc/sudoers.d/xlx026-github-agent <<'SUDO'
Defaults:xlxagent !requiretty
xlxagent ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-safe-backup
xlxagent ALL=(root) NOPASSWD: /usr/local/sbin/xlx026-golden-lab-v2
SUDO
chmod 0440 /etc/sudoers.d/xlx026-github-agent
visudo -cf /etc/sudoers.d/xlx026-github-agent >/dev/null

systemctl daemon-reload
systemctl enable --now xlx026-github-agent.timer
systemctl start xlx026-github-agent.service || true

systemctl is-enabled xlx026-github-agent.timer >/dev/null
systemctl is-active xlx026-github-agent.timer >/dev/null

cat <<OUT
[OK] XLX026 GitHub Maintenance Agent instalado.
[OK] Usuário sem shell: xlxagent
[OK] GitHub não recebeu credencial da VPS.
[OK] Nenhum token GitHub foi salvo no servidor.
[OK] Ações root permitidas: backup_only e golden_lab, por wrappers locais fixos.
[OK] Timer ativo: a cada 2 minutos.
[OK] Backup pré-bootstrap: $PRE

Para conferir:
  systemctl status xlx026-github-agent.timer --no-pager
  cat /var/lib/xlx026-github-agent/latest.status 2>/dev/null || true
OUT
