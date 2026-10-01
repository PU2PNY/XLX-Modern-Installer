#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v g++ >/dev/null || { echo 'SKIP | deadline test requires g++'; exit 0; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
g++ -std=c++17 -O2 -Wall -Wextra -Werror -pthread -I"$ROOT" "$ROOT/tests/helix-pcm-deadline.cpp" -o "$TMP/deadline"
timeout 20 "$TMP/deadline" "$TMP"
