# Adaptive DMR Gain Normalizer — experimental V1

Status: **disabled by default; not approved for production yet**.

The component measures active DMR speech for a short window and adjusts only the AMBE+2 coded gain parameter. Adaptive mode returns before the legacy PCM DSP/re-encode path.

## Calibrated reference

Offline analysis on the XLX026 lab captures found:
- PU2UJY approved/reference capture: active-speech median about **-30.53 dBFS**.
- PU2MIZ strong capture: about **-23.42 dBFS**.
- The earlier V6 coded adjustment **-0.8** moved PU2MIZ to about **-29.60 dBFS**, while PU2UJY remained bit-exact.

An initial experimental ±3 coded-gain ceiling was rejected before deployment: synthetic replay showed it could produce roughly +20 dB / -14.5 dB decoded PCM changes. AMBE coded "dB" is not 1:1 with decoded PCM dB.

V1 therefore uses:
- target active speech: **-30 dBFS**;
- deadband: **±3.5 dB**;
- coded-gain scale: **0.125 per 1 dB PCM error**;
- hard coded-gain ceiling: **±1.0**;
- insufficient speech evidence => **0 adjustment (fail-open)**.

## Safety

- **0 OpenAI/LLM tokens per transmission**; no external API in TX/RX.
- Manual RadioID calibration keeps precedence.
- `adaptive_gain_dmr=0` by default.
- YSF and D-Star are unchanged in V1.
- Production activation still requires offline replay of this calibrated candidate, ENV regression, real-radio/HW comparison and rollback validation.

The source was imported from the XLX026 runtime observed on 2026-09-29. The production normalizer service was inactive, so this is provenance, not PROD PASS.

### Offline replay result — 2026-09-29

Candidate `66d0dec5f92f22b11e34ad4e1e91bcd4d9f187f8`:
- low: -38.87 → -30.30 dBFS;
- mid: -27.06 → -27.06 dBFS (**bit-exact**);
- loud: -18.72 → -25.10 dBFS;
- PU2MIZ: -23.42 → -27.95 dBFS;
- PU2UJY: -30.53 → -30.53 dBFS (**bit-exact**);
- MMDVM and DMRPlus: `failed=0`.

This is offline ENV evidence using existing XLX026 lab captures, not HW/PROD validation.
