# XLX026 RadioID reconciliation (production reference)

This directory records the **observed XLX026 integration**, not a generic installer step. Its paths refer to the XLX026 production layout. Do not enable this bundle in a fresh installation until the runtime paths and service account have been validated there.

## Evidence and precedence

- The MMDVM `RPTC` packet supplies the **gateway's numeric DMR ID**. The passive metadata monitor records its IPv4 source and timestamp. The XLXD connection XML supplies the gateway callsign and IP.
- Reconciliation proceeds only if that IP matches exactly one recently observed DMR ID. Shared NAT, absent metadata, stale observation, a non-DMR connection, or competing IDs are skipped.
- An exact-ID lookup at RadioID is required before a changed callsign is published. The existing atomic RadioID helper backs up CSV/SQL, validates SQLite and rolls back on failure. The alias file is published only after the SQL query confirms the new callsign.
- PHP status and Live read the small local alias file; the Rust Live core reads it on opening and while an active stream is enriched. The original network callsign stays in `network_callsign`. No request path calls an external API.
- A DMR **operator ID in an RF stream can differ from the gateway ID**. Never use a gateway's `RPTC` ID to rename a different operator without separate stream-ID evidence.

## XLX026 deployment and rollback

The production copy is at `/opt/xlx-dmr-meta-monitor/` and `/opt/xlx026-live-core-v2/`. The PHP files live under `/var/www/html/xlxd/api/`. The systemd timer runs every 15 seconds; it performs at most one external lookup per run and backs off for five minutes per candidate. The numeric-ID lookup is bounded to five seconds. The backup directory for this change is `/root/backups-xlx026/RADIOID_GLOBAL_20260925_073144`; the prior Live binary is in `/root/backups-xlx026/RADIOID_DISPLAY_20260925_070714/`.

For rollback, disable `xlx026-radioid-reconcile.timer`, restore the backed-up passive monitor, alias helper, dashboard APIs, and Live binary, then restart only their services during an idle TX window. Restore the CSV and SQL from the helper's per-operation backup only if a reconciliation actually changed that ID. Keep the old network callsign in logs for audit.

## Validation levels

- SW: Python syntax, parser packet test, unambiguous/ambiguous IP tests, PHP syntax, Rust offline compilation and two Rust unit tests passed.
- PROD: API status and Live returned 200. A live `PU2UJY` stream was observed as `PY2UYY`, including its name and gateway. The timer and services are active without restarts.
- PROD pending: no new post-restart `RPTC` announcement has yet exercised an automatic **second** ID change through the reconciler. This is not a validated fresh-server installation.

RadioID API use: https://database.radioid.net/api/ . Only exact-ID point lookups are made; heed RadioID rate limits and data-use terms.
