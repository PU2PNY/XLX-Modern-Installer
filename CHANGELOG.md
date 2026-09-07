# Changelog


## v1.2.2 — 2026-09-07

### Fixed
- Fixed fresh-install rollback after a successful Admin 8/8 installation.
- Private Admin route validation now checks stable functional markers instead of translated UI labels.
- Admin wrapper now reports the exact failed invariant instead of a generic rollback message.
- Public release audit now recognizes only two exact historical ZIP blobs that were manually reviewed and contain no credentials or secret files; any different archive still triggers review.

## 1.2.1 — 2026-09-07

- Fixed fresh-install Admin rollback at step 6/8 caused by a crawler-protection validation mismatch.
- Added real known-crawler denial to the private Admin while keeping X-Robots-Tag and meta noindex protections.
- Step 6 now reports each credential/security validation separately instead of ending with an opaque rc=1.
- Added regression coverage for PT-BR and English Admin crawler/security markers.

## v1.2.0 — 2026-09-07 — Production parity release

### Dashboard
- Synchronized the public installer with the current validated production behavior.
- Restored **Modules** as an independent page from **Connected**.
- Added NATO phonetic module names from **Alfa** through **Zulu**.
- Standardized **Gateway / Repeater** terminology.
- Added public QRZ operator photos in live TX with local caching and fallback animation.
- Added 🛰️ live-position links to APRS/D-PRS when a recent real position exists.
- Added Digital Lab APRS/D-PRS/GPS assets and APIs.
- Added repeater enrichment and module capability presentation.
- Kept the visible activity history at 24 hours.
- Applied the live endpoint/polling optimizations used in production.

### Installer
- Installer UI remains selectable at startup: Portuguese (Brazil) or English.
- Dashboard language remains selectable from six complete catalogs.
- APRS/D-PRS is now bundled in this repository and installed by default.
- Admin username, password and private URL slug are collected before installation begins.
- Admin minimum password length changed to 8 characters.
- Inputs that are logically case-insensitive accept upper- or lowercase.
- The private Admin page is installed without a public menu link.

### Administration and operations
- Added public operational observability for XLXD, DMR data/metadata, YSF data, APRS/D-PRS, history and regression self-tests.
- Health is local-only in the public package: no Telegram integration and no private CrossMode/Unified Voice implementation is shipped.
- Timezone and module count are inherited from each reflector installation instead of using reference-server defaults.
- Updated Admin baseline to the current production feature set.
- Whitelist, blacklist and per-reflector XLX Interlink management retained.
- RadioID management, integrity checks, Health status and protected restart retained.
- CallingHome remains part of installation/post-install validation.

### Public-release policy
- No production passwords, tokens, private IP data or private Admin route are published.
- Support, ANATEL simulator and News are excluded from the standard public dashboard.
