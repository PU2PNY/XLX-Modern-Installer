# XLX026 GitHub Maintenance Control

This directory is a deliberately restricted control plane for maintenance of the XLX026 production reflector.

## Safety model

- The Internet-facing polling component runs as the unprivileged `xlxagent` user with `/usr/sbin/nologin`.
- The poller can only validate `control.json` and write a small JSON request into a local inbox.
- A separate root-owned executor is triggered locally by `systemd.path`; it never reads arbitrary shell commands from GitHub.
- The executor accepts only the fixed allowlist `readonly_smoke`, `backup_only`, `golden_lab`, and `candidate_build`.
- `candidate_build` only copies the validated 2.6.0 lab tree, applies the XLX026 nine-protocol scope, compiles and statically audits the resulting binary. It does not execute or install the candidate.
- Root operations call only fixed, root-owned local wrappers installed from a commit-pinned bootstrap with SHA-256 validation.
- The maintenance flow does not use `sudo` from inside the sandboxed poller.
- GitHub does **not** provide arbitrary root shell access.
- The public dashboard is not modified by the agent.
- No GitHub PAT, SSH private key, TLS private key, production backup, `.env`, database or credential is stored in this repository.
- Every job has a unique `job_id`; completed jobs are not executed again unless an administrator explicitly clears/requeues the failed state during a controlled migration.
- There is no production publish action at this stage. Publication will only be added after the lab candidate and compatibility tests are reviewed.

## XLX026 Core 2.6.0 scope

Operational handlers retained: DExtra, DPlus, DCS, XLX interlink, DMRPlus, DMRMMDVM, YSF, G3 and IMRS.

M17, NXDN and P25 handlers are excluded from the XLX026 candidate. The transcoder infrastructure remains in the core for compatibility, but this maintenance flow does not install AMBEd or hardware transcoding.

## control.json

`control.json` contains only four fields: `schema`, `enabled`, `job_id`, and `action`.

The branch used by the XLX026 maintenance agent is `feature/xlx026-maint-20260823`. `main` is intentionally untouched during development and validation.
