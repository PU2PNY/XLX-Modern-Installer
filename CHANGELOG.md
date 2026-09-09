## v1.2.10 — 2026-09-09

- Added explicit handling of Let's Encrypt rate limits without replacing Certbot.
- Parse the ACME `retry after` timestamp and schedule a one-shot systemd retry using `xlx-modern-https-retry`.
- Final output now shows the URL that is actually available immediately (HTTP or HTTPS).
- Added end-to-end readiness checks for Live, Connected, Modules, APRS/D-PRS, Certificates, APIs, APRS service, Health service, private Admin, Apache, XLXD and Echo before reporting installation complete.
- Added regression coverage for rate-limit parsing and final readiness invariants.

# Changelog

## v1.2.9 — 2026-09-09

- Fixed a fresh-install blocker where the dashboard i18n builder translated the protected native route sentinel for `certificado`, causing the installed `index.php` to lose the Certificate route and stop at `Native Certificate route is missing`.
- Route-protection sentinels are now language-neutral numeric identifiers and the build fails immediately if any protected route sentinel remains unresolved.
- Added a six-language regression build that requires `certificado`, `digital-lab`, their native views, and the QR library to survive translation unchanged.
- No XLXD production restart is required by this release.

## v1.2.8 — 2026-09-09

### Fresh-install hardening after Debian 12 VPS audit

- Fixed the Admin install chain so functional validation no longer depends on translated UI labels. Stable DOM/action markers now validate Access, RadioID and Interlink capabilities.
- Added explicit unexpected-error diagnostics (file, line, return code and failing command) to the top-level installer and critical Admin/dashboard/APRS/certificate stages, preventing silent returns to the shell.
- Migrated package automation from `apt` to `apt-get` and declared required Debian 12 utilities such as `sudo`, `procps`, `iproute2`, `util-linux`, `openssl`, `rsync` and `python3`. Mandatory `full-upgrade` remains disabled.
- Kept HTTPS/Certbot non-fatal for recoverable ACME failures; the real ACME diagnostic and retry helper remain available while the public dashboard can continue over HTTP.
- Made APRS/D-PRS a native, mandatory dashboard capability: its UI/API ships under `dashboard/`, while only the background service and SQLite state are provisioned outside the webroot. Removed the active `vendor/xlx-aprs-dprs` architecture.
- Kept APRS account behavior aligned with the production reference: cryptographically generated passwords, hash-only storage, day/month birthday verification for authorized password recovery, auth-version rotation and remembered-token revocation. Raw birthday values are no longer written in SELF_REGISTER audit details.
- Made Certificates fully native to this repository and dashboard. Removed the active external `XLX-Certificate-Generator` install path.
- Added versioned certificate signing payloads and a shared HMAC signature library. Automated tests now prove a valid token succeeds while a one-character-tampered token and a changed record fail.
- Certificate QR verification uses the native route `/?page=certificado&validar=...&token=...` on the installed reflector.
- Completed native APRS/Certificate UI catalogs for English, Spanish, French, German and Italian and added regression checks against untranslated/mangled native strings.
- Preserved v1.2.6/v1.2.7 live-stream identity, QRZ/TX and frontend stability fixes while rebasing this release on the current public `main`.
- Updated README/README.en/README.pt-BR to document the actual server, dashboard, Admin, APRS/D-PRS, certificate, CallingHome, observability, HTTPS and security behavior.
- Added release-hardening regression coverage for Admin markers, Debian dependencies, APRS recovery semantics, native architecture and explicit `INSTALLATION COMPLETE` terminal state.

## v1.2.7 — 2026-09-08

### Painel sincronizado e estabilidade do TX

- Corrige a alternância entre foto do QRZ e GIF causada por leituras rápidas transitórias do estado de TX.
- Evita falso bip de encerramento ao exigir 900 ms de estabilidade antes de remover uma transmissão confirmada.
- Reutiliza imediatamente a foto pública do QRZ já carregada, sem retornar ao GIF entre atualizações.
- Inclui os ajustes móveis mais recentes do XLX026, correção do botão de acessibilidade e fallback para navegadores antigos.
- Mantém o painel global e configurável, sem dados privados ou identidade fixa do XLX026.
- As páginas Suporte e Simulado ANATEL permanecem excluídas da distribuição pública.

## v1.2.6 — 2026-09-08

### Fixed
- Made live transmission keys unique across legitimate DMR/YSF Stream ID reuse by including the stream start time.
- Prevented the dashboard translator from changing callable JavaScript identifiers in Spanish and French builds.
- Prevented the live callsign MutationObserver from rewriting identical text and retriggering itself.
- Connected the persistent callsign directory to status connections, active transmissions and history.
- Aligned access-list backups and Interlink audit events with the validated Admin contract.
- Added the `noimageindex` crawler directive without restoring the removed Quick Guide.
- Added regression checks for callable identifiers and identical live callsign rewrites.


## v1.2.5 — 2026-09-08

### Fixed
- Unified all installation data questions into the main reflector questionnaire: city/region, YSF reflector ID, Admin username, private Admin URL and Admin password now appear before the single settings review.
- Removed the separate `INSTALL` confirmation; pressing ENTER on the reviewed settings is the only normal installation confirmation before execution continues.
- Fixed bundled APRS/D-PRS integrity validation by regenerating `SOURCE-MANIFEST.sha256` after the bundled README/install changes.
- Added a regression guard that verifies every bundled APRS/D-PRS file against its manifest.
- Restored the production visual separation between **Modules** and **Connected**: standalone menu items and independent page layouts.
- **Modules** now follows production order: access-identification table first, then module cards.
- **Connected** now follows production layout: filters plus station table, without the merged summary-card block.
- Restored the production 1240 px dashboard content width.
- Removed hard-coded reference-server identifiers from the public Modules JavaScript; REF/XRF/DCS/YSF labels now derive from installation data.


## v1.2.4 — 2026-09-07

### Fixed
- Replaced the fragile Certificate route hook with a semantic, idempotent integration compatible with the current dashboard page structure and module ordering.
- Added a regression test that applies the Certificate hook twice to the current dashboard and validates route, navigation and view integration.
- Dashboard footer version is now rendered from the installer VERSION instead of a stale hard-coded v1.2.0 label.
- Corrected the Admin installation report: no terminal route is provided (`terminal_route_admin=no`), and the reported Admin baseline is 1.5.1.
- Propagated the selected installer language into runtime-data, callsign-directory, Admin and Certificate modules and translated their active PT/EN operational messages.

## v1.2.3 — 2026-09-07

### Fixed
- Removed the mandatory `apt full-upgrade` from clean-server installation; only the package index and required dependencies are handled by the installer.
- HTTPS certificate issuance is now non-destructive: a Certbot/ACME failure no longer aborts or discards an otherwise valid reflector installation.
- Added explicit handling for the Debian 12 Certbot 2.1.x / Python 3.11 `AttributeError: can't set attribute` reporting bug.
- Added `xlx-modern-https-retry DOMAIN EMAIL` for controlled HTTPS recovery without reinstalling the reflector.
- CallingHome uses HTTPS only after a valid certificate actually exists; otherwise it remains on HTTP until TLS is ready.
- Final validation now tests the protocol actually available and reports HTTPS as pending instead of failing the whole installation.
- HTTPS diagnostics no longer falsely claim DNS/port failure without evidence; relevant ACME diagnostics are surfaced when available.
- Added regression tests preventing mandatory full OS upgrades and fatal HTTPS behavior from returning.


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
