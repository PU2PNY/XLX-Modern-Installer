# Unified Audio V1 — 2026-10-16 canary

This branch records the controlled XLX026 audio-normalization canary for D-Star ⇄ DMR/YSF transcoding. P25 is explicitly out of scope.

## Goal
Replace module-specific gain/EQ behavior with an opt-in, per-stream deterministic audio profile. The legacy production path remains the default unless `XLX_AUDIO_PROFILE=unified-v1` is set.

## Unified V1 processing
- 8 kHz PCM, 160 samples per 20 ms frame;
- gentle high-pass per destination direction;
- speech low-pass around the usable narrowband range;
- moderate presence contour;
- bounded per-stream AGC with faster attenuation than boost;
- low-level expander which attenuates noise but does not boost silence;
- soft compressor and safety limiter;
- no callsign-specific profile;
- no module-specific DSP in Unified V1.

Helix remains in `shadow` during the canary. Unified V1 is local deterministic DSP in xuvd and does not depend on cloud/API processing.

## Provenance / drift reconciliation
The current production xuvd did not match `main`. Its exact reproducible source was recovered from branch `fix/helix-live-observer-loop-20261001`, commit `bce9b1ff16d9be1bab593dfb63c2a56f1fc630c0`. Rebuilding that source reproduced production binary SHA-256 `d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884` exactly before Unified V1 was added.

## ENV gates
- Helix fallback contract: PASS.
- D-Star → YSF numeric/audio path: PASS.
- Full `tests/run-all.sh`: `failures=0`.
- Candidate with profile disabled/off: bit-identical to production in four codec/module paths.
- Candidate with Helix `shadow`: bit-identical to production in four codec/module paths.
- Unified V1 A/C module parity: bit-identical when each fixture starts from clean encoder state, both directions.
- Candidate runtime dependencies match baseline.

## Production canary
Backup: `/opt/xlx026-backups/UNIFIED_AUDIO_BASELINE_20261016_194650` (root-only, restore smoke checked).

Candidate SHA-256: `76f080e8d2090955231dd23b5acb28380f07c8968ce3bc0e0fdb81311b7008ae`.

Canary activation uses a separate systemd drop-in with `XLX_AUDIO_PROFILE=unified-v1`; existing Helix shadow configuration remains. XLXD is not restarted.

Initial PROD gate: XLXD PID stayed `2175715`; xuvd started as PID `3890481`; Live and Status APIs returned 200; first completed real AMBE+2→D-Star stream delivered 731 frames with `failures=0` and `helix_fallback=0`.

Perceptual quality remains **PENDING OPERATOR/HW** until real operators compare DMR, YSF and D-Star on air.

## Rollback
1. stop only `xlx-unified-voice.service`;
2. remove the Unified Audio drop-in;
3. restore backup xuvd SHA `d3ea28ef...e1884`;
4. daemon-reload/start xuvd;
5. do not restart XLXD;
6. revalidate D-Star/DMR/YSF and panel endpoints.
