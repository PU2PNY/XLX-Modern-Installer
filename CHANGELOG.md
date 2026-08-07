# Changelog

## Unreleased — Global Dashboard V1

- Updated the repository dashboard from the current production-tested interface.
- Removed the XLX026-private Support implementation from the distributed dashboard.
- Removed the Brazil-specific ANATEL/LABRE News integration from the distributed dashboard.
- Added runtime deployment configuration through `config/site.json`.
- Added support for three-character alphanumeric XLX reflector codes.
- Removed hard-coded XLX026, domain, callsign, YSF and DMR production values.
- Added neutral generated SVG reflector branding.
- Added persistent Ranking V2 collector, API and systemd timer integration.
- Ranking periods now cover today, rolling 7 days, and the current civil month.
- Added configurable weather/propagation cache and global location discovery.
- Updated live/module rendering so DMR/YSF values come from configuration rather than fixed module assumptions.
- Added staging validation, backup and rollback behavior to the dashboard installer.
- Added GitHub Actions validation for shell, PHP, JavaScript, JSON and ranking collector self-test.

## Previous development

- Added a safety wrapper around a reviewed PP5PK installer revision.
- Added preventive backup, preflight validation and explicit confirmation before real installation.
- Added project security documentation and development branches.
