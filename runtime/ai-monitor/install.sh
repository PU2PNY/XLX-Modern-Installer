#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERRO: execute como root." >&2
  exit 1
fi

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
install -d -m 0755 /usr/local/lib/xlx-modern
install -d -m 0755 /var/lib/xlx-ai-monitor
install -m 0755 "$ROOT/xlx-ai-monitor.py" /usr/local/lib/xlx-modern/xlx-ai-monitor.py
install -m 0755 "$ROOT/xlx-ai-key.sh" /usr/local/sbin/xlx-ai-key
install -m 0644 "$ROOT/xlx-ai-monitor.service" /etc/systemd/system/xlx-ai-monitor.service
install -m 0644 "$ROOT/xlx-ai-monitor.timer" /etc/systemd/system/xlx-ai-monitor.timer

systemctl daemon-reload
systemctl enable --now xlx-ai-monitor.timer
systemctl start xlx-ai-monitor.service || true

echo "OK: AI Monitor instalado. Para adicionar a chave: sudo xlx-ai-key"
