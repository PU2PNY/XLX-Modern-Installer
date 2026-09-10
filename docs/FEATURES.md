# XLX Modern Installer — Public Feature Set

Version: **1.2.12**

## Server

- Debian 12 x86_64 fresh installation.
- XLXD core and configurable active modules.
- Optional XLX Echo on module E.
- Apache/PHP dashboard stack.
- RadioID/callsign database with persistent local overrides.
- Timer-based CallingHome.
- Health, DMR data/meta, YSF data, history collection and regression self-test.
- Preventive backups and component-level rollback where supported.
- Recoverable HTTPS failure handling with `xlx-modern-https-retry`.

## Public dashboard

- Low-latency live TX/RX monitor with fast start/end state changes and 24-hour activity grouped by callsign with expandable transmission history.
- Public operator profile photo when available and observed APRS/D-PRS/GPS location linking into the reflector Digital Lab.
- Connected stations as an independent page.
- Modules/access identifiers as an independent page; configured module range and NATO names.
- Ranking for longest connected station, most PTT/TX, most airtime, busiest hours, modules and protocols.
- Worldwide XLX reflector list with search/filter controls.
- Exact Gateway/Repeater semantics; no proximity-based identity guessing.
- RadioID identity, supplemental DMR Talker Alias and observed APRS/D-PRS/GPS status.
- Native APRS/D-PRS Digital Lab on dedicated module B, with APRS message/ACK send and receive support.
- Native activity-based certificates with TX/airtime/module/protocol data plus QR + HMAC verification.
- Dashboard languages: PT-BR, EN, ES, FR, DE, IT.
- Support, ANATEL simulator and News are intentionally excluded from the public installer distribution.

## Native APRS/D-PRS

- APRS-IS/D-PRS background gateway and local SQLite state.
- Callsign account creation after qualifying recent activity.
- Day/month birthday consent used by the authorized password-recovery flow.
- Cryptographically generated passwords; hash-only persistence.
- Reset rotates auth version and revokes remembered tokens.
- Message/ACK/operator-state support as provided by the production-derived Digital Lab implementation.

## Native Certificates

- Certificate issue/preview/verification inside the dashboard.
- Requires eligible recorded activity.
- Unique issuance ID.
- Versioned HMAC-SHA256 payload.
- Constant-time verification and tamper rejection.
- QR returns to the same dashboard validation route.
- Secret stored outside the webroot.

## Private Admin

- Configurable private slug, username and password (minimum 8 characters).
- PT-BR or English UI.
- Status/listeners/logs/backups/Health.
- RadioID check/refresh/search/save/delete.
- Whitelist/blacklist and Interlink management.
- Protected XLXD restart.
- No SSH/Linux browser terminal and no XLXD terminal UI.
- CSRF/session/rate-limit/audit controls and limited sudo helpers.

## Installer UX

- PT-BR or English installer.
- One consolidated questionnaire and one final ENTER confirmation.
- Edit individual answers by question number.
- No late city/YSF/Admin prompts and no `INSTALL` confirmation.
- No mandatory OS full-upgrade.
- Explicit final `INSTALLATION COMPLETE` only after essential post-install checks pass.
