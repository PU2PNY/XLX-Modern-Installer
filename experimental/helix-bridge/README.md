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
- the local request/reply timeout is bounded to 1..10 ms (10 ms default after ENV measurement);
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

This is ENV evidence. It does not authorize production `process`. The exact provenance of the currently running production transcoder's historical OP25/mbelib build dependencies must be reconciled before replacing that binary, even in `shadow`.
