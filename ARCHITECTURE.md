# Architecture

## Execution flow

1. Language selection.
2. Root and operating-system validation.
3. Configuration validation.
4. Dry-run plan.
5. Explicit confirmation.
6. Backup and manifest.
7. Package preparation.
8. XLX core installation.
9. Optional Echo installation.
10. Dashboard installation.
11. Nginx + PHP-FPM and SSL configuration.
12. Firewall proposal.
13. Permissions hardening.
14. Functional validation.
15. Rollback and final report.

## Web runtime

The authoritative web stack is Nginx + PHP-FPM. The legacy Apache module remains only as historical compatibility material and must not be treated as the primary installation/runtime path without new evidence.

Performance invariants:

- Live TX/RX uses the Live Core v2/WebSocket path and must stay low-latency.
- General status polling is page-scoped and bounded; static pages do not maintain a status loop.
- Heavy 24-hour history is fetched only when needed and is not reloaded after short tab visibility changes.
- APRS/D-PRS and repeater enrichment use bounded cache/on-demand lookup.
- Internal consumers should use the compact `/api/runtime.php` endpoint whenever they need only module/connection runtime data.
- DOM replacement is avoided when the rendered data has not changed.

## Change safety

Production-changing modules must preserve backup/rollback, explicit validation and regression tests. XLXD core, protocol, transcoder/audio and radio-routing changes are outside dashboard performance work unless separately justified and tested.
