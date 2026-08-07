#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' \
  '[ERRO] Este utilitário legado de saneamento foi desativado.' \
  'A release internacional já mantém identidade e configuração de implantação separadas do código distribuído.' \
  'Futuras mudanças devem passar pela auditoria automatizada e revisão do Pull Request.' >&2
exit 1
