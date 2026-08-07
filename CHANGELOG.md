# Changelog

## Unreleased — Global Dashboard V1

- Updated the repository dashboard from the current production-tested interface.
- Removed the XLX026-private Support implementation from the distributed dashboard.
- Removed the Brazil-specific ANATEL/LABRE News integration from the distributed dashboard.
- Added runtime deployment configuration through `config/site.json`.
- Added support for three-character alphanumeric XLX reflector codes.
- Removed hard-coded XLX026, domain, callsign, YSF and DMR production values.
- Added neutral generated SVG reflector branding.
- Added persistent Ranking V2 collector, SQLite storage, JSON API snapshot and systemd timer integration.
- Ranking periods now cover today, rolling 7 days, and the current civil month.
- Added a deterministic isolated Ranking V2 collector self-test.
- Added configurable weather/propagation cache and global location discovery.
- Updated live/module rendering so DMR/YSF values come from configuration rather than fixed module assumptions.
- Reworked the dashboard installer around staging, verified backup, rollback, runtime configuration and post-install validation.
- Added common XLX/Apache dashboard path detection, including `/var/www/xlxd`.
- Extended the top-level installer to validate the Ranking V2 timer and generated JSON after installation.
- Added developer attribution for PU2PNY / Página Certa Digital with public website and contact email.
- Removed unresolved export placeholders from the distributed PWA runtime.
- Expanded `.gitignore` and `SECURITY.md` protections for credentials, databases, logs, backups and generated runtime state.
- Strengthened GitHub Actions validation for shell, PHP, JavaScript, JSON, Ranking V2, installer contract, distribution scope, developer attribution and documentation.

## Previous development

- Added a safety wrapper around a reviewed PP5PK installer revision.
- Added preventive backup, preflight validation and explicit confirmation before real installation.
- Added project security documentation and development branches.
