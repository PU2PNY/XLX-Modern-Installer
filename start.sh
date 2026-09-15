#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

printf '\n============================================================\n'
printf 'XLX MODERN INSTALLER — MODO SIMPLES / SIMPLE MODE\n'
printf '============================================================\n'
printf 'Perguntas em Português + English, uma por vez.\n'
printf 'Questions in Portuguese + English, one at a time.\n\n'

exec bash "$ROOT_DIR/install.sh" "$@" --classic
