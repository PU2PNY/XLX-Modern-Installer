# Helix PCM Bridge — experimental

Status: **laboratory only / disabled by default**.

This directory contains the first reversible bridge between the existing XLX legacy voice transcoder and Helix Voice. It does not make HVC a radio codec and it does not remove AMBE/AMBE+2 compatibility from D-STAR, DMR or YSF.

## Safety model

The legacy decoder/encoder remains outside the Helix core.

```text
legacy radio codec
        |
        v
external legacy decoder
        |
        v
      PCM
        |
        +----> Helix local Unix socket
        |          |
        |          v
        |       PCM DSP
        |          |
        +<---------+
        |
        v
external legacy encoder
```

The C++ client is fail-open for compatibility:

- `XLX_HELIX_MODE=off` — default; no Helix connection is attempted.
- `XLX_HELIX_MODE=shadow` — decoded PCM is sent one-way over a non-blocking Unix datagram; there is no reply wait and the radio audio path remains legacy.
- `XLX_HELIX_MODE=process` — returned PCM may replace the decoded PCM only after a complete, valid response.
- shadow send failure only drops the observation; process connect/read/write/validation timeout or failure leaves the original PCM untouched.
- the local request/reply timeout is bounded to 1..5 ms (5 ms default; one total deadline covering connect/write/read);
- if `process` fails once during a stream, that stream remains on the legacy path until close; Helix is retried only on a later stream.
- no remote/cloud dependency exists in the audio path.
- Helix or its socket may disappear without making a non-Helix radio incompatible.

Production must remain `off` until the documented ENV gates are completed. `shadow` is the first permitted production observation mode after laboratory regression and must use `XLX_HELIX_OBSERVE_SOCKET` (default `/run/helix-voice/observe.sock`). `process` uses the request/reply socket `XLX_HELIX_SOCKET` (default `/run/helix-voice/pcm.sock`) and is a separate audio-path change requiring its own controlled validation and rollback.

## Wire contract

The local protocol is `HXP1` version 1 over a Unix stream socket.

Header (24 bytes):

| Offset | Size | Field |
|---|---:|---|
| 0 | 4 | magic `HXP1` |
| 4 | 1 | version |
| 5 | 1 | flags |
| 6 | 2 | sample count, little-endian |
| 8 | 4 | stream id |
| 12 | 4 | sample rate |
| 16 | 8 | sample timestamp |

Payload: signed PCM16 little-endian. Maximum 960 samples.

Flags:

- `0x01`: apply Helix DSP;
- `0x02`: reset per-stream state;
- `0x80`: successful response.

## Legacy codec provenance used in the lab

No OP25 or mbelib source is vendored in this directory.

The reproducibility lab used:

- OP25: `boatbod/op25`, commit `71abcd0ead32f86f51615ea6cc8a6a4dba4c949a`;
- mbelib reference clone: `szechyjs/mbelib`, commit `9a04ed5c78176a9965f3d43f7aa1b1f5330e771f`.

The active XLX026 transcoder source uses OP25/mbelib-compatible AMBE parameter handling outside Helix. OP25 files inspected in the lab carry GPLv3-or-later notices; mbelib/AMBE files inspected carry their own permissive notice. Distribution of any binary linked with third-party code must comply with the applicable upstream terms. Patent/trademark/licensing questions around legacy vocoders remain separate from copyright license compliance.

## Acceptance sequence

1. compile and unit/contract tests;
2. compare `off` with the known-good legacy transcoder;
3. verify missing Helix produces bit-equivalent fallback;
4. verify `shadow` leaves transcoded output unchanged;
5. verify Helix process isolation and bounded latency;
6. controlled ENV audio regression;
7. only then consider production `shadow`;
8. `process` requires an additional quality/rollback gate.

The known-good production XLXD/transcoder must never be replaced merely because this experimental path builds successfully.


## ENV evidence — WartyWallaby, 2026-09-30

Real legacy-codec framing was exercised through the experimental transcoder using valid AMBE+2 generated from PCM and the public AMBED control/stream boundary.

- `off`, missing-Helix fallback and `shadow` produced the same output SHA-256: `0927cfff2bb8dfd6076ba6912ba9a96eef57284afd4df77e2436e9657521074f`.
- `process` with Helix active produced a different output SHA-256, proving that returned PCM was actually committed.
- missing Helix caused one bounded failure and pinned the remainder of that stream to legacy PCM; all 40 transcoder frames were still delivered with zero codec failures.
- `shadow` delivered 40/40 observations with zero fallbacks and remained bit-identical to `off`.
- `process` delivered 40/40 Helix responses with zero fallbacks in the single-stream run.
- two interleaved streams delivered all 60 output frames; one stream experienced one bounded Helix timeout and safely stayed legacy, while the other completed 30/30 through Helix.
- direct HXP1 request/reply latency over 2,000 frames: p50 0.085 ms, p95 0.319 ms, p99 0.817 ms, p99.9 1.750 ms, max 3.653 ms; zero samples above 5 ms.

This is ENV evidence. It does not authorize production `process`.

Production provenance was subsequently recovered from the 2026-09-08 backup: `boatbod/op25@28f2c40645deca3f8c2d529d27d0df2555ed287a`, the current production xuvd source SHA-256 `232754806725c85c3d6ad929bd7e7c6e20930c1c7829ddeeb0bb40c4f0bfea5c`, and an exact copy of the active binary SHA-256 `4b72dfc7a26697a3e315fba8c8d22435996d8e67c3112e2f343a65b4c6e58069`. The preserved deployment log shows that active binary was made by a one-byte FEC threshold patch (3→4) to predecessor SHA-256 `50ac33dfa7d14e972a120b77dd66ccbd6691bc7c32fd85edb63118ddf21cec15`. A clean historical rebuild in the same backup has SHA-256 `cc163930e5b0d859148c4324d21b6e3be6f4e8d8a25cbdc8853d77e6bfa475d0`, so build reproducibility is still not byte-identical. Production xuvd therefore remains untouched.


## Production-derived corpus equivalence — 2026-09-30

A bounded 90-second loopback capture was taken from the production XLXD↔xuvd AMBED interface without changing or restarting either process:

- 1,947 packets captured;
- 0 kernel drops;
- PCAP SHA-256: `112583f108c6b2c22d71aac007775193dc0bf11690414bc3b2c871e479af4f16`;
- the raw PCAP is operational evidence and must **not** be committed to Git.

Three complete real AMBE+2→D-Star sessions were extracted (101 + 66 + 661 = **828 input frames**) and replayed on WartyWallaby into:

1. the exact production xuvd binary SHA-256 `4b72dfc7a26697a3e315fba8c8d22435996d8e67c3112e2f343a65b4c6e58069`;
2. the Helix bridge candidate in `off`;
3. the same candidate in `shadow` with Helix observing every PCM frame.

All three generated byte-identical output, SHA-256:

`f64ebcfebfe59aeba9404a174f2c95eef000303f41e43a8c3b7562b8cf62a470`

Shadow observed **828/828** frames, with **0 transcoder failures**. This is ENV replay evidence using PROD-derived input; it is not itself a production audio-path deployment.

The deterministic synthetic gate additionally covers both directions (AMBE+2→D-Star and D-Star→AMBE+2) in modules A and C. The exact production binary, bridge `off`, and bridge `shadow` are bit-identical for all four generated paths. Reproduce with `test-prod-equivalence.sh`; provide the known-good xuvd binary and the reviewed OP25 source tree via environment variables.

## Repeatable E2E lab gate
Run only on an isolated host with UDP loopback 10100 free. Set OP25_LIB to the
reviewed OP25 lib directory, HELIX_DAEMON to the daemon executable, XUVD_BASELINE
to the exact known-good binary, LAB_OUTPUT to a new short directory path, then
run bash experimental/helix-bridge/test-e2e-lab.sh.

The gate first checks legacy equivalence, then exercises seven real AMBED sessions:
off, missing Helix, shadow, shadow killed halfway, process, process killed
halfway, and two interleaved TX streams. It compares output hashes and per-stream
counters and records frame round-trip p50/p95/p99, sampled RSS and CPU tick deltas.
A direct HXP1 low/high test compares isolated DSP streams with interleaved streams.
No production service is changed. CPU measurements on these short sessions are
coarse; this is not a 24-hour soak or a perceptual/RF test.

The 5 ms setting is one monotonic deadline for the complete IPC transaction,
including connect/write/header/payload. Socket operations are non-blocking.
Linux scheduling and poll granularity can add observed wall-clock overshoot;
5 ms is not a hard real-time guarantee. No PCM is committed after deadline expiry.
