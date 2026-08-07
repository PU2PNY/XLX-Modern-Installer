#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' \
  '[ERRO] Este publicador legado foi desativado na release internacional.' \
  'Publicação direta de uma VPS para a branch principal não faz parte do fluxo suportado.' \
  'Use staging, auditoria, branch de release e Pull Request.' >&2
exit 1
