#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${REACTBITS_LICENSE_KEY:-}" ]]; then
  echo "LICENCA_AUSENTE: configure REACTBITS_LICENSE_KEY no ambiente privado; nunca no GitHub nem no webroot." >&2
  exit 2
fi
if [[ ! -f package.json || ! -f components.json ]]; then
  echo "REACT_SCAFFOLD_INCOMPLETO" >&2; exit 3
fi
node scripts/verify-registry.mjs
npx shadcn@latest add @reactbits-starter/prismatic-slats-tw
printf '%s\n' "INSTALACAO_CONCLUIDA_NO_AMBIENTE_PRIVADO: inspecione export/props e adapte src/App.tsx em seguida."
