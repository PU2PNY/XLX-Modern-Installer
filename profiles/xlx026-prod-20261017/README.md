# XLX026 production recovery profile — 2026-10-17

This profile records the non-secret production runtime required to reconstruct the XLX026 behavior observed on 2026-10-17. It is intentionally separate from the generic installer.

## Use

On the immutable recovery revision/tag, run `sudo bash start.sh --profile=xlx026-prod-20261017` and complete the normal questions for the new VPS. The profile is applied only after the generic installation. Other users do not select this profile and continue to receive the generic installer.

## Captured

- dashboard/control code that differs from the canonical generic dashboard, including the current Live UI, Support, ANATEL simulator, SEO helpers, Helix status and TX-turn wait UI;
- Live Core V2 Rust source + Cargo.lock;
- Live Hub source and TX-turn state consumer;
- Health Monitor and passive transmission analyzer source;
- current xuvd source snapshot and production binary hash;
- project systemd units/drop-ins as reference;
- exact approved XLXD 2.5.3/TOT180/TX Turn Guard build target and production hash;
- hashes for the active XLXD, xuvd, Helix daemon and Live Core V2 binaries.

## Deliberately excluded

No password, API token, private key, TLS private material, real database, production log, backup, CallingHome secret, APRS recovery secret or `/etc/xlx-ai-monitor.env` is stored here. These values must be restored from a separate private backup or entered again during recovery.

## Important limitation

The exact production xuvd and Helix ELF files are identified by SHA-256 but are not committed to the public repository. XLXD and Live Core V2 are reproducibly rebuilt from versioned source; xuvd/Helix remain subject to the existing provenance/equivalence gate. Therefore this profile is a complete public-code/runtime snapshot, but a byte-for-byte private disaster recovery still also requires the separate secret/data backup and the known-good xuvd/Helix artifact or a validated rebuild.

See `PRODUCTION_MANIFEST.json`, `docs/RECOVERY.md` and `PROJECT_RELEASE_STATUS.md`.
