#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-}"
[[ -n "$OUT" && ! -e "$OUT" ]] || { echo 'usage: build-helix-recovery.sh NEW_OUTPUT_DIRECTORY' >&2; exit 2; }
mkdir -p "$OUT"
git init -q "$OUT"
git -C "$OUT" remote add origin https://github.com/PU2PNY/Helix-Voice.git
git -C "$OUT" fetch --depth 1 origin e80969d58d0ecf0f4bd55bbc7fae85311c0176d2
git -C "$OUT" checkout --detach FETCH_HEAD
cp "$ROOT/runtime/helix-recovery/Cargo.lock" "$OUT/Cargo.lock"
cargo +1.90.0 build --locked --release --manifest-path "$OUT/Cargo.toml" --jobs 1
sha256sum "$OUT/target/release/helix-daemon" > "$OUT/helix-daemon.sha256"
echo 'HELIX_REFERENCE_BUILD=PASS; no service installed or restarted'
