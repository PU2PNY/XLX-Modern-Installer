#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERRO: execute com sudo/root." >&2
  exit 1
fi

install -d -m 0700 /etc/xlx-ai-monitor

printf "Cole a chave da API OpenAI (a chave não será exibida): "
IFS= read -r -s OPENAI_KEY
printf "\n"

if [[ -z "${OPENAI_KEY}" || "${#OPENAI_KEY}" -lt 20 ]]; then
  echo "ERRO: chave vazia ou inválida." >&2
  exit 2
fi

if [[ "${OPENAI_KEY}" =~ [[:space:]\'"] ]]; then
  echo "ERRO: formato de chave não aceito pelo gravador seguro." >&2
  exit 3
fi

TMP="$(mktemp /etc/xlx-ai-monitor.env.XXXXXX)"
trap 'rm -f "$TMP"' EXIT
printf 'OPENAI_API_KEY=%s\n' "$OPENAI_KEY" > "$TMP"
printf 'OPENAI_MODEL=%s\n' "${OPENAI_MODEL:-gpt-6-luna}" >> "$TMP"
chmod 0600 "$TMP"
chown root:root "$TMP"
mv -f "$TMP" /etc/xlx-ai-monitor.env
trap - EXIT
unset OPENAI_KEY

systemctl start xlx-ai-monitor.service || true
systemctl enable --now xlx-ai-monitor.timer >/dev/null 2>&1 || true

echo "OK: chave salva somente em /etc/xlx-ai-monitor.env (root:root 0600)."
echo "OK: nenhum segredo foi gravado no GitHub ou no dashboard."
