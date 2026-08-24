# XLX026 GitHub Maintenance Control

This directory documents the restricted maintenance control plane used for the XLX026 production reflector and the completed controlled migration to XLX026 Core 2.6.0.

## Current state

- Production migration completed on 2026-08-24.
- XLX026 Core version: `2.6.0`.
- Production core SHA-256: `10870cf84d91c936497c95c314a0b1eed79779e73260c7ec306cf6bba17632a7`.
- Pinned upstream source commit: `a79a3bf8d883bd35911a34648d71e6980726b4e8`.
- Panel version: `1.1.0`.
- The temporary maintenance agent/timer and executor path were disabled after final validation.
- `maintenance/control.json` is intentionally disabled and set to `idle`.
- Rollback copies/backups remain on the production server; no production backup or secret is stored in GitHub.

## Safety model

- The Internet-facing polling component runs as the unprivileged `xlxagent` user with `/usr/sbin/nologin`.
- The poller can only validate `control.json` and write a small JSON request into a local inbox.
- A separate root-owned executor is triggered locally by `systemd.path`; it never reads arbitrary shell commands from GitHub.
- The executor accepts only a fixed allowlist of maintenance actions; it does not expose arbitrary shell execution.
- Root operations call only fixed, root-owned local wrappers installed from commit-pinned upgrades with integrity validation.
- GitHub does **not** provide arbitrary root shell access.
- No GitHub PAT, SSH private key, TLS private key, production backup, `.env`, database or credential is stored in this repository.
- The maintenance control plane is disabled after successful completion.

## XLX026 Core 2.6.0 scope

Operational handlers retained: DExtra, DPlus, DCS, XLX interlink, DMRPlus, DMRMMDVM, YSF, G3 and IMRS (`NB_OF_PROTOCOLS=9`).

M17, NXDN and P25 handlers are excluded from the XLX026 production candidate. Shared transcoder infrastructure remains for compatibility; this maintenance flow does not install AMBEd or hardware transcoding.

Operational XLX026 settings preserved in the 2.6.0 build:

- `NB_OF_MODULES=5`
- `DMRMMDVM_KEEPALIVE_TIMEOUT=180`
- `YSF_KEEPALIVE_TIMEOUT=90`
- YSF TX/RX default frequency `433125000` Hz
- YSF autolink enabled to module `C`

The fixed transcoder listener remains UDP `10100`. UDP `10101-10199` are dynamic codec-stream ports (`10100 + stream_id`) and are audited separately rather than compared as permanent listeners.

## Validation and rollback

The release path performed a fail-closed pre-publish audit, immediate verified backup, atomic binary replacement, restart of only `xlxd`, XML/listener/log/API/page checks, source synchronization and automatic rollback on failure.

An earlier production attempt correctly rolled back to 2.5.3 when the validator treated dynamic UDP `10102` as a permanent listener. After proving from the source that `10101-10199` are dynamic transcoder stream ports, the validator was corrected while keeping UDP `10100` and every other fixed listener mandatory. The final release then passed all checks.

Final validation covered nine public dashboard routes, `status.php`, `live.php`, and the expected `mtr.php` contract (`HTTP 400` + `invalid_request` when called without required parameters).

See `maintenance/XLX026-2.6.0-RELEASE.md` for the release record.
