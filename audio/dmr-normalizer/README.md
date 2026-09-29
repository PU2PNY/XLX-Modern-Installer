# Adaptive DMR Gain Normalizer — experimental V1

Status: **disabled by default; not approved for production yet**.

The component measures a short DMR speech window and, only for a true level outlier, adjusts the AMBE+2 gain parameter already present in the coded voice frame. Adaptive mode returns before the legacy PCM DSP/re-encode path.

Safety:
- 0 OpenAI/LLM tokens per transmission; no external API in TX/RX.
- target -25 dBFS, deadband ±3 dB, hard software correction cap ±3 dB.
- insufficient speech evidence => 0 dB (fail-open).
- manual RadioID calibration keeps precedence.
- YSF and D-Star are unchanged in V1.
- production activation requires backup + ENV + real-radio/HW regression + rollback.

The source is imported from the XLX026 runtime observed on 2026-09-29. The existing production normalizer service was inactive, so source provenance is not a PROD PASS.

`xlxd-cysfutils-gain.patch` records the functional XLXD production delta that provides `CYsfUtils::AdjustAmbeGain()`. It must not be applied blindly to a different XLXD revision.
