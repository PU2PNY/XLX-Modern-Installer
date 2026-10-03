#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/experimental/stereotool/systemd"
WORKER="$D/xlx-stereotool-shadow.service"
ROUTER="$D/xlx-pcm-shadow-router.service"
HELIX="$D/helix-voice-shadow-fanout.conf"
ORDER="$D/xlx-unified-voice-shadow-router.conf"

grep -F 'RestrictAddressFamilies=AF_UNIX' "$WORKER" >/dev/null
grep -F 'PrivateDevices=yes' "$WORKER" >/dev/null
grep -F 'MemoryMax=320M' "$WORKER" >/dev/null
grep -F 'CPUQuota=50%' "$WORKER" >/dev/null
grep -F -- '--max-contexts 1' "$WORKER" >/dev/null
grep -F '9bc3b7c79b3e090adad8b13c87a8c34e37271278d65c7dccd5d4daf76548b20f' "$WORKER" >/dev/null

grep -F 'RestrictAddressFamilies=AF_UNIX' "$ROUTER" >/dev/null
grep -F -- '--input /run/helix-voice/observe.sock' "$ROUTER" >/dev/null
grep -F -- '--target /run/helix-voice/helix.sock' "$ROUTER" >/dev/null
grep -F -- '--target /run/xlx-stereotool/observe.sock' "$ROUTER" >/dev/null
grep -F 'MemoryMax=32M' "$ROUTER" >/dev/null

grep -F 'RuntimeDirectoryPreserve=yes' "$HELIX" >/dev/null
grep -F '/run/helix-voice/helix.sock' "$HELIX" >/dev/null
grep -F 'Wants=xlx-pcm-shadow-router.service' "$ORDER" >/dev/null

if grep -R -nE 'RestrictAddressFamilies=.*AF_INET|--target[[:space:]]+https?://' "$WORKER" "$ROUTER"; then
  echo 'stereotool_shadow_systemd=FAIL network surface detected'
  exit 1
fi

echo 'stereotool_shadow_systemd=PASS'
