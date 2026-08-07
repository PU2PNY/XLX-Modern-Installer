#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' \
  '[ERRO] Este publicador legado foi desativado na release internacional.' \
  'Ele não deve copiar uma instalação de produção diretamente para a branch principal.' \
  'Use um fluxo de staging, auditoria e Pull Request para futuras atualizações do dashboard.' >&2
exit 1
