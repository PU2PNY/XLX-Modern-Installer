# mbelib upstream compatibility — XLX026 source audit (2026-11-03)

**Decision:** NO additional mbelib library installed or run. The known-good XLXD/xuvd continues unchanged in production. Track [issue #95](https://github.com/PU2PNY/XLX-Modern-Installer/issues/95).

## Upstream source (DOC)

- [szechyjs/mbelib](https://github.com/szechyjs/mbelib), pinned master commit `9a04ed5c78176a9965f3d43f7aa1b1f5330e771f` (2019-05-29), `MBELIB_VERSION=1.3.0` in `mbelib.h`.
- Public README says 7200x4400 IMBE (P25 Phase 1), 7100x4400 IMBE (ProVoice), 3600x2250 half-rate vocoder and initial D-STAR AMBE in changelog. The public `mbelib.h` contains decoder, error-correction and PCM synthesis functions, but **does not provide a complete AMBE/AMBE+2 encoding API** or the OP25 extension `mbe_dequantizeAmbe*Parms` used by our xuvd source.
- The project COPYRIGHT/debian/copyright includes the **ISC license**. The upstream README explicitly warns of possible codec patents. Copyright permission and patent rights are separate.

## Existing XLX026 source integration (DOC)

- `experimental/helix-bridge/xuvd.cpp` already has `#include "mbelib.h"`, `mbe_initMbeParms`, `mbe_moveMbeParms`, `mbe_useLastMbeParms`, `mbe_dequantizeAmbe2400Parms`, `mbe_dequantizeAmbe2250Parms`, PCM synthesis, plus separate OP25-derived `software_imbe_decoder` and `ambe_encoder`.
- `experimental/helix-bridge/README.md` previously fixed the **mbelib reference clone** to `szechyjs/mbelib@9a04ed5...`, with original OP25 and provenance references.
- This establishes **mbelib-compatible source lineage** but NOT byte-for-byte identity to upstream mbelib from 2019, nor a claim that a new libmbe1 package is present.

## Read-only production evidence (PROD)

- Active `/opt/xlx-unified-voice/bin/xuvd` SHA256 `d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884`.
- `nm -C` of active xuvd shows `mbe_initMbeParms`, `mbe_moveMbeParms`, `mbe_useLastMbeParms`, `mbe_synthesizeSpeech`, `mbe_dequantizeAmbe2250Parms` and `mbe_dequantizeAmbe2400Parms` as embedded ELF symbols.
- `readelf -d` and `ldd` show **no libmbe.so dynamic linkage**. `dpkg-query` on `libmbe1` and `libmbe-dev` showed no installed package records in this inspection.
- `xlxd.service` and `xlx-unified-voice.service` were active/enabled; `xlx-softambe.service` inactive/disabled after the operator rejected SoftAMBE D-STAR↔DMR audio and rollback succeeded. No system modification was performed in this mbelib audit.
- There is **no verified parity mapping** of every embedded mbe symbol to the exact upstream commit.

## Implications

1. Adding `apt install libmbe1` will not automatically alter the xuvd audio path: the mbelib-compatible functions already reside inside the ELF. No new shared-library ABI dependency is desirable without justified proof and a reproducible rebuild.
2. The upstream public header has decode/PCM synth but does not offer a drop-in replacement for both directions of xuvd's full AMBE↔AMBE+2 transcoding. It also cannot be assumed to fix a poor microphone input, saturation, or DMR↔YSF DN direct-frame handling.
3. Any hypothetical change needs a specific measured failure, matched codec corpus, binary-reproducible build, independent source license inventory (ISC mbelib and additional OP25 licenses), rollback with actual restore, and real-radio evaluation.
4. Preserve the present **working** xuvd and XLXD. The SoftAMBE attempt was reversed on the operator's acoustic evidence; no alternate codec should be introduced solely because its repository is available.

**No binary, patch, license secret or user voice corpus is copied into this repository.**

Sources: [mbelib README](https://github.com/szechyjs/mbelib/blob/9a04ed5c78176a9965f3d43f7aa1b1f5330e771f/README.md) | [mbelib.h](https://github.com/szechyjs/mbelib/blob/9a04ed5c78176a9965f3d43f7aa1b1f5330e771f/mbelib.h) | [COPYRIGHT](https://github.com/szechyjs/mbelib/blob/9a04ed5c78176a9965f3d43f7aa1b1f5330e771f/COPYRIGHT) | [XLX026 xuvd.cpp](https://github.com/PU2PNY/XLX-Modern-Installer/blob/main/experimental/helix-bridge/xuvd.cpp).
