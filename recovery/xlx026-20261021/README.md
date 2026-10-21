# XLX026 — captured RadioID / MTR runtime (2026-10-21)

**Evidence level: PROD inspection + syntactic checks + limited synthetic dry runs. Not a complete release, and not certified for clean installation.**

This directory preserves **selected production source/configuration files** verbatim as observed after narrowly scoped corrections on 2026-10-21. Files here are **reference/recovery material only**; they are not wired into `install.sh` and must NOT replace generic installer components without adaptation, review, a test deployment and rollback.

## Source of truth and drift
- Source repository: `PU2PNY/XLX-Modern-Installer`, `main` was observed at `56a8591c9f3504805136be64bfcbf48e98fbeb46`.
- Live files differed from repository main. Production has a custom `controle/index.php`, protected sudo helpers, 15-second/timer-driven RadioID reconciliation, MTR live push and cache behavior.
- Generic design remains pending: no production secrets or user DB/data are included here. Absolute `/xlxd` and `/var/lib` paths, `xlx026.net` and control-helper settings must become per-install configurable before installer integration.

## Functional changes observed in PROD
1. `controle/index.php`: authenticated, CSRF-protected official RadioID lookup now provides **Adicionar à base**. A subsequent authorized POST refreshes the official record by callsign and validates a unique seven-digit ID, mandatory name/location data, CSV-safe content, and local ID collision; the existing `radioid-save` helper performs backed-up, integrity-checked publication of the `users.db`. The browser does not get to assert profile fields.
2. `reconcile_radioid.py`: existing DMR ID reconciliation no longer ignores new numeric IDs solely because their currently advertised callsign matches the official source. A bounded new-callsign path checks connected NODE callsigns not present locally across network protocols and, for a unique verified RadioID record, can add using the same atomic helper. No more than one new-callsign API lookup per 60 seconds, with per-callsign backoff (24 h). Existing DMR-specific logic remains.
3. `api/mtr.php`: stale/closed TX is treated as a normal `HTTP 200` + `ok:false,state:inactive` response instead of a `409` error; `mtr.js` ceases polling an inactive widget until the stream is replaced. The existing 15-second interval and pushed MTR remain.
4. `api/repeater.php`: an official, valid empty RadioID-repeater lookup is returned as `HTTP 200` + `ok:false,error:not_found` (negative caching retained). A malformed/unavailable upstream returns `503`, without inventing an absent repeater.
5. A single stale Nginx cache file for `/api/repeater.php|PU2PNY` was quarantined; the subsequent official `PU2PNY` endpoint check returned `HTTP 200` with cache MISS.

## Checks observed
- PHP syntax checks: `controle/index.php`, `api/mtr.php`, `api/repeater.php`: PASS.
- Node.js syntax check: `assets/mtr.js`: PASS.
- Python AST and mocked dry run of a new YSF callsign: PASS.
- `PRAGMA integrity_check` of live `users.db`: `ok` at observed time.
- `/controle/?view=radioid`: HTTP 200 (unauthenticated request tests login/route availability only).
- `/api/live.php`: HTTP 200.
- `xlxd.service` and `xlx026-radioid-reconcile.timer`: active.
- No XLXD restart or audio change required.
- Observed official RadioID response contained 17 named fields. Core identity/location is stored via the legacy CSV/`users.db` schema, while all **17 observed, allowlisted public API fields** are stored in an isolated SQLite archive (`/var/lib/xlx026-identity/radioid-profiles.sqlite3`) when a verified import succeeds. The archive was tested with a verified real RadioID profile; its integrity check passed. No private unlisted API fields are retained.

## Pending release/test gates
- Authenticated UI end-to-end import test including duplicate, update and failed upstream.
- Long-lived tests for concurrency, network failure, new D-Star/YSF/DMR callsigns, negative cache and race with 03:00 database merge.
- Integration into parameterized generic installer + `PROJECT_MASTER_SPEC.md` + test matrix and release status updates, followed by ENV clean install and rollback test.
- Add scheduled backup/restore testing for the separate public metadata archive and a safe read-only view in the Control panel; it is not part of the legacy `users.db`.
- Confirm responsive/accessibility behavior of added control form.
- Verify runtime identity/status over longer operation and avoid misrepresenting syntax/synthetic tests as full PROD correctness.

## Local rollback copies (host-only; not GitHub)
- `/opt/xlx026-backups/RADIOID_UI_20261021_081440`
- `/opt/xlx026-backups/RADIOID_RECONCILE_20261021_081659`
- `/opt/xlx026-backups/RADIOID_AUTO_ALL_20261021_082400`
- `/opt/xlx026-backups/MTR_INACTIVE_20261021_081746`
- `/opt/xlx026-backups/REPEATER_EMPTY_RESPONSE_20261021_083030`
- `/opt/xlx026-backups/REPEATER_CACHE_ONE_KEY_20261021_083207`
- `/opt/xlx026-backups/RADIOID_FULL_PROFILE_IMPORT_20261021_083857`
- `/opt/xlx026-backups/RADIOID_AUTO_PROFILES_20261021_083929`

Use file-specific rollback, owner/group/mode restoration, service health checks and DB integrity verification; never blindly restore files across installations. Backups alone do not prove an executed restore test.
