# XLX026 GitHub Maintenance Control

This directory is a deliberately restricted control plane for maintenance of the XLX026 production reflector.

## Safety model

- The polling agent runs as the unprivileged `xlxagent` user.
- GitHub does **not** provide arbitrary root shell access.
- Root operations are limited to fixed, root-owned local wrappers installed during bootstrap.
- The public dashboard is not modified by the agent.
- No GitHub PAT, SSH private key, TLS private key, production backup, `.env`, database or credential is stored in this repository.
- Every job has a unique `job_id`; the agent executes a job only once.
- Initial allowlist: `readonly_smoke`, `backup_only`, `golden_lab`.
- There is no production publish action in the initial agent. Publication will only be added after the lab candidate and compatibility tests are reviewed.

## control.json

`control.json` contains only four fields: `schema`, `enabled`, `job_id`, and `action`.

The branch used by the XLX026 maintenance agent is `feature/xlx026-maint-20260823`. `main` is intentionally untouched during development and validation.
