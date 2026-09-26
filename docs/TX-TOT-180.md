# XLXD TX TOT 180 s — 2026-09-23

## Decision

Add an absolute **180-second transmission timeout (TOT)** to XLXD.

The dashboard warns the operator beginning at **170 seconds** with a strong
pulsing red/neon border. At **180 seconds**, the reflector closes the active
stream and releases the module so another call can start.

The timed-out stream ID + source IP are temporarily suppressed until its
last frame is observed or the normal 1.6-second inactivity window expires.
This prevents the same held PTT from immediately reopening the stream while
still allowing the next legitimate call.

## Scope

Core patch only:

- `src/cpacketstream.h/.cpp`
- `src/cprotocol.cpp`
- `src/creflector.h/.cpp`

The patch intentionally does **not** hard-code reflector identity, module
count, YSF ID/frequency, ports, callsigns, domains or other XLX026-specific
configuration.

Patch file:

- `patches/xlxd/0001-tx-tot-180.patch`

## Evidence

### DOC

- Upstream baseline: PP5PK/xlxd commit
  `e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004`, XLXD 2.5.3.
- XLX026 production configuration preserved independently:
  5 modules, YSF UDP 42000, 433.125 MHz, YSF autolink C.

### SW

- `git diff --check`: PASS.
- Full `make -j1` on Debian 12 test VPS `WartyWallaby`: PASS.
- Candidate SHA-256:
  `c0283b7f6c7644b84284140ecaa20e7643bd60a99b961a8f099f9fea19976441`.

### ENV

- Candidate binary started on the Debian 12 test VPS.
- The test VPS already had another XLXD bound on the production protocol
  ports, so that run is **not** evidence of exclusive port ownership or
  end-to-end RF/protocol traffic.

### PROD

Deployed to XLX026 at approximately 2026-09-23 01:03 BRT after waiting for
`active_count=0`.

Validated after restart:

- `xlxd.service`: active.
- XLXD reports version 2.5.3.
- Protocol listeners restored, including 10001, 10002, 20001, 30001, 30051,
  42000, 62030 and 8880.
- Transcoder reconnected.
- Connected clients recovered from 88 before restart to 88 after recovery.
- Dashboard HTTP checks remained fast (approximately 13–23 ms in the
  immediate post-deploy checks).
- No startup fatal/socket/segfault errors were observed.

**Important:** the actual 180-second production cutoff has not yet been
observed with a real post-deploy transmission reaching the threshold.
Therefore the code is deployed and the service path is validated, but
`PROD TOT functional PASS` must remain pending until a real 180-second
transmission proves the cutoff and next-call recovery.

## Rollback

Pre-change production backup:

`/root/backups-xlx026/TOT180_PRE_20260923_005427/xlxd`

Pre-change binary SHA-256:

`ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347`

Current TOT candidate SHA-256:

`c0283b7f6c7644b84284140ecaa20e7643bd60a99b961a8f099f9fea19976441`

Do not remove the rollback binary until the real 180-second production test
has passed.
