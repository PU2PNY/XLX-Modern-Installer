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
- the local IPC timeout is bounded to 1..5 ms.
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
