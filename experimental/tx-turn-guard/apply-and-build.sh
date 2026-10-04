#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$ROOT/patches/xlxd-2.5.3-anti-ping-pong-v1.patch"
EXPECTED_COMMIT="e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004"
SRC="${1:-}"

if [[ -z "$SRC" || ! -d "$SRC/.git" || ! -d "$SRC/src" ]]; then
  echo "Uso: $0 /caminho/para/checkout/xlxd" >&2
  exit 2
fi

actual="$(git -C "$SRC" rev-parse HEAD)"
if [[ "$actual" != "$EXPECTED_COMMIT" ]]; then
  echo "ERRO: revisão XLXD não aprovada para este patch." >&2
  echo "esperado=$EXPECTED_COMMIT" >&2
  echo "observado=$actual" >&2
  exit 20
fi

if [[ -n "$(git -C "$SRC" status --porcelain)" ]]; then
  echo "ERRO: checkout XLXD possui alterações locais; recusando aplicar patch." >&2
  exit 21
fi

if ! git -C "$SRC" apply --check "$PATCH"; then
  echo "ERRO: patch não aplica limpo; nenhuma alteração foi feita." >&2
  exit 22
fi

git -C "$SRC" apply "$PATCH"
make -C "$SRC/src" -f makefile clean
make -C "$SRC/src" -f makefile -j"${JOBS:-2}"

printf 'tx_turn_guard_build=PASS\n'
printf 'upstream_commit=%s\n' "$actual"
printf 'binary=%s\n' "$SRC/src/xlxd"
sha256sum "$SRC/src/xlxd"

cat <<'NOTE'
ATENÇÃO: este script somente aplica e compila o candidato em LAB.
Ele NÃO instala o binário, NÃO reinicia serviço e NÃO habilita XLX_TX_TURN_GUARD.
NOTE
