# Unified Audio V1.x — canary, operator feedback and rollback

Date: 2026-10-16/17
Repository: `PU2PNY/XLX-Modern-Installer`
Archive branch: `archive/unified-audio-v1-3-20261017`

## Evidence model

- DOC: code/docs only.
- SW/ENV: WartyWallaby tests and build gates.
- PROD: direct XLX026 service/API observation.
- OPERATOR: listening feedback from real users/operator; not inferred from software metrics.

## Baseline preserved before audio canary

Production backup: `/opt/xlx026-backups/UNIFIED_AUDIO_BASELINE_20261016_194650`

Known-good pre-canary xuvd SHA-256:
`d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884`

Backup contains xuvd binary, source snapshot, systemd unit, Helix shadow drop-in, checksums and restore-smoke artifact.

## Unified Audio V1.0/V1.1 canary

The canary introduced an opt-in `XLX_AUDIO_PROFILE=unified-v1` PCM processing stage around the existing D-Star/AMBE+2 transcoder. Helix remained in `shadow`; XLXD was not restarted.

V1.1 production xuvd SHA-256:
`781fbd8292c677227b223cde056e64c62fa7e7f93eec267fc79bf179cb3854ca`

OPERATOR result: audio was judged too muffled, with excessive bass/low-mid energy, microphone level perceived as amplified and a pronounced "tin-can" character. The supplied recording was treated as evidence for further DSP work; subjective approval was NOT granted.

## Unified Audio V1.3 candidate

ENV/WartyWallaby candidate SHA-256:
`1c8247a6c7a203be3ee4e8d06d0dd51d8b28ab4b2be76d788f27b300deb2a95d`

The V1.3 candidate removes microphone boost (AGC may attenuate but not raise input), applies stronger broad suppression of the 300-1400 Hz box/low-mid region and preserves/restores the 1.6-3.4 kHz intelligibility region. Specific equivalence gates passed in ENV, including bit-identical legacy/off paths. V1.3 was NOT promoted to production before the rollback request.

A DSP snapshot is kept under `experimental/helix-bridge/archive/` on this archive branch. The exact tested full source and ELF are also retained in the production-side root-only work archive listed below.

## Helix indicator false negative

During the V1.1 canary, Helix itself remained healthy in shadow mode, with socket present and recent observations without fallback. The dashboard showed unavailable because `xlx-helix-monitor.py` still expected the pre-canary xuvd SHA. A temporary production monitor correction updated the expected hash to V1.1. Backup before that monitor change:

`/opt/xlx026-backups/HELIX_MONITOR_HASH_FIX_20261016_220038`

This monitor change was also rolled back when production returned to the pre-canary xuvd.

## Work archive retained before rollback

Root-only archive:
`/opt/xlx026-backups/UNIFIED_AUDIO_WORK_ARCHIVE_20261017_0023`

It retains the V1.1 production ELF, V1.3 ENV ELF, exact V1.3 source, current/temporary monitor copy, systemd state and SHA-256 manifest. No production secrets are versioned here.

## Production rollback

User explicitly requested preserving the experiment and restoring the backup from before the audio changes.

Rollback result (PROD): PASS.

- XLXD PID before: `2175715`
- XLXD PID after: `2175715` (unchanged)
- xuvd before rollback PID: `3915230`
- xuvd after rollback PID: `3946342`
- restored xuvd SHA-256: `d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884`
- `audio-unified-v1.conf`: removed
- effective xuvd environment after rollback: `XLX_HELIX_MODE=shadow XLX_HELIX_OBSERVE_SOCKET=/run/helix-voice/observe.sock`
- Helix monitor restored to the pre-hash-fix script
- `/api/live.php`: HTTP 200
- `/api/status.php`: HTTP 200
- `/api/helix-status.php`: shadow active, candidate OK, anomaly false at post-rollback validation

No dashboard database/data, Nginx/PHP, XLXD binary, protocol ports, TX Turn Guard, TOT or other unrelated runtime component was changed by this rollback.

## Decision

Do not merge the Unified Audio experiment into `main` and do not reactivate the profile in production without a new explicit decision, new ENV gates and operator listening approval. The pre-canary production audio path is restored as the active baseline.